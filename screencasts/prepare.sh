#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
die() { echo "${0##*/}: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }

[[ "${BASH_SOURCE[0]}" = "${BASH_SOURCE[0]#/}" ]] &&
  SCREENCASTSDIR="$PWD/${BASH_SOURCE[0]}" || SCREENCASTSDIR="${BASH_SOURCE[0]}"
export SCREENCASTSDIR="${SCREENCASTSDIR%/*}"
# Add jj-fzf to $PATH
PATH="$SCREENCASTSDIR/..:$PATH"

# == Options ==
SCREENCAST_WINDOW=false
SCREENCAST_SPEED=normal
SCREENCAST_HIDE=false
for arg in "$@"; do
  case "$arg" in
    -x)		set -x ;;
    --fast)	SCREENCAST_SPEED=fast ;;
    --window)	SCREENCAST_WINDOW=true ;;
    --hide)	SCREENCAST_HIDE=true ;;
    --help)	cat <<-__EOF
	Usage: ${0##*/} [OPTIONS...]
	Options:
	  --window	Run screencast in dedicated terminal window
	  --hide	Hide screencast output during run
	  --fast	Reduce replay timings, might cause race conditions
__EOF
		exit 0 ;;
  esac
done
[[ "$SCREENCAST_WINDOW$SCREENCAST_HIDE" == *true* ]] &&
  SCREENCAST_FIXTTY=false || SCREENCAST_FIXTTY=true

# == Config  ==
test -n "${SCREENCAST_SESSION-}" || die "missing SCREENCAST_SESSION name"
TEMPD=$(mktemp --tmpdir -d screencasts.XXXXXX) &&
  trap "rm -rf '$TEMPD'" 0 || die "mktemp failed"
echo "$$" > $TEMPD/$SCREENCAST_SESSION.pid
readonly SCREENCAST_ABSPATH=$(readlink -f "./$SCREENCAST_SESSION")
export SCREENCAST_SESSION SCREENCAST_ABSPATH
export JJ_EMAIL=jane.doe@example.com
export JJ_USER="Jane Doe"
export JJ_CONFIG=/dev/null	# per default, ignore user config

# == Timings ==
W=120 H=30	# cols rows
Py=26		# Y for 3 line text popup
Z=0.9		# gnome-terminal zoom
sync=0.250	# synchronizing delay, dont shorten
blink=0.034	# minimum time for next frame
slow_timings()
{
  k=0.7		# control key delay
  p=3		# user pause for reading/study
  s=0.9		# short pause (at max 1sec)
  w=0.04	# info delay
  t=0.07	# typing delay
}
slow_timings	# default

# Use fast timings for debugging
fast_timings()
{
  k=$sync
  p=$sync
  s=$sync	# use $sync as minimum
  w=0.004
  t=0.007
}
[[ "$SCREENCAST_SPEED" == fast ]] && fast_timings

# == deps ==
test -z "${TMUX-}" || die "this session must be started outside tmux"
SCREENCAST_DEPS=( nano tmux script asciinema pv )
for cmd in "${SCREENCAST_DEPS[@]}" ; do
  command -V $cmd >/dev/null ||
    die "missing command: $cmd"
done
asciinema --version >/dev/null ||
  die "failed: asciinema --version"
printf '  %-8s %s\n' OK Dependencies

# == Screencast functions ==
# rtrim, then count chars
crtrim()
(
  V="$*"
  V="${V%"${V##*[![:space:]]}"}"
  echo "${#V}"
)

# type text
T()
{
  txt="$*"
  for (( i=0; i<${#txt}; i++ )); do
    chr="${txt:$i:1}"
    if test "$chr" == ';'; then
      tmux send-keys -t $SCREENCAST_SESSION -H $(printf %x "'$chr'")
    else
      tmux send-keys -t $SCREENCAST_SESSION -l "$chr"
    fi
    sleep $t
  done
}

# send key
K()
(
  while test $# -ge 1 ; do
    KEY="$1"; shift
    [[ "${1:-}" =~ ^[1-9][0-9]*$ ]] &&
      { REPEAT="$1"; shift; } || REPEAT=1
    for (( i=0 ; i<$REPEAT; i++ )); do
      tmux send-keys -t $SCREENCAST_SESSION "$KEY"
      DK="${KEY/C-/Ctrl-}" && DK="${DK/M-/Alt-}"
      #	[[ "$DK" == "$KEY" ]] && [[ "$DK" != "Enter" ]] && sk=$k || sk=$(echo "2 * $k" | bc -l)
      field=20 && len=${#DK} && pad=$(printf '%*s' $(( (field - len) / 2 )) '')
      tmux display-popup -t $SCREENCAST_SESSION -E -B -y$Py -h1 -w$field \
	   "tput smso && printf '%-$field""s' '$pad$DK' | column && tput civis; sleep $k && exit"
      sleep $blink
    done
  done
)

Enter() { K "Enter" ; }

# synchronize (with other programs)
S()
{ sleep $s ; }

# pause (for user to observe)
P()
{ sleep $p ; }

# Display message with pause
X()
{
  echo "  $*" > $TEMPD/xmsg
  local pause=$p # $(echo "`crtrim "$*"` * $w + $p" | bc -l)
  tmux display-popup -t $SCREENCAST_SESSION -E -y$Py -h3 -w80 \
       "$SCREENCASTSDIR/slowtype.sh $w $TEMPD/xmsg && tput civis && sleep $pause && exit"
  rm $TEMPD/xmsg
  sleep $k
}

# kill-line + type-text + kill-line
Q()
{ K C-U; T "$*"; K C-U; sleep $sync; }	# fzf-query + Ctrl+U

# Q without delays
Q0()
{ tmux send-keys -t $SCREENCAST_SESSION C-U; tmux send-keys -t $SCREENCAST_SESSION -l "$*"; tmux send-keys -t $SCREENCAST_SESSION C-U; }

# == Recording ==
# Discard stdout and stderr unless `set -x` was set
stderr_to_dev_null() { [[ $- == *x* ]] || exec 2>/dev/null; }
stdout_to_dev_null() { [[ $- == *x* ]] || exec >/dev/null; }
stdio_to_dev_null()  { [[ $- == *x* ]] || exec >/dev/null 2>&1; }
stdin_discard()      ( set +x; rest=1 ; while test -n "$rest" ; do read -t 0.1 -n1 rest || : ; done )

# Configure bash and nano for screencasts
screencast_shell_setup()
{
  if test -z "${SCREENCAST_SHELL-}" ; then
    # Simplify nano exit to Ctrl+X without 'y' confirmation
    echo -e "set saveonexit"							>  $TEMPD/nanorc
    echo -e "#!/usr/bin/env bash\nexec nano --rcfile $TEMPD/nanorc \"\$@\""	>  $TEMPD/nano
    chmod +x $TEMPD/nano
    # Setup clean shell env
    echo "export HISTFILE=/dev/null"			       			>  $TEMPD/bashrc
    echo "PS1='\[\033[01;34m\]\W\[\033[00m\]\$ '"				>> $TEMPD/bashrc
    echo "export EDITOR=$TEMPD/nano"						>> $TEMPD/bashrc
    echo "export JJFZF_SHELL='/usr/bin/env bash --init-file $TEMPD/bashrc -i'"	>> $TEMPD/bashrc
    echo 'echo "$$" ' ">$TEMPD/bash-i.pid"					>> $TEMPD/bashrc
    echo "PS1='\s<\W>$ '"							>> $TEMPD/bashrc
    echo "cd $TEMPD/$SCREENCAST_SESSION"					>> $TEMPD/bashrc
    export SCREENCAST_SHELL="bash --init-file $TEMPD/bashrc -i"
  fi
}

# Find PID of asciinema for the current $SCREENCAST_SESSION
find_asciinema_pid()
{
  ps --no-headers -eo pid=,comm=,args= |
    awk -v session="$SCREENCAST_SESSION" '
    $0 ~ /asciinema.*\/python.*\/asci[i]nema rec.* tmux attach-session/ && $0 ~ session {
    	if (firstpid == "" || $1 < firstpid) firstpid = $1
    }
    END { if (firstpid != "") print firstpid }
  '
}

# Start recording with asciinema in a dedicated terminal, using $W x $H, etc
start_screencast() # start_screencast <shelldir> [send-keys..]
{
  export TERM=xterm-256color	# best agg compatibility
  printf '  %-8s %s\n' START $SCREENCAST_ABSPATH
  local DIR="$(readlink -f "${1:-.}")" ; shift
  screencast_shell_setup
  # stert new screencast session
  tmux kill-session -t $SCREENCAST_SESSION 2>/dev/null || :
  ( cd "$DIR"
    # export JJ_CONFIG=/dev/null
    tmux new-session -s $SCREENCAST_SESSION -P -d -x $W -y $H $SCREENCAST_SHELL
  ) >$TEMPD/session
  printf '  %-8s %s\n' TMUX "$SCREENCAST_SESSION"
  tmux set-option -t $SCREENCAST_SESSION status off
  tmux set-option -t $SCREENCAST_SESSION allow-rename off
  tmux send-keys -t $SCREENCAST_SESSION "exec $SCREENCAST_SHELL"$'\n'
  while ! test -r $TEMPD/bash-i.pid ; do sleep 0.1 ; done
  tmux resize-window -t $SCREENCAST_SESSION -x $W -y $H ; sleep 0.1
  tmux send-keys -t $SCREENCAST_SESSION $'clear\n' ; sleep 0.1
  while [ $# -gt 0 ] ; do
    tmux send-keys -t $SCREENCAST_SESSION "$1"
    shift
  done
  sleep $sync
  # start asciinema in bg, so this script continues
  RECORDER_C="asciinema rec --overwrite $SCREENCAST_ABSPATH.cast --cols $W --rows $H -c "
  TMUX_ATTACH_RO="tmux attach-session -t $SCREENCAST_SESSION -f read-only"
  ( set -e
    if $SCREENCAST_WINDOW ; then
      gnome-terminal --geometry $W"x"$H -t "$SCREENCAST_SESSION -- asciinema" --zoom $Z -- \
		     $RECORDER_C "$TMUX_ATTACH_RO"
    elif $SCREENCAST_HIDE ; then
      script -Enever -O $TEMPD/script.log -c \
	     "stty rows $H cols $W && $RECORDER_C '$TMUX_ATTACH_RO' " |
	pv -b -t -p -e -i 0.1 -w80 -N '  SCREENCAST' >/dev/null
    else
      script -Enever -O $TEMPD/script.log -c \
	     "stty rows $H cols $W && $RECORDER_C '$TMUX_ATTACH_RO' "
      stdin_discard	# Absorb to terminal DSR escape sequences
    fi
  ) &
  echo "$!" > $TEMPD/subshell.pid
  sleep $sync
  test -z "$(find_asciinema_pid)" && sleep $sync
  test -n "$(find_asciinema_pid)" || {
    ps --no-headers -ao pid,comm,args
    die "failed to identify asciinema process for screencast session: $SCREENCAST_SESSION"
  }
  stdin_discard	# Absorb to terminal DSR escape sequences
  true
}

# Stop recording
stop_screencast()
{
  set -Eeuo pipefail # -x
  # hard abort asciinema, so last frame is preserved
  ( set -x
    ps --no-headers -ao pid,comm,args
    kill -SIGUSR1 $(find_asciinema_pid) 	# PID=$(tmux list-panes -t $SCREENCAST_SESSION -F '#{pane_pid}')
  ) > $TEMPD/kill.log 2>&1
  tmux kill-session -t $SCREENCAST_SESSION
  ( wait -fn $(cat $TEMPD/subshell.pid) || true ) >/dev/null 2>&1
  sleep $sync
  $SCREENCAST_HIDE && echo	# leave PV line
  if $SCREENCAST_FIXTTY ; then
    stdin_discard	# Absorb to terminal DSR escape sequences
    stty sane || true	# may fail in Github CI env
    # Reset terminal state from mouse/alt-screen/etc
    reset	# does: sleep 1
    # resize
  else
    sleep $sync
  fi
  [[ $- == *x* ]] &&
    cat $TEMPD/kill.log
  printf '  %-8s %s\n' STOP $SCREENCAST_ABSPATH
}

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

# JJ_CONFIG suitable for screencasts with tight layout
make_jj_config()
(
  LOG_TMPL="${1-builtin_log_oneline}"
  cat > $TEMPD/jjfzfcast.toml <<__EOF
[template-aliases]
"commit_timestamp(commit)" = "commit.author().timestamp()"
'format_timestamp(timestamp)' = 'timestamp.local().format("%Y-%m-%d")'
'format_short_signature(signature)' = ' coalesce(signature.email().local(), email_placeholder) '
[colors]
"diff token" = { underline = false }
[jj-fzf]
# log_template = "$LOG_TMPL"
__EOF
  echo $TEMPD/jjfzfcast.toml
)

# Clone JJ repo into reproducible state (from ~/.cache/jj.git)
clone_jj_repo()
{
  local DIR="$1"
  # cd ~/.cache/ && git clone --bare --single-branch --shallow-since 2024-12-31 -b v0.29.0 git@github.com:jj-vcs/jj.git
  test -r /$HOME/.cache/jj.git/ ||
    die 'missing ~/.cache/jj.git'
  rm -rf "$DIR"
  ( stdio_to_dev_null # unless set -x
    git clone --shallow-since 2025-01-01 file://$HOME/.cache/jj.git "$DIR"
    cd "$DIR"
    rm -f .git/packed-refs .git/refs/tags/v0.3* .git/refs/tags/v0.28.2 .git/refs/tags/v0.29.0
    mkdir -p .git/refs/remotes/origin/
    echo 041c4fecb77434dd6720e7d7f1ce48d9575ac5f7 > .git/refs/remotes/origin/main
    jj git init --colocate
    jj new b9ebe2f0
    jj tag delete '*' # we just need main and the rest to be mutable
    # Keep the ancestor chain of 8b949f7e (incl. qylkzstz and wvormzwm) visible;
    # jj >= 0.39 no longer revives hidden commits during `jj rebase`.
    jj abandon --ignore-immutable '(lxuluxyq:: | sqywrslw::) & ~ancestors(8b949f7e)'
    jj rebase --destination 3aac8d21 --source 8b949f7e
  )
}
