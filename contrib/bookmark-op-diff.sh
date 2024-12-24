#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
SCRIPTNAME=`basename $0` && function die  { [ -n "$*" ] && echo "$SCRIPTNAME: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }

BOOKMARK="$1"

TEMPD="`mktemp --tmpdir -d $SCRIPTNAME-XXXXXX`" &&
  trap "rm -rf '$TEMPD'" 0 HUP INT QUIT TRAP USR1 PIPE TERM ||
    die "mktemp failed"

jj op log --no-graph -T 'id++"\n"' --op-diff > $TEMPD/opdiff 2>/dev/null || :

grep -P "^$BOOKMARK|^[a-f0-9]{24,}" $TEMPD/opdiff > $TEMPD/bm-or-ops

grep -P "^$BOOKMARK" -B1 $TEMPD/bm-or-ops > $TEMPD/bm+op

grep -P "^[a-f0-9]{24,}" $TEMPD/bm+op > $TEMPD/ops

for op in $(cat $TEMPD/ops) ; do
  jj op log -n1 --at-operation $op --op-diff --color=always
done
