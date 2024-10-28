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
make_repo -3tips MergingDemo gitdev jjdev
start_asciinema MergingDemo 'jj-fzf' Enter

# GOTO rev
X 'To create a merge commit, pick the first commit to be merged'
Q0 "trunk"; S

# MERGE-2
X 'Alt+M starts the Merge dialog'
K M-m; P
K 'Down'; K 'Down'
Q "jjdev"
X 'Tab selects another revision to merge with'
K Tab; P
X 'Enter starts the text editor to describe the merge'
K Enter; P
K C-k; P; K C-x; S	# nano
X 'The newly created merge commit is now the working copy'

# UNDO
X 'Alt+Z will undo the last operation (the merge)'
K M-z ; P
X 'The repository is back to 3 unmerged branches'

# MERGE-3
X 'Select a revision to merge'
K Down; K Down; K Down
Q0 "gitdev"; S
X 'Alt+M starts the Merge dialog, now for an octopus merge'
K M-m; P
K Down; Q0 "trunk"; S
K Tab; S
K Down; Q0 "jjdev"; S
X 'Tab again selects the third revision'
K Tab; S
X 'Enter starts the text editor to describe the merge'
K Enter; P
K C-k; P; K C-x; S	# nano
X 'The newly created merge commit is now the working copy'
X 'Ctrl+D starts the text editor to alter the description'
K C-d; P
K C-k 16
T "Merge 'gitdev' and 'jjdev' into 'trunk'"; P
K C-x; S		# nano
X 'This is an Octopus merge, a commit can have any number of parents'
P; P

# EXIT
P
stop_asciinema
render_cast "$ASCIINEMA_SCREENCAST"
