#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x

readonly SCREENCAST_SESSION=rebasing-demo
source $(dirname $(readlink -f "${BASH_SOURCE[0]}"))/prepare.sh	"$@" # for $TEMPD and funcs

# == Config ==
export JJ_CONFIG=$(make_jj_config)
clone_jjfzf_repo $TEMPD/$SCREENCAST_SESSION 5265ff6
( stdio_to_dev_null
  cd $TEMPD/$SCREENCAST_SESSION
  git update-ref refs/remotes/origin/trunk 97d796b
  jj git init --colocate
  jj b s trunk -r 97d796b --allow-backwards
  jj new -r f2c149e
  jj abandon 5265ff6
  jj b c splittingdemo -r 9325d16
  jj b c diffedit -r 685fd50
  jj b c homebrew-fixes -r c1512f4
  jj rebase -r splittingdemo -d f3b860c # -> -A -B 685fd50
  jj rebase -s homebrew-fixes-  -d 8f18758
  jj new @-
)

# == SCRIPT ==
start_screencast $TEMPD/$SCREENCAST_SESSION \
		 'jj-fzf' Enter

# REBASE -r -A
X 'To rebase commits, navigate to the target revision'
K Down 6; P	# splittingdemo
X 'Alt+R starts the Rebase dialog'
K M-r; P
X 'Alt+B: --branch  Alt+R: --revisions  Alt+S: --source'
K M-b; P; K M-s; P; K M-r; P; K M-b; P; K M-s; P; K M-r; P
X 'Select destination revision'
K Up 4; P	# diffedit
X 'Ctrl+A: --insert-after  Ctrl+B: --insert-before  Ctrl+D: --destination'
K C-b; P; K C-a; P; K C-d; P; K C-b; P; K C-a; P
X 'Enter: run `jj rebase` to rebase with --revisions --insert-after'
K Enter; P
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
K Up 4; P	# diffedit
X 'Ctrl+A: --insert-after  Ctrl+B: --insert-before  Ctrl+D: --destination'
K C-a; P; K C-b; P; K C-d; P; K C-a; P; K C-b; P
X 'Enter: run `jj rebase` to rebase with --revisions --insert-before'
K Enter; P
X 'Revision "splittingdemo" was inserted *before* "diffedit"'
P; P

# REBASE -b -d
X 'Select the "homebrew-fixes" bookmark to rebase'
K Down 5; P	# homebrew-fixes
X 'Alt+R starts the Rebase dialog'
K M-r; P
X 'Alt+B: use `jj rebase --branch` to rebase the entire branch'
K M-b; P
X 'Select HEAD@git as destination'
K Up 10; P	# @-
X 'Enter: rebase "homebrew-fixes" onto HEAD@git'
K Enter; S; K PageUp 3; P
X 'The "homebrew-fixes" branch was moved on top of HEAD@git'
P; P

# REBASE -s -d
X 'Or, select a "homebrew-fixes" ancestry commit to rebase'
K Down 2; P	# homebrew-fixes-
X 'Alt+R starts the Rebase dialog'
K M-r; P
X 'Use Alt+S for `jj rebase --source --destination` to rebase a subtree'
K Down 4; P	# merge-commit-screencast
K M-s; P
X 'Enter: rebase the "homebrew-fixes" subtree onto "merge-commit-screencast"'
K Enter; P
K Down 7; P
X 'The rebase now moved the "homebrew-fixes" parent commit and its descendants'
P; P

# == EXIT ==
P
stop_screencast

( cd $TEMPD/$SCREENCAST_SESSION
  test -n "$(jj log --no-graph -T change_id -r 'diffedit- & splittingdemo')" ||
    die 'failed to rebase splittingdemo before diffedit'
  test -n "$(jj log --no-graph -T change_id -r 'homebrew-fixes-- & 66c8ec6e')" ||
    die 'failed to rebase the homebrew-fixes subtree onto 66c8ec6e'
)

printf '  %-8s %s\n' OK "$SCREENCAST_SESSION passed"
