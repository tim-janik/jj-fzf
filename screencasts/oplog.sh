#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x

readonly SCREENCAST_SESSION=oplog-demo
source $(dirname $(readlink -f "${BASH_SOURCE[0]}"))/prepare.sh	"$@" # for $TEMPD and funcs
H=40

# == Config ==
export JJ_CONFIG=$(make_jj_config)
clone_jj_repo $TEMPD/$SCREENCAST_SESSION
( cd $TEMPD/$SCREENCAST_SESSION
  jj b t main@origin
  jj new -m Merge qylkzstz wvormzwm
  jj new
  jj abandon
  echo -e '\n## DemoSection' >> README.md
  jj st
  echo -e '\nThis MESSAGE was added for the oplog demo.' >> README.md
  jj describe -m 'README.md: add MESSAGE to DemoSection'
) > $TEMPD/bookmarks.log 2>&1

SNAP1=$(cd $TEMPD/$SCREENCAST_SESSION && jj --ignore-working-copy log --no-graph -T commit_id -r @)

# screencast_shell_setup && $SCREENCAST_SHELL ; exit

D() ( K Down )
U() ( K Up )
Tab() ( K Tab )

#  1234567890123456789012345678901234567890123456789012345678901234567890123456

# == SCRIPT ==
start_screencast $TEMPD/$SCREENCAST_SESSION \
		 'jj-fzf' Enter

# -- oplog --
X "Press Ctrl-O to view the operations behind the top commit to README.md"
K C-o; S
D; S
X "Press Enter to view the details of the selected operation"
K Enter; P; K q; S
D; S
X "These two operations added 'MESSAGE' and 'DemoSection' to the top commit"
U; P
D; P

# -- inject --
X "Press Alt-J to inject the earlier operation as a separate commit"
K M-j ; P
D; P
K C-d
T 'README.md: add DemoSection'; S; K C-x; S
X "The earlier snapshot has been turned into its own commit"

# -- undo --
U; K C-n; S
X 'Press Alt-Z to undo the most recent `jj new` command'
K M-z; S; K M-z; P

# -- redo --
X "Oops, that was too much undo, let's inspect the oplog and redo"
K C-o; S
X "Undo steps are indicated by the '⋯' marker in the oplog"
D; S; D; S; D; P
X 'Press Alt-Y to redo the `jj describe` step and restore the commit message'
K M-y; P; K C-g; P

SNAP2=$(cd $TEMPD/$SCREENCAST_SESSION && jj --ignore-working-copy log --no-graph -T commit_id -r @)

# -- restore --
X "Enough trying, let's restore the repository to the initial state"
K C-o; S
D;D;D;D; D;D;D; P
X 'Press Alt-R to restore the repository to the selected operation'
K M-r; S; K C-g; P
X "Repo restored - no commits were harmed in this demonstration"
P

# == EXIT ==
P; T ' '
stop_screencast

SNAP3=$(cd $TEMPD/$SCREENCAST_SESSION && jj --ignore-working-copy log --no-graph -T commit_id -r @)

( cd $TEMPD/$SCREENCAST_SESSION
  test -n "$SNAP1" -a -n "$SNAP2" -a -n "$SNAP3" ||
    die 'test snapshots failed'
  test "$SNAP1" != "$SNAP2" ||
    die 'SNAP1 -> SNAP2 failed to make progress'
  test "$SNAP1" == "$SNAP3" ||
    die 'SNAP1 -> SNAP3 failed to restore'
)

printf '  %-8s %s\n' OK "$SCREENCAST_SESSION passed"
