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
X 'Select a revision as Merge Base'
Q0 "trunk"; S

# MERGE-2
X 'Alt+M starts the Merge dialog'
K M-m; P
K 'Down'; K 'Down'
Q "jjdev"
X 'Tab selects a revision'
K Tab; P
X 'Enter creates the merge commit and starts the text editor'
K Enter; P
K C-k; P; K C-x; S	# nano
X 'The commits are merged. For 2 parents, jj-fzf suggests a commit message'

# UNDO
X 'Alt+Z will undo the last operation (the merge)'
K M-z ; P
X 'The repository is back to 3 unmerged branches'

# MERGE-3
X 'Select a revision to merge'
K Down; K Down; K Down
Q0 "gitdev"; S
X 'Alt+M starts the Merge dialog for an octopus merge'
K M-m; P
K Down; Q0 "trunk"; S
K Tab; S
K Down; Q0 "jjdev"; S
X 'Tab again selects the third revision'
K Tab; S
X 'Enter creates the merge commit'
K Enter; P
X 'Ctrl+D starts the text editor to describe the commit'
K C-d; S
T "Merge 'gitdev' and 'jjdev' into 'trunk'"; P
K C-x; S		# nano
X 'This is an Octopus merge, a commit can have any number of parents'

# EXIT
P
stop_asciinema
render_cast "$ASCIINEMA_SCREENCAST"
