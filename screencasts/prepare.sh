#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
die() { echo "${0##*/}: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }

[[ "${BASH_SOURCE[0]}" = "${BASH_SOURCE[0]#/}" ]] &&
  SCREENCASTSDIR="$PWD/${BASH_SOURCE[0]}" || SCREENCASTSDIR="${BASH_SOURCE[0]}"
export SCREENCASTSDIR="${SCREENCASTSDIR%/*}"
# Add jj-fzf to $PATH
PATH="$SCREENCASTSDIR/..:$PATH"

# == Config  ==
test -n "${SCREENCAST_SESSION-}" || die "missing SCREENCAST_SESSION name"
TEMPD=$(mktemp --tmpdir -d screencasts.XXXXXX) &&
  trap "rm -rf '$TEMPD'" 0 || die "mktemp failed"
echo "$$" > $TEMPD/$SCREENCAST_SESSION.pid
readonly ASCIINEMA_SCREENCAST=$(readlink -f "./$SCREENCAST_SESSION")
export SCREENCAST_SESSION ASCIINEMA_SCREENCAST
export JJ_EMAIL=jane.doe@example.com
export JJ_USER="Jane Doe"
export JJ_CONFIG=/dev/null	# per default, ignore user config


# == deps ==
test -z "${TMUX-}" || die "this session must be started outside tmux"
for cmd in nano tmux asciinema agg gif2webp gnome-terminal ffmpeg ; do
  command -V $cmd || die "missing command: $cmd"
done
asciinema --version || die "failed: asciinema --version"

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
      { N="$1"; shift; } ||
	N=1
    for (( i=0 ; i<$N; i++ )); do
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
  local S=$p # $(echo "`crtrim "$*"` * $w + $p" | bc -l)
  tmux display-popup -E -y$Py -h3 -w80 "$SCREENCASTSDIR/slowtype.sh $w $TEMPD/xmsg && tput civis && sleep $S && exit"
  rm $TEMPD/xmsg
  sleep $k
}

# kill-line + type-text + kill-line
Q()
{ K C-U; T "$*"; K C-U; S; }	# fzf-query + Ctrl+U

# Q without delays
Q0()
{ tmux send-keys -t $SCREENCAST_SESSION C-U; tmux send-keys -t $SCREENCAST_SESSION -l "$*"; tmux send-keys -t $SCREENCAST_SESSION C-U; }

# == Recording ==
# Find PID of asciinema for the current $SCREENCAST_SESSION
find_asciinema_pid()
{
  ps --no-headers -ao pid,comm,args |
    awk "/asci[i]nema rec.*\\<$SCREENCAST_SESSION\\>/{ print \$1 }"
}

# Start recording with asciinema in a dedicated terminal, using $W x $H, etc
start_asciinema() # start_asciinema <shelldir> [send-keys..]
{
  DIR="$(readlink -f "${1:-.}")" ; shift
  # Setup clean shell env
  echo "export HISTFILE=/dev/null"			       			>  $TEMPD/bashrc
  echo "PS1='\[\033[01;34m\]\W\[\033[00m\]\$ '"					>> $TEMPD/bashrc
  echo "export EDITOR='/usr/bin/env nano --rcfile $TEMPD/nanorc'"		>> $TEMPD/bashrc
  echo "export JJFZF_SHELL='/usr/bin/env bash --rcfile $TEMPD/bashrc -i'"	>> $TEMPD/bashrc
  echo 'echo "$$" ' ">$TEMPD/bash-i.pid"					>> $TEMPD/bashrc
  # Simplify nano exit to Ctrl+X without 'y' confirmation
  echo -e "set saveonexit"							>  $TEMPD/nanorc
  # stert new screencast session
  tmux kill-session -t $SCREENCAST_SESSION 2>/dev/null || :
  ( cd "$DIR"
    # export JJ_CONFIG=/dev/null
    tmux new-session -s $SCREENCAST_SESSION -P -d -x $W -y $H
  ) >$TEMPD/session
  echo "tmux-session: $SCREENCAST_SESSION"
  tmux set-option -t $SCREENCAST_SESSION status off
  tmux send-keys -t $SCREENCAST_SESSION "source $TEMPD/bashrc"$'\n'
  while ! test -r $TEMPD/bash-i.pid ; do sleep 0.1 ; done
  tmux resize-window -t $SCREENCAST_SESSION -x $W -y $H ; sleep 0.1
  tmux send-keys -t $SCREENCAST_SESSION $'clear\n' ; sleep 0.1
  while [ $# -gt 0 ] ; do
    tmux send-keys -t $SCREENCAST_SESSION "$1"
    shift
  done
  sleep 0.2
  gnome-terminal --geometry $W"x"$H -t "$SCREENCAST_SESSION -- asciinema" --zoom $Z  -- \
		 asciinema rec --overwrite "$ASCIINEMA_SCREENCAST.cast" -c "tmux attach-session -t $SCREENCAST_SESSION -f read-only"
  while test -z "$(find_asciinema_pid)" ; do
    sleep 0.1 # dont save PID, this might be an early pid still forking
  done
}

# Stop recording
stop_asciinema()
(
  set -Eeuo pipefail -x
  PID=$(find_asciinema_pid)	# PID=$(tmux list-panes -t $SCREENCAST_SESSION -F '#{pane_pid}')
  kill -15 $PID	# hard abort asciinema, so last frame is preserved
  tmux kill-session -t $SCREENCAST_SESSION
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
(
  DIR="$1"
  # cd ~/.cache/ && git clone --bare git@github.com:jj-vcs/jj.git'
  test -r /$HOME/.cache/jj.git/ ||
    die 'missing ~/.cache/jj.git'
  rm -rf "$DIR"
  # set -x
  git clone --shallow-since 2025-01-01 file://$HOME/.cache/jj.git "$DIR"
  cd "$DIR"
  rm -r .git/packed-refs .git/refs/tags/v0.3* .git/refs/tags/v0.28.2 .git/refs/tags/v0.29.0
  echo 041c4fecb77434dd6720e7d7f1ce48d9575ac5f7 > .git/refs/remotes/origin/main
  jj git init --colocate
  jj new b9ebe2f0
  jj abandon --ignore-immutable ' 3e51038d:: | sqywrslw::'
  jj rebase --destination 3aac8d21 --source 8b949f7e
)
