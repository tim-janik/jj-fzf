#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x

readonly SCREENCAST_SESSION=merging-demo
source $(dirname $(readlink -f "${BASH_SOURCE[0]}"))/prepare.sh	"$@" # for $TEMPD and funcs

# == Config ==
export JJ_CONFIG=$(make_jj_config)
( stdio_to_dev_null
  cd $TEMPD && make_repo -3tips $SCREENCAST_SESSION gitdev jjdev
)

# == SCRIPT ==
start_screencast $TEMPD/$SCREENCAST_SESSION \
		 'jj-fzf' Enter

# -- Merge 2 --
X 'To create a merge commit, select the commits to merge with Tab'
K Down; P	# trunk
K Tab; P
K Down; P	# jjdev
K Tab; P
X 'Ctrl+N creates a new commit with all selected revisions as parents'
K C-n; P
X 'Ctrl+D starts the text editor with a suggested merge commit message'
K C-d; P
K C-k; T "Merge 'jjdev' into 'trunk'"; K Enter; P
K C-x; S	# nano
X 'The new merge commit is now the working copy'

# -- Undo --
X 'Alt+Z undoes the last operation, use it twice to undo describe and merge'
K M-z; P
K M-z; P
X 'The repository is back to 3 unmerged branches'

# -- Merge 3 --
X 'Select three revisions for an octopus merge'
K C-Left; K Down; P	# trunk
K Tab; P
K Down; P	# jjdev
K Tab; P
K Down 2; P	# gitdev
K Tab; P
X 'Ctrl+N creates the merge commit'
K C-n; P
X 'Ctrl+D starts the text editor to describe the merge commit'
K C-d; P
K C-k; T "Merge 'gitdev' and 'jjdev' into 'trunk'"; K Enter; P
K C-x; S	# nano
X 'This is an Octopus merge, a commit can have any number of parents'
P; P

# == EXIT ==
P
stop_screencast

( cd $TEMPD/$SCREENCAST_SESSION
  test "$(jj log --no-graph -T 'description.first_line()' -r @)" == "Merge 'gitdev' and 'jjdev' into 'trunk'" ||
    die 'failed to describe the octopus merge'
  test "$(jj log --no-graph -T change_id -r '@- ~ (trunk | jjdev | gitdev)')" == "" &&
    test "$(jj log --no-graph -T '"x"' -r '@-')" == xxx ||
      die 'failed to merge trunk, jjdev and gitdev'
)

printf '  %-8s %s\n' OK "$SCREENCAST_SESSION passed"
