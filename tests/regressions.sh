#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
SCRIPTNAME="${0##*/}" && SCRIPTDIR="$(readlink -f "$0")" && SCRIPTDIR="${SCRIPTDIR%/*}"

[[ " $* " =~ -x ]] && set -x

source $SCRIPTDIR/utils.sh

# == lib_source ==
# Source a line-1 range of lib/$1 into the test shell to reach internal
# functions without triggering the script's top-level fzf UI. Runs from a
# sandbox so relative `source`s resolve, with positional args cleared for
# the scripts' option parsing loops.
lib_source()
{ # LIBFILE SEDEXPR
  local LIBFILE="$1" SEDEXPR="$2"
  # Must stay: only line-1 ranges, mid-file ranges would couple tests to script internals
  [[ "$SEDEXPR" == 1,* ]] ||
    die "lib_source: only ranges starting at line 1 are supported: $SEDEXPR"
  mkdir -p $TEMPD/libtest
  cp $SCRIPTDIR/../preflight.sh $TEMPD/preflight.sh
  cp $SCRIPTDIR/../lib/setup.sh $TEMPD/libtest/setup.sh
  sed -n "$SEDEXPR" "$SCRIPTDIR/../lib/$LIBFILE" > $TEMPD/libtest/part.sh
  local -a OLDARGS=("$@") # source without positional args, so option loops
  set --			# in the sourced script see no arguments
  source $TEMPD/libtest/part.sh
  set -- "${OLDARGS[@]}"
  rm -fr $TEMPD/libtest
}

# == TESTS ==
# Regression: `jj op show -p` only shows "interesting" revisions since jj-0.40.0,
# jj-fzf must pass `--show-changes-in=all()` to keep the oplog undo indicators complete.
test-oplog-info-all-changes()
(
  cd_new_repo
  # Restrict interesting revisions to @, so the describe op below is elided
  # unless `--show-changes-in=all()` is in effect.
  jj config set --repo revsets.op-diff-changes-in '@' >$DEVERR 2>&1
  mkcommits A B
  jj --no-pager describe -m 'A updated' A >$DEVERR 2>&1 # modify @-
  OPID=$(jj op log --no-graph -T 'id ++ " " ++ description.first_line()' |
	   grep -m1 ' describe ' | awk '{print $1}' | cut -c1-20)
  test -n "$OPID" || die "failed to locate describe operation"
  lib_source oplog.sh '1,/^export -f jjfzf_op_info$/p'
  OUT="$(JJFZF_COLOR= jjfzf_op_info "$OPID")"
  # The `Modified commit description:` hunk is only emitted by `jj op show -p`
  # when `--show-changes-in=all()` is passed; without it, @- changes are ignored.
  grep -q 'Modified commit description' <<<"$OUT" ||
    die "oplog info omitted changes of a non-@ commit"
)
TESTS+=( test-oplog-info-all-changes )

# == RUN ==
temp_dir
for TEST in "${TESTS[@]}" ; do
  $TEST
  printf '  %-7s %s\n' OK "$TEST"
done
