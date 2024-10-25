#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail # -x
SCRIPTNAME=`basename $0` && function die  { [ -n "$*" ] && echo "$SCRIPTNAME: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }
ABSPATHSCRIPT=`readlink -f "$0"`
SCRIPTDIR="${ABSPATHSCRIPT%/*}"

# == functions and setup for screencasts ==
source $SCRIPTDIR/prepare.sh ${SCRIPTNAME%%.*}
# fast_timings

# CLONE REPO
( rm -rf dest
  git clone --no-hardlinks --single-branch --branch master $(cd  $SCRIPTDIR && git rev-parse --git-dir) dest
  cd dest
  git update-ref refs/remotes/origin/master d398b973
  git reset --hard b04d2f21
  jj git init --colocate
  jj b s master -r d398b973 --allow-backwards
  jj new -r c1ee758b
  jj abandon b04d2f21
  jj b c splittingdemo -r 6e0092ca
  jj b c diffedit -r 6d0a76d2
  jj b c homebrew-fixes -r abb91c8e
  jj rebase -r splittingdemo -d 6a472b0b # -> -A -B 6d0a76d2
  jj rebase -s homebrew-fixes-  -d 82ae8b2d
  jj new @-
)

# SCRIPT
start_asciinema dest 'jj-fzf' Enter

# REBASE -r -A
X 'To rebase commits, navigate to the target revision'
K Down 10; P	# splittingdemo
X 'Alt+R starts the Rebase dialog'
K M-r; P
X 'Alt+B: --branch  Alt+R: --revisions  Alt+S: --source'
K M-b; P; K M-s; P; K M-r; P; K M-b; P; K M-s; P; K M-r; P
X 'Select destination revision'
K Down 3; P	# diffedit
X 'Ctrl+A: --insert-after  Ctrl+B: --insert-before  Ctrl+D: --destination'
K C-b; P; K C-a; P; K C-d; P; K C-b; P; K C-a; P
X 'Enter: run the `jj rebase` to rebase with --revisions --insert-after'
Enter; P
X 'Revision "splittingdemo" was inserted *after* "diffedit"'
P; P

# UNDO
X 'To start over, Alt+Z will undo the last rebase'
K M-z; P
P; P

# REBASE -r -B
X 'Alt+R starts the Rebase dialog'
K M-r; P
X 'Alt+B: --branch  Alt+R: --revisions  Alt+S: --source'
K M-b; P; K M-s; P; K M-r; P; K M-b; P; K M-s; P; K M-r; P
X 'Select destination revision'
K Down 3; P	# diffedit
X 'Ctrl+A: --insert-after  Ctrl+B: --insert-before  Ctrl+D: --destination'
K C-a; P; K C-b; P; K C-d; P; K C-a; P; K C-b; P
X 'Enter: run the `jj rebase` to rebase with --revisions --insert-before'
Enter; P
X 'Revision "splittingdemo" was inserted *before* "diffedit"'
P; P

# REBASE -b -d
X 'Select the "homebrew-fixes" bookmark to rebase'
K Down 7; P	# homebrew-fixes
X 'Alt+R starts the Rebase dialog'
K M-r; P
X 'Keep `jj rebase --branch --destination` at its default'
K Down; P	# @-
X 'Enter: rebase "homebrew-fixes" onto HEAD@git'
Enter; P
X 'The "homebrew-fixes" branch was moved on top of HEAD@git'
P; P

# REBASE -s -d
X 'Or, select a "homebrew-fixes" ancestry commit to rebase'
K Home; K Down; P	# homebrew-fixes-
X 'Alt+R starts the Rebase dialog'
K M-r; P
X 'Use Alt+S for `jj rebase --source --destination` to rebase a subtree'
K Down 9; P	# @-
K M-s; P
X 'Enter: rebase the "homebrew-fixes" subtree onto "merge-commit-screencast"'
Enter; P
K Down 7; P
X 'The rebase now moved the "homebrew-fixes" parent commit and its descendants'
P; P

# EXIT
P
stop_asciinema
render_cast "$ASCIINEMA_SCREENCAST"
