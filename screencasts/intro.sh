#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
SCRIPTNAME=`basename $0` && function die  { [ -n "$*" ] && echo "$SCRIPTNAME: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }
ABSPATHSCRIPT=`readlink -f "$0"`
SCRIPTDIR="${ABSPATHSCRIPT%/*}"


# == functions and setup for screencasts ==
source $SCRIPTDIR/prepare.sh ${SCRIPTNAME%%.*}
# fast_timings

# SCRIPT
make_repo IntroDemo gitdev jjdev
start_asciinema IntroDemo 'jj-fzf' Enter
P  # S; T "jj-fzf"; Enter

# FILTER
X 'JJ-FZF shows and filters the `jj log`, hotkeys are used to run JJ commands'
K Down; S; K Down; P; K Down; S; K Down; P; K Down; P;
X 'The preview on the right side shows commit information and the content diff'
K Up; P; K Up; S; K Up; P; K Up; S; K Up; P;
X 'Type keywords to filter the log'
T 'd'; S; T 'o'; S; T 'm'; S; T 'a'; S; T 'i'; S; T 'n'; S; P
K BSpace 6; P

# OP-LOG
X 'Ctrl+O shows the operation log'
K C-o; P
K Down 11
X 'Ctrl+D and Ctrl+L display diff or log'
K C-d; P
K Up 11
K C-g; P

# COMMIT / DESCRIBE
# REBASE -r
# BOOKMARK + DEL
# PUSH

# HELP
X 'Ctrl+H shows the help for all hotkeys'
K C-h; P
K C-Down 11; P
# T 'g'; S; T 'i'; S; T 't'; S; P; K C-u; P; P; K Down; P; K Down; P; P;
K C-g; P


# EXIT
P
stop_asciinema
render_cast "$ASCIINEMA_SCREENCAST"
#stop_asciinema && render_cast "$ASCIINEMA_SCREENCAST" && exit
