#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail # -x
SCRIPTNAME=`basename $0` && function die  { [ -n "$*" ] && echo "$SCRIPTNAME: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }
ABSPATHSCRIPT=`readlink -f "$0"`
SCRIPTDIR="${ABSPATHSCRIPT%/*}"


# == functions and setup for screencasts ==
source $SCRIPTDIR/prepare.sh ${SCRIPTNAME%%.*}
# fast_timings

# SCRIPT
make_repo -squashall SplittingDemo gitdev jjdev
start_asciinema SplittingDemo 'jj-fzf' Enter

X 'When the working copy has lots of changes in lots of files...'

# SPLIT FILES
X 'Alt+F can split the current revision into one commit per file'
K M-f; P
K Down; P; K Down; P; K Down; P
K Up  ; P; K Up  ; P; K Up  ; P

# DESCRIBE
K Down; P
X 'Ctrl+D opens the text editor to describe the commit'
K C-d; S; K End; P
T 'marker left by jj'; P
K C-x; P	# nano

# ABANDON
K Down; P
X 'Alt+A abandons a commit'
K M-a; P

# SPLIT INTERACTIVELY
K Home; P
X 'Alt+I starts `jj split` interactively'
X 'Use Mouse Clicks to explore the interactive editor'
K M-i
P
tmux send-keys -H 1b 5b 4d 20 24 21    1b 5b 4d 23 24 21   # FILE
P
tmux send-keys -H 1b 5b 4d 20 2a 21    1b 5b 4d 23 2a 21   # EDIT
P
tmux send-keys -H 1b 5b 4d 20 32 21    1b 5b 4d 23 32 21  # SELECT
P
tmux send-keys -H 1b 5b 4d 20 3a 21    1b 5b 4d 23 3a 21   # VIEW
P
tmux send-keys -H 1b 5b 4d 20 3a 21    1b 5b 4d 23 3a 21   # VIEW (hides)
P
T 'F'; P
K Down
K Down
K Enter
K Enter
K Enter
K Enter
K Enter
K Enter; P
T 'ac'; P
X 'With the diff split up, each commit can be treated individually'

# DESCRIBE
K Down; P
K C-d; S; K End; P
T 'add brief description'; P
K C-x; P	# nano

# DESCRIBE
K Up; P
K C-d; S; K End; P
T 'add front-matter + date'; P
K C-x; P	# nano

# DIFF-EDIT
X 'Alt+E starts `jj diffedit` to select diff hunks to keep'
K M-e; P;
K F; K a; K Down 3; K Space; P
K c; P
K C-d; S; K End; P
K BSpace 7; P
K C-x; P	# nano

# UNDO
X 'Or, use Alt+Z Alt+Z to undo the last 2 steps and keep the old front-matter'
K M-z ; P
K M-z ; P

# NEW
K Home
X 'Create a new, empty change with Ctrl+N to edit the next commit'
K C-n; P

# EXIT
P
stop_asciinema
render_cast "$ASCIINEMA_SCREENCAST"
