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

# Feature: Alt-Q runs `jj squash` to move the changes of all selected revisions
# into the revision under the cursor. Squashing the working copy must first
# create a new empty @+, so the working copy is never left on the squashed
# (abandoned) commit and children of the original @ are preserved.
test-squash()
(
  cd_new_repo
  mkcommits A B C
  jj --no-pager edit B >$DEVERR 2>&1	# working copy at B, C stays a child above @
  echo 'B-content' > f.txt && jj file track f.txt >$DEVERR 2>&1 && jj --no-pager describe -m B >$DEVERR 2>&1
  assert_commit_count $((2 + 3))
  EDITOR=true jj-fzf squash B >$DEVERR 2>&1 ||
    die "jj-fzf squash failed with exit status $?"
  assert_commit_count $((2 + 3))	# B abandoned, replaced by a new empty @+
  test "$(jj --no-pager file show -r A f.txt 2>&1)" == B-content ||
    die "jj-fzf squash did not move the working copy changes into A: $(jj --no-pager file show -r A f.txt 2>&1)"
  test "$(jj --ignore-working-copy log --no-graph -T 'if(description,"no","yes")' -r @)" == yes ||
    die "jj-fzf squash left the working copy on the squashed commit"
  assert_commits_eq @ C-	# C must stay on top of the new working copy
)
TESTS+=( test-squash )

# Feature: Alt-Q with several revisions selected squashes the entire selection
# into the revision under the cursor, leaving unrelated branches and the
# working copy untouched.
test-squash-branch()
(
  cd_new_repo
  mkcommits A B
  echo 'B-content' > f.txt && jj file track f.txt >$DEVERR 2>&1 && jj --no-pager describe -m B >$DEVERR 2>&1
  jj --no-pager new -r A -m C >$DEVERR 2>&1 && jj bookmark set -r @ C >$DEVERR 2>&1
  jj --no-pager new -m D >$DEVERR 2>&1 && echo 'D-content' > g.txt && jj file track g.txt >$DEVERR 2>&1 && jj --no-pager describe -m D >$DEVERR 2>&1 && jj bookmark set -r @ D >$DEVERR 2>&1
  jj --no-pager new -m E >$DEVERR 2>&1 && jj bookmark set -r @ E >$DEVERR 2>&1
  assert_commit_count $((2 + 5))
  EDITOR=true jj-fzf squash D B >$DEVERR 2>&1 ||
    die "jj-fzf squash failed with exit status $?"
  assert_commit_count $((2 + 4))	# B squashed into D
  test "$(jj --no-pager file show -r D f.txt 2>&1)" == B-content ||
    die "jj-fzf squash did not move B into D: $(jj --no-pager file show -r D f.txt 2>&1)"
  test "$(jj --no-pager file show -r D g.txt 2>&1)" == D-content ||
    die "jj-fzf squash altered the target content of D"
  assert_@ "$(get_change_id E)"	# working copy untouched
  assert_commits_eq A C-	# unrelated branch C untouched
)
TESTS+=( test-squash-branch )

# Feature: Alt-J injects a historic version of a revision as a new commit
# before @, without affecting the working copy. Historic (hidden) commits are
# identified by commit_id, so the injected commit restores the old description.
test-inject()
(
  cd_new_repo
  mkcommits A1
  echo 'A1-content' > f.txt && jj file track f.txt >$DEVERR 2>&1 && jj --no-pager describe -m A1 >$DEVERR 2>&1
  mkcommits B
  jj --no-pager describe -m A2 A1 >$DEVERR 2>&1	# rewrite A1, its old version stays hidden
  OLDID=$(jj --no-pager evolog --no-graph -r A1 -T 'commit.commit_id() ++ " " ++ commit.description().first_line() ++ "\n"' |
	  grep -m1 ' A1$' | awk '{print $1}')
  test -n "$OLDID" || die "failed to locate the historic A1 version in the evolog"
  jj-fzf inject "$OLDID" >$DEVERR 2>&1 ||
    die "jj-fzf inject failed with exit status $?"
  assert_commit_count $((2 + 3))	# historic version injected before @
  test "$(jj --ignore-working-copy log --no-graph -T description -r @-)" == A1 ||
    die "jj-fzf inject did not restore the historic description: $(jj --ignore-working-copy log --no-graph -T description -r @-)"
  test "$(jj --no-pager file show -r @- f.txt 2>&1)" == A1-content ||
    die "jj-fzf inject did not restore the historic content"
  assert_@ "$(get_change_id B)"	# working copy untouched
  test "$(jj --ignore-working-copy log --no-graph -T 'self.parents().map(|c| c.description().first_line())' -r @-)" == A2 ||
    die "jj-fzf inject inserted the historic commit at the wrong position"
)
TESTS+=( test-inject )

# Feature: Alt-R plans and runs `jj rebase`/`jj duplicate` commands through the
# rebase dialog; the enter handler must honor the dialog's target mode
# (Ctrl-A: --insert-after) and duplicate mode (Alt-D) for the given revisions.
test-rebase()
(
  cd_new_repo
  mkcommits A B		# branch A <- B
  jj --no-pager new -r A -m C >$DEVERR 2>&1 && jj bookmark set -r @ C >$DEVERR 2>&1
  jj --no-pager new -m D >$DEVERR 2>&1 && jj bookmark set -r @ D >$DEVERR 2>&1	# @ = D
  lib_source rebase.sh '1,/^export -f jjfzf_rebase_enter$/p'
  export JJFZF_CREVS="$(jjfzf_ccrevs "$(get_change_id B)")"
  DID=$(get_change_id D)
  # rebase B after D (Alt-R + Ctrl-A)
  sed 's/^TO=.*/TO=--insert-after/' -i $JJFZF_TEMPD/rebase.env
  jjfzf_rebase_enter "$DID" >$DEVERR 2>&1 ||
    die "jj-fzf rebase enter failed with exit status $?"
  assert_commits_eq D B-	# B rebased after D
  assert_@ "$DID"		# working copy untouched
  # duplicate B before D (Alt-D + Ctrl-B)
  sed 's/^TO=.*/TO=--insert-before/; s/^DP=.*/DP=1/' -i $JJFZF_TEMPD/rebase.env
  jjfzf_rebase_enter "$DID" >$DEVERR 2>&1 ||
    die "jj-fzf duplicate enter failed with exit status $?"
  assert_commit_count $((2 + 5))	# original B, duplicated B, C, D + root commits
  test "$(jj --ignore-working-copy log --no-graph -T 'description.first_line()' -r D-)" == B ||
    die "jj-fzf duplicate did not insert a B copy before D"
)
TESTS+=( test-rebase )

# == RUN ==
temp_dir
for TEST in "${TESTS[@]}" ; do
  $TEST
  printf '  %-7s %s\n' OK "$TEST"
done
tear_down
