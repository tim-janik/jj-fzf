#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
SCRIPTNAME="${0##*/}" && SCRIPTDIR="$(readlink -f "$0")" && SCRIPTDIR="${SCRIPTDIR%/*}"

source $SCRIPTDIR/utils.sh

# == TESTS ==
test-functions-fail-early()
(
  cd_new_repo
  # Check `jj-fzf describe` does not continue with $EDITOR
  # once an invalid change_id has been encountered.
  export JJ_CONFIG='' EDITOR='echo ERRORINERROR'
  OUT="$(set +x; jj-fzf describe 'zzzzaaaa' 2>&1)" && E=$? || E=$?
  assert_nonzero $E
  assert1error "$OUT"
  ! grep -Eq 'ERRORINERROR' <<<"$OUT" ||
    die "${FUNCNAME[0]}: detected nested invocation, output:"$'\n'"$(echo "$OUT" | sed 's/^/> /')"
)
TESTS+=( test-functions-fail-early )

test-edit-new()
(
  cd_new_repo
  mkcommits 'Ia' 'Ib' 'Ia ->Ic' 'Ib|Ic ->Id'
  assert_commit_count $((2 + 4))
  git tag IMMUTABLE `get_commit_id Id` && jj_status
  assert_commit_count $((2 + 5))
  mkcommits A B 'A ->C' 'B|C ->D'
  assert_commit_count $((2 + 5 + 4))
  jj-fzf edit 'C' >$DEVERR 2>&1
  assert_commit_count $((2 + 5 + 4))
  assert_@ `get_commit_id C` && assert_@- `get_commit_id A`
  jj-fzf edit 'Ic' >$DEVERR 2>&1
  assert_commit_count $((2 + 5 + 4 + 1))
  assert_@- `get_commit_id Ic`
  jj-fzf new '@' >$DEVERR 2>&1
  assert_commit_count $((2 + 5 + 4 + 1 + 1))
  assert_commits_eq @-- `get_commit_id Ic`
)
TESTS+=( test-edit-new )

test-undo-undo-redo()
(
  cd_new_repo
  mkcommits A B 'A ->C' 'B|C ->D' E
  assert_commit_count $((2 + 5))
  ( jj new -m U1 && jj new -m U2 && jj new -m U3 ) >$DEVERR 2>&1
  assert_commit_count $((2 + 5 + 3)) && assert_@ `get_commit_id U3` && assert_@- `get_commit_id U2`
  jj-fzf undo >$DEVERR 2>&1 && assert_commit_count $((2 + 5 + 2))
  jj-fzf undo >$DEVERR 2>&1 && assert_commit_count $((2 + 5 + 1))
  assert_@ `get_commit_id U1` && assert_@- `get_commit_id E`
  jj new >$DEVERR 2>&1 # resets undo pointer
  assert_commit_count $((2 + 5 + 1 + 1))
  jj-fzf undo >$DEVERR 2>&1
  assert_commit_count $((2 + 5 + 1)) && assert_@ `get_commit_id U1` && assert_@- `get_commit_id E`
  jj-fzf undo >$DEVERR 2>&1
  jj-fzf undo >$DEVERR 2>&1
  assert_commit_count $((2 + 5 + 3))
  assert_@ `get_commit_id U3` && assert_@- `get_commit_id U2`
  jj-fzf undo >$DEVERR 2>&1
  jj-fzf undo >$DEVERR 2>&1
  assert_commit_count $((2 + 5 + 1)) && assert_@ `get_commit_id U1` && assert_@- `get_commit_id E`
  jj-fzf undo-reset >$DEVERR 2>&1 # resets undo pointer
  jj-fzf undo >$DEVERR 2>&1
  jj-fzf undo >$DEVERR 2>&1
  assert_commit_count $((2 + 5 + 3)) && assert_@ `get_commit_id U3` && assert_@- `get_commit_id U2`
)
TESTS+=( test-undo-undo-redo )

# == RUN ==
temp_dir
for TEST in "${TESTS[@]}" ; do
  $TEST
  printf '  %-7s %s\n' OK "$TEST"
done
tear_down
