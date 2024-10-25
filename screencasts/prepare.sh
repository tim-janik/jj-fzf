# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

export JJ_CONFIG=/dev/null # ignore user config
readonly SESSION="$1"
readonly ASCIINEMA_SCREENCAST=$(readlink -f "./$SESSION")
export SESSION ASCIINEMA_SCREENCAST

# == deps ==
for cmd in nano tmux asciinema agg gif2webp gnome-terminal ; do
  command -V $cmd || die "missing command: $cmd"
done
for font in \
  /usr/share/fonts/truetype/firacode/FiraCode-Retina.ttf \
    /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf
do
  cp $font .
done

# == Aux Funcs ==
# Create temporary dir, assigns $TEMPD
temp_dir()
{
  test -n "${TEMPD:-}" || {
    TEMPD="`mktemp --tmpdir -d jjfzf0XXXXXX`" || die "mktemp failed"
    trap "rm -rf '$TEMPD'" 0 HUP INT QUIT TRAP USR1 PIPE TERM
    echo "$$" > $TEMPD/jj-fzf.pid
    echo "$$" > $TEMPD/$SCRIPTNAME.pid
  }
}

# rtrim, then count chars
crtrim()
(
  V="$*"
  V="${V%"${V##*[![:space:]]}"}"
  echo "${#V}"
)

# == Config + Timings ==
W=122 H=40 Z=0.8
t=0.050		# typing delay
k=0.2000150	# special key delay
s=0.250		# synchronizing delay, dont shorten
p=0.9990750	# user pause
w=1.500025	# info pause

# Use fast timings for debugging
fast_timings()
{
  t=0.005
  k=0.01
  p=$s
  w=0.1
}

# == screencast commands ==
# type text
T()
{ txt="$*" && for (( i=0; i<${#txt}; i++ )); do tmux send-keys -t $SESSION -l "${txt:$i:1}" ; sleep $t ; done ; }
# send key
K()
( N="${2:-1}";  for (( i=0 ; i<$N; i++ )); do tmux send-keys -t $SESSION "$1" ; sleep $k ; done )
Enter() { K "Enter" ; P; }
# synchronize (with other programs)
S()
{ sleep $s ; }
# pause (for user to observe)
P()
{ sleep $p ; }
# kill-line + type-text + kill-line
Q()
{ K C-U; T "$*"; K C-U; S; }	# fzf-query + Ctrl+U
# Q without delays
Q0()
{ tmux send-keys -t $SESSION C-U; tmux send-keys -t $SESSION -l "$*"; tmux send-keys -t $SESSION C-U; }
# Ctrl-Alt-X type-text Ctrl-g
X()
{
  K C-M-x ;
  (export t=$(echo "$t / 2" | bc -l) ; T "$*        ")
  sleep $(echo "`crtrim "$*"` * $w / 25" | bc -l)
  K C-g ; S
}

# Find PID of asciinema for the current $SESSION
find_asciinema_pid()
{
  ps --no-headers -ao pid,comm,args |
    awk "/asci[i]nema rec.*\\<$SESSION\\>/{ print \$1 }"
}
# Start recording with asciinema in a dedicated terminal, using $W x $H, etc
start_asciinema()
{
  DIR="$(readlink -f "${1:-.}")" ; shift
  temp_dir
  # set -x
  # Simplify nano exit to Ctrl+X, also avoids exposing absolute file paths
  echo -e "set saveonexit" > $TEMPD/nanorc # avoids confirmation: Type "y" Enter
  export EDITOR="/usr/bin/nano --rcfile $TEMPD/nanorc"
  # stert new screencast session
  tmux kill-session -t $SESSION 2>/dev/null || :
  ( cd "$DIR"
    export JJ_CONFIG=/dev/null
    tmux new-session -P -d -x $W -y $H -s $SESSION
  ) >$TEMPD/session
  echo "tmux-session: $SESSION"
  tmux set-option -t $SESSION status off
  tmux send-keys -t $SESSION 'PS1="> "; EDITOR="/usr/bin/nano --rcfile '$TEMPD/nanorc'" ; '
  tmux resize-window -t $SESSION -x $W -y $H
  tmux send-keys -t $SESSION $'clear\n'
  while [ $# -gt 0 ] ; do
    tmux send-keys -t $SESSION "$1"
    shift
  done
  sleep 0.05
  gnome-terminal --geometry $W"x"$H -t $SESSION --zoom $Z  -- \
		 asciinema rec --overwrite "$ASCIINEMA_SCREENCAST.cast" -c "tmux attach-session -t $SESSION -f read-only"
  while test -z "$(find_asciinema_pid)" ; do
    sleep 0.1 # dont save PID, this might be an early pid still forking
  done
}
# Stop recording
stop_asciinema()
(
  set -Eeuo pipefail -x
  PID=$(find_asciinema_pid)	# PID=$(tmux list-panes -t $SESSION -F '#{pane_pid}')
  kill -9 $PID	# abort asciinema, so last frame is preserved
  tmux kill-session -t $SESSION
)
# Stop recording and render screencast output files
render_cast()
(
  set -Eeuo pipefail # -x
  SCREENCAST="$1"
  test -r "$SCREENCAST.cast" || die "missing file: $SCREENCAST.cast"
  # sed '$,/"\[exited]/d' "$SCREENCAST.cast"
  # --font-family "DejaVu Sans Mono" --idle-time-limit 1 --fps-cap 60 --renderer resvg
  # asciinema-agg
  agg \
    --theme asciinema --speed 1 \
    --font-family "Fira Code Retina" \
    --font-dir $PWD --font-size 16 \
    "$SCREENCAST.cast" "$SCREENCAST.gif"
  ( set -x
    # -preset slower -preset veryslow -x264opts opencl
    time ffmpeg -hwaccel auto -i "$SCREENCAST.gif" \
	 -c:v libx264 -crf 24 -tune animation -preset placebo \
	 -movflags faststart -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
         -y "$SCREENCAST.mp4" &
    gif2webp "$SCREENCAST.gif" -min_size -metadata all -o "$SCREENCAST.webp" &
    wait
  )
  ls -l "$SCREENCAST"*
  command -V notify-send 2>/dev/null && notify-send  -i system-run -t 10 "Screencast ready: $SCREENCAST"
  true
)

# == repo commands ==
# Usage: make_repo [-quitstage] [repo] [brancha] [branchb]
make_repo()
(
  [[ "${1:-}" =~ ^- ]] && { DONE="${1:1}"; shift; } || DONE=___
  R="${1:-repo0}"
  A="${2:-deva}"
  B="${3:-devb}"

  rm -rf $R/
  mkdir $R
  ( # set -x
    cd $R
    git init -b trunk
    echo -e "# $R\n\nHello Git World" > README
    git add README && git commit -m "README: hello git world"
    G=`git log -1 --pretty=%h`
    [[ $DONE =~ root ]] && exit

    git switch -C $A
    echo -e "Git was here" > git-here.txt
    git add git-here.txt && git commit -m "git-here.txt: Git was here"
    echo -e "\n## Copying Restricted\n\nCopying prohibited." >> README
    git add README && git commit -m "README: copying restricted"
    L=`git log -1 --pretty=%h`   # L=`jj log --no-graph -T change_id -r @-`
    echo -e "Two times" >> git-here.txt
    git add git-here.txt && git commit -m "git-here.txt: two times"
    [[ $DONE =~ $A ]] && exit

    jj git init --colocate
    jj new $G
    sed -r "s/Git/JJ/" -i README
    jj commit -m "README: jj repo"
    echo -e "\n## Public Domain\n\nDedicated to the Public Domain under the Unlicense: https://unlicense.org/UNLICENSE" >> README
    jj commit -m "README: public domain license"
    echo -e "JJ was here" > jj-here.txt
    jj file track jj-here.txt && jj commit -m "jj-here.txt: JJ was here"
    jj bookmark set $B -r @-
    [[ $DONE =~ $B ]] && exit

    jj new trunk
    echo -e "---\ntitle: Repo README\n---\n\n" > x && sed '0rx' -i README && rm x
    jj commit -m "README: yaml front-matter"

    [[ $DONE =~ 3tips ]] && jj abandon -r $L # allow conflict-free merge of 3tips
    sed '/title:/i Date: today' -i README
    jj commit -m "README: add date to front-matter"
    jj bookmark set trunk --allow-backwards -r @-
    [[ $DONE =~ 3tips ]] && exit

    jj new $A $B -m "Merging '$A' and '$B'"
    M1=`jj log --no-graph -T change_id -r @`
    [[ $DONE =~ merged ]] && exit

    jj backout -r $L -d @ && jj edit @+ && jj rebase -r @ --insert-after $A-
    jj rebase -b trunk -d @
    [[ $DONE =~ backout ]] && exit

    jj new trunk $M1 -m "Merge into trunk"
    [[ $DONE =~ squashall ]] && (
      EDITOR=/bin/true jj squash --from 'root()+::@-' --to @ -m ""
      jj bookmark delete trunk gitdev jjdev
    )

    true
  )

  ls -ald $R/*
)
