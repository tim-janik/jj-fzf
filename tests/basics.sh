#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
SCRIPTNAME="${0##*/}" && SCRIPTDIR="$(readlink -f "$0")" && SCRIPTDIR="${SCRIPTDIR%/*}"

source $SCRIPTDIR/utils.sh

# == TESTS ==
test-edit-workspace()
(
  cd_new_repo
  mkcommits 'Ia' 'Ib' 'Ia ->Ic' 'Ib|Ic ->Id'
  assert_commit_count $((2 + 4))
  git tag IMMUTABLE `get_commit_id Id` && jj_status
  assert_commit_count $((2 + 5))
  mkcommits A B 'A ->C' 'B|C ->D'
  assert_commit_count $((2 + 5 + 4))
  jj-fzf edit-workspace 'C' >$DEVERR 2>&1
  assert_commit_count $((2 + 5 + 4))
  assert_@ `get_commit_id C` && assert_@- `get_commit_id A`
  jj-fzf edit-workspace 'Ic' >$DEVERR 2>&1
  assert_commit_count $((2 + 5 + 4 + 1))
  assert_@- `get_commit_id Ic`
)
TESTS+=( test-edit-workspace )

# == RUN ==
temp_dir
for TEST in "${TESTS[@]}" ; do
  $TEST
  printf '  %-7s %s\n' OK "$TEST"
done
tear_down
