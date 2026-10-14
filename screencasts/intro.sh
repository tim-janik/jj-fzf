#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x

readonly SCREENCAST_SESSION=intro-demo
source $(dirname $(readlink -f "${BASH_SOURCE[0]}"))/prepare.sh	"$@" # for $TEMPD and funcs

# == Config ==
export JJ_CONFIG=$(make_jj_config)
( stdio_to_dev_null
  cd $TEMPD && make_repo $SCREENCAST_SESSION gitdev jjdev
)
OPID=$(jj -R $TEMPD/$SCREENCAST_SESSION op log --no-graph -n1 -T id)

# == SCRIPT ==
start_screencast $TEMPD/$SCREENCAST_SESSION \
		 'jj-fzf' Enter
P

# -- Log --
X 'JJ-FZF shows the `jj log`, hotkeys are used to run JJ commands'
K Down; S; K Down; P; K Down; S; K Down; P; K Down; P
X 'The preview on the right side shows commit information and the content diff'
K Up; P; K Up; S; K Up; P; K Up; S; K Up; P

# -- Oplog --
X 'Ctrl-O shows the operation log'
K C-o; P
K Down 5; P
K Up 5; P
K C-g; P

# -- Help --
X 'Ctrl-H shows the manual page with all hotkeys'
K C-h; P
K PageDown; P; K PageDown; P
T 'q'; P

# == EXIT ==
P
stop_screencast

test "$OPID" == "$(jj -R $TEMPD/$SCREENCAST_SESSION op log --no-graph -n1 -T id)" ||
  die 'browsing must not change the repository'

printf '  %-8s %s\n' OK "$SCREENCAST_SESSION passed"
