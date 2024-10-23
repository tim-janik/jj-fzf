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

# FIXME: remove empty commits upfront

# FILTER
X 'JJ-FZF shows and filters the `jj log`, hotkeys are used to run JJ commands'
K Down; K Down
X 'The preview on the right side shows commit information and the content diff'
K Up; K Up
X 'Type keywords to filter the log'
T 'd'; S
T 'o'; S
T 'm'; S
T 'a'; S
T 'i'; S
T 'n'; S
P
K BSpace; S
K BSpace; S
K BSpace; S
K BSpace; S
K BSpace; S
K BSpace; S
P

# COMMIT / DESCRIBE

# REBASE -r

# BOOKMARK + DEL

# PUSH




# HELP
X 'Ctrl+H shows the help for all hotkeys'
K C-h; P
K C-Down C-Down C-Down C-Down C-Down C-Down C-Down C-Down C-Down C-Down C-Down; P
T 'g'; S
T 'i'; S
T 't'; S; P
K C-u; P; P
K Down; P
K Down; P; P
K C-g; P; P

# EXIT
P
stop_asciinema
render_cast "$ASCIINEMA_SCREENCAST"
#stop_asciinema && render_cast "$ASCIINEMA_SCREENCAST" && exit
