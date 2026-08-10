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

# Feature: Alt-L runs `jj resolve` on the selected revision; a conflicted
# commit must be resolved interactively (non-interactive merge editor here),
# while unrelated revisions stay untouched.
test-resolve()
(
  cd_new_repo
  # Build a conflicted merge commit: base -> ours, base -> theirs, merge both
  echo 'base' > f.txt && jj file track f.txt >$DEVERR 2>&1
  jj --no-pager new -m base >$DEVERR 2>&1 && jj --no-pager describe -m base >$DEVERR 2>&1
  jj --no-pager new -m ours >$DEVERR 2>&1 && echo 'ours' > f.txt && jj --no-pager describe -m ours >$DEVERR 2>&1
  jj --no-pager new -r 'description(exact:"base\n")' -m theirs >$DEVERR 2>&1 && echo 'theirs' > f.txt && jj --no-pager describe -m theirs >$DEVERR 2>&1
  jj --no-pager new -m merge 'description(exact:"ours\n")' 'description(exact:"theirs\n")' >$DEVERR 2>&1
  jj --no-pager new -m top >$DEVERR 2>&1	# working copy above the conflict
  # jj status / jj resolve --list exit non-zero in conflict states, so capture
  # output and check content instead of pipeline exit statuses (pipefail).
  L="$(jj --no-pager resolve --list -r @- 2>&1 || true)"
  grep -q '2-sided conflict' <<<"$L" ||
    die "test setup failed: expected unresolved conflicts, got: $L"
  # Non-interactive merge editor: resolve by picking the right side
  cat > $TEMPD/merge-tool.sh <<\EOF
#!/usr/bin/env bash
cp "$2" "$3"
EOF
  chmod +x $TEMPD/merge-tool.sh
  jj --no-pager config set --repo ui.merge-editor \
      "$TEMPD/merge-tool.sh \$left \$right \$output" >$DEVERR 2>&1
  jj-fzf resolve @- >$DEVERR 2>&1 ||
    die "jj-fzf resolve failed with exit status $?"
  L="$(jj --no-pager resolve --list -r @- 2>&1 || true)"
  grep -q 'No conflicts found' <<<"$L" ||
    die "jj-fzf resolve did not resolve the selected revision: $L"
  S="$(jj status 2>&1 || true)"
  ! grep -q 'unresolved conflicts' <<<"$S" ||
    die "jj-fzf resolve left conflicts unresolved: $S"
  test "$(jj --no-pager file show -r @- f.txt 2>&1)" == theirs ||
    die "jj-fzf resolve produced unexpected content: $(jj --no-pager file show -r @- f.txt 2>&1)"
  test "$(jj --ignore-working-copy log --no-graph -T description -r @)" == top ||
    die "jj-fzf resolve altered an unrelated revision"
)
TESTS+=( test-resolve )

# == RUN ==
temp_dir
for TEST in "${TESTS[@]}" ; do
  $TEST
  printf '  %-7s %s\n' OK "$TEST"
done
tear_down
