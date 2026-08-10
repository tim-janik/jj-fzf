#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
SCRIPTNAME="${0##*/}" && SCRIPTDIR="$(readlink -f "$0")" && SCRIPTDIR="${SCRIPTDIR%/*}"

[[ " $* " =~ -x ]] && set -x

source $SCRIPTDIR/utils.sh

# == TESTS ==
# Feature: Ctrl-R runs `jj metaedit --update-change-id --force-rewrite`,
# which must rewrite the change id while preserving the commit content.
test-metaedit-change-id()
(
  cd_new_repo
  mkcommits A B
  CID=$(get_change_id A)
  COUNT=$(commit_count)
  jj-fzf meta A >$DEVERR 2>&1
  NCID=$(get_change_id A)
  test "$CID" != "$NCID" ||
    die "jj-fzf meta did not rewrite the change id of A"
  assert_commit_count "$COUNT"
  test "$(jj --ignore-working-copy log --no-graph -T description -r A)" == A ||
    die "jj-fzf meta altered the description of A"
)
TESTS+=( test-metaedit-change-id )

# == RUN ==
temp_dir
for TEST in "${TESTS[@]}" ; do
  $TEST
  printf '  %-7s %s\n' OK "$TEST"
done
tear_down
