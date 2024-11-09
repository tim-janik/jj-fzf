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
DIR=MegaMergeDemo
( rm -rf $DIR
  set -x
  git clone --no-hardlinks --single-branch --branch trunk $(cd  $SCRIPTDIR && git rev-parse --git-dir) $DIR
  cd $DIR
  git update-ref refs/remotes/origin/trunk f2c149e
  git tag -d `git tag`
  # git reset --hard f2c149e
  jj git init --colocate
  jj b s trunk -r f2c149e --allow-backwards
  jj bookmark track trunk@origin
  jj new -r f2c149e
  jj b c two-step-duplicate-and-backout -r 7d3dae8
  jj abandon b19d586:: && jj rebase -s bf7fd9d -d f2c149e
  jj b c bug-fixes -r f93824e
  jj abandon 56a3cbb:: && jj rebase -s bed3bcd -d f2c149e
  jj abandon 249a167:: # jj b c screencast-scripts -r 69fd52e
  # jj abandon 4951884:: && jj rebase -s 249a167 -d f2c149e
  jj abandon 5cf1278:: # jj b c readme-screencasts -r 8c3d950
  # jj abandon 66eb19d:: && jj rebase -s 5cf1278 -d f2c149e
  jj b c homebrew-fixes -r c1512f4
  jj abandon 5265ff6::
  jj new @-
)

# SCRIPT
start_asciinema $DIR 'jj-fzf' Enter
X 'The "Mega-Merge" workflow operates on a selection of feature branches'

# FIRST NEW
X 'Use Ctrl+N to create a new commit based on a feature branch'
K PageUp Down; P
K C-n; P
X 'Use Ctrl+D to give the Mega-Merge head a unique marker'
K C-d
T $'= = = = = = = =\n'; P;
K C-x; P		# nano

# ADD PARENTS
X 'Alt+P starts the Parent editor for the selected commit'
K M-p; P
X 'Alt+A and Alt+D toggle between adding and deleting parents'
K M-d; P; K M-a; P; K M-d; P; K M-a; P
X 'Pick branches and use Tab to add parents'
#K Down; K Tab; P	# readme-screencasts
Q "two-step-duplicate-and-backout"; K Tab; P
Q "bug-fixes"; K Tab; P
Q "homebrew-fixes"; K Tab; P
X 'Enter: run `jj rebase` to add the selected parents'
K Enter; P
X 'The working copy now contains 3 feature branches'

# NEW COMMIT
X 'Ctrl+N starts a new commit'
K C-n; P
X 'Ctrl+Z starts a subshell'
K C-z; P
T '(echo; echo "## Multi-merge") >>README.md && exit'; P; K Enter; P
X 'Alt+C starts the text editor and creates a commit'
K M-c; K End; P
T 'start multi-merge section'; P
K C-x; P		# nano

# ADD BRANCH
K PageUp; K Down 2
X 'Alt+N: Insert a new parent (adds a branch to merge commits)'
K M-n; P
Q "\ @\ "
X 'Alt+B: Assign/move a bookmark to a commit'
K M-b; T 'cleanup-readme'; P; K Enter

# REBASE before
K PageUp; P
X 'Alt+R allows rebasing a commit into a feature branch'
K M-r;
X 'Use Alt+R and Ctrl+B to rebase a single revision before another'
K M-r; P
Q "\ @\ "	# "cleanup-readme"
K C-b; P
X 'Enter: rebase with `jj rebase --revisions --insert-before`'
K Enter; P

# SQUASH COMMIT
K PageUp
X 'Ctrl+N starts a new commit'
K C-n; P
X 'Ctrl+Z starts a subshell'
K C-z; P
T '(echo; echo "Alt+P enables the Multi-Merge workflow.") >>README.md && exit'; P; K Enter; P
K C-d End; P
T 'describe Alt+P'; P
K C-x; S		# nano
X 'The working copy changes can be squashed into a branch'
Q "cleanup-readme"; P
X 'Alt+W: squash the contents of the working copy into the selected revision'
K M-w; P; P;
X 'The commit now contains the changes from the working copy'
K PageUp; P;
X 'The working copy is now empty'

# UPSTREAM-MERGE
X "Let's merge the new branch into upstream and linearize history"
Q "cleanup-readme"; P
X 'Alt+M: start merge dialog'
K M-m Down 3; P
X 'Alt+U: upstream merge - add tracked bookmark to merge parents'
K M-u; P
X 'Enter: edit commit message and create upstream merge'
K Enter; P; K C-k; P; K C-x; P      # nano

# REBASE MegaMerge head
K PageUp; K Down 2; P
X 'Alt+R: rebase the Mega-Merge head onto the working copy'
K M-r; P
X "Alt+P: simplify-parents after rebase to remove old parent edges"
K M-p; P
X "Enter: rebase onto 'trunk' and also simplify parents"
K Enter; P

# NEW
K PageUp
X 'Use Ctrl+N to prepare the next commit'
K C-n; P

# OUTRO
X "The new feature can be pushed with 'trunk' and the Mega-Merge head is rebased"
P; P

# EXIT
P
stop_asciinema
render_cast "$ASCIINEMA_SCREENCAST"
ffmpeg -ss 00:02:32 -i megamerge.mp4 -frames:v 1 -q:v 2 -y megamerge230.jpg
