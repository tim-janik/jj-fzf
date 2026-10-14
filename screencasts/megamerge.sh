#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x

readonly SCREENCAST_SESSION=megamerge-demo
source $(dirname $(readlink -f "${BASH_SOURCE[0]}"))/prepare.sh	"$@" # for $TEMPD and funcs

# == Config ==
export JJ_CONFIG=$(make_jj_config)
clone_jjfzf_repo $TEMPD/$SCREENCAST_SESSION ad3b2ad
( stdio_to_dev_null
  cd $TEMPD/$SCREENCAST_SESSION
  git update-ref refs/remotes/origin/trunk f2c149e
  jj git init --colocate
  jj b s trunk -r f2c149e --allow-backwards
  jj bookmark track trunk@origin
  jj new -r f2c149e
  jj b c two-step-duplicate-and-backout -r 7d3dae8
  jj abandon b19d586:: && jj rebase -s bf7fd9d -d f2c149e
  jj b c bug-fixes -r f93824e
  jj abandon 56a3cbb:: && jj rebase -s bed3bcd -d f2c149e
  jj abandon 249a167::
  jj abandon 5cf1278::
  jj b c homebrew-fixes -r c1512f4
  jj abandon 5265ff6::
  jj new @-
)

# == SCRIPT ==
start_screencast $TEMPD/$SCREENCAST_SESSION \
		 'jj-fzf' Enter
X 'The "Mega-Merge" workflow operates on a selection of feature branches'

# -- Mega-Merge head --
X 'Use Ctrl+N to create a new commit based on a feature branch'
K Down; P	# bug-fixes
K C-n; P
X 'Use Ctrl+D to give the Mega-Merge head a unique marker'
K C-d; S
T '= = = = = = = ='; P
K C-x; P	# nano

# -- Add parents --
X 'Alt+P starts the Parent editor for the selected commit'
K M-p; P
X 'Alt+A and Alt+D toggle between adding and deleting parents'
K M-d; P; K M-a; P; K M-d; P; K M-a; P
X 'Pick branches and use Tab to add parents'
Q "two-step-duplicate-and-backout"; K Tab; P
Q "homebrew-fixes"; K Tab; P
X 'Enter: run `jj rebase` to add the selected parents'
K Enter; P
X 'The working copy now contains 3 feature branches'

# -- New commit --
X 'Ctrl+N starts a new commit'
K C-n; P
X 'Ctrl+Z starts a subshell'
K C-z; P
T '(echo; echo "## Multi-merge") >>README.md && exit'; P; K Enter; P
X 'Ctrl+D describes the new commit'
K C-d; S
T 'start multi-merge section'; P
K C-x; P	# nano

# -- Rebase into branch --
X 'Alt+R allows rebasing a commit into a feature branch'
K M-r; P
X 'Use Alt+R and Ctrl+A to insert the revision after "bug-fixes"'
K M-r; P
K Down 2; P	# bug-fixes
K C-a; P
X 'Enter: rebase with `jj rebase --revisions --insert-after`'
K Enter; P
K Down; P	# start multi-merge section
X 'Alt+B: move the "bug-fixes" bookmark to the new commit'
K M-b; S
T 'bug-fixes'; P
K Enter; P

# -- Squash into branch --
K C-Left; P	# Mega-Merge head
X 'Ctrl+N starts a new commit'
K C-n; P
K C-z; P
T '(echo; echo "Alt+P enables the Multi-Merge workflow.") >>README.md && exit'; P; K Enter; P
X 'The working copy changes can be squashed into a branch'
K Tab; P	# select @
K Down; P	# bug-fixes
X 'Alt+Q: squash the selected working copy into the revision under the cursor'
K M-q; P
X 'The working copy is now empty, "bug-fixes" contains its changes'
P

# -- Upstream merge --
X "Let's merge the \"bug-fixes\" branch into 'trunk'"
K C-Left; K Down 2; P	# bug-fixes
K Tab; P
K Down 7; P	# trunk
K Tab; P
X 'Ctrl+N creates the merge commit'
K C-n; P
K C-d; P
K C-k; T "Merge branch 'bug-fixes'"; K Enter; P
K C-x; S	# nano
X "Alt+B: move the 'trunk' bookmark to the merge commit"
K M-b; S
T 'trunk'; P
K Enter; P

# -- Rebase Mega-Merge head --
K Down; P	# Mega-Merge head
X 'Alt+P: add the new trunk merge as parent of the Mega-Merge head'
K M-p; P
K Up; K Tab; P	# trunk merge
X 'Alt+P: simplify-parents removes the old "bug-fixes" parent edge'
K M-p; P
X 'Enter: run `jj rebase` and `jj simplify-parents`'
K Enter; P

# -- New --
K C-Left; P	# Mega-Merge head
X 'Use Ctrl+N to prepare the next commit'
K C-n; P
X "The branch is merged into 'trunk' and the Mega-Merge head is rebased onto it"
P; P

# == EXIT ==
P
stop_screencast

( cd $TEMPD/$SCREENCAST_SESSION
  test -z "$(jj log --no-graph -T change_id -r 'conflicts()')" ||
    die 'unexpected conflicts'
  test -n "$(jj log --no-graph -T change_id -r 'trunk- & bug-fixes')" ||
    die "failed to merge bug-fixes into trunk"
  test "$(jj log --no-graph -T '"x"' -r '@--')" == xxx &&
    test -z "$(jj log --no-graph -T change_id -r '@-- ~ (trunk | two-step-duplicate-and-backout | homebrew-fixes)')" ||
      die 'failed to rebase the Mega-Merge head'
  jj file show -r bug-fixes README.md | grep -q 'Alt+P enables the Multi-Merge workflow' ||
    die 'failed to squash into bug-fixes'
)

printf '  %-8s %s\n' OK "$SCREENCAST_SESSION passed"
