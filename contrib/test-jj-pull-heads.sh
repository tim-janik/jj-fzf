#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
# Test script for jj-pull-heads.sh — creates two test jj repos in /tmp/ and
# exercises the various sync modes (fetch, hidden commit propagation,
# rewrites, working-copy protection, revsets, dry-run, ...).
#
# Each test scenario runs with all of its stdout+stderr captured into a
# single log file.  On success only a green PASS is printed; on failure the
# log is printed first, then a red FAIL.  With --strict the script aborts
# immediately after the first FAIL.
set -Eeuo pipefail #-x
SCRIPTNAME="${BASH_SOURCE[0]##*/}"
die() { echo "$SCRIPTNAME: **ERROR**: ${*:-aborting}" >&2; exit 127; }

test "${1-}" = -x && { shift; set -x; }

# == Help ==
show_help()
{
  cat <<-'EOF'
	Usage: test-jj-pull-heads.sh [OPTIONS...]

	Tests contrib/jj-pull-heads.sh by creating pairs of jj repos in /tmp/
	and running various sync scenarios against them.  Each scenario captures
	stdout+stderr into a single log file: on success only a green PASS is
	printed, on failure the log is printed first, then a red FAIL.  On
	success the sandbox is removed; on failure it is kept for inspection.

	The pull script under test is located next to this script; override
	with the S environment variable.

	Options:
	  -h, --help     Display this help and exit
	  -k, --keep     Keep the /tmp/ sandbox even on success
	  -s, --strict   Abort immediately after the first FAIL
	EOF
}

KEEP_SANDBOX=false
STRICT=false
while test $# -ne 0 ; do
  case "$1" in \
    -h|--help)		show_help; exit 0 ;;
    -k|--keep)		KEEP_SANDBOX=true ;;
    -s|--strict)	STRICT=true ;;
    -*)			die "unknown option: $1" ;;
    *)			die "unexpected argument: $1" ;;
  esac
  shift
done

# == Resolve script under test ==
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="${S:-$SCRIPT_DIR/jj-pull-heads.sh}"
test -x "$S" || die "pull script not found or not executable: $S"

# == Sandbox ==
BASE="$(mktemp -d /tmp/jj-pull-heads-test.XXXXXX)"
PASS=0; FAIL=0
printf '[user]\nname = "jj-pull-test"\nemail = "test@example.invalid"\n' > "$BASE/config.toml"
export JJ_CONFIG="$BASE/config.toml"
LOG="$BASE/run.log"		# single file holding stdout+stderr of the running test
ASSERTFAIL="$BASE/.assertfail"	# marker listing failed assertions of the running test
ABORTED=""
on_err() # records unexpected failures (set -Ee makes this fire in functions/subshells too)
{
  local rc=$?
  test "$rc" -eq 0 && return 0
  ABORTED="command '$BASH_COMMAND' failed (exit $rc) at line ${BASH_LINENO[0]}"
}
cleanup()
{
  local rc=$?
  echo
  echo "== RESULT: $PASS passed, $FAIL failed"
  if test -n "$ABORTED" ; then
    echo "== WARNING: test aborted before completion (exit $rc): $ABORTED" >&2
    echo "== sandbox kept: $BASE" >&2
    exit 1
  fi
  if test $FAIL -eq 0 && ! $KEEP_SANDBOX ; then
    rm -rf "$BASE"
  else
    echo "== sandbox kept: $BASE"
    test $FAIL -eq 0
  fi
}
trap on_err ERR
trap cleanup EXIT
trap 'ABORTED="interrupted by SIGINT"; exit 130' INT
trap 'ABORTED="terminated by SIGTERM"; exit 143' TERM

# == Color output (only when stdout is a TTY and NO_COLOR is unset) ==
GREEN=$'\033[32m'; RED=$'\033[31m'; RESET=$'\033[0m'
if test ! -t 1 || test -n "${NO_COLOR-}" ; then
  GREEN=; RED=; RESET=
fi

# == Test harness ==
assert() # desc cmd...   -- runs a check, silently records a failure on miss
{
  local desc="$1"; shift
  if "$@" ; then return 0; fi
  echo "  ** FAILED ASSERT: $desc" >> "$ASSERTFAIL"
  return 0
}
run_test() # desc <fn>   -- runs the test fn, capturing stdout+stderr into $LOG
{
  local desc="$1"; shift
  local rc=0
  : > "$LOG"
  rm -f "$ASSERTFAIL"
  ( set -Ee; "$@" ) >"$LOG" 2>&1 || rc=$?
  if test $rc -eq 0 && ! test -e "$ASSERTFAIL" ; then
    PASS=$((PASS+1)); echo "  ${GREEN}PASS${RESET}: $desc"
  else
    echo "===== output of failed test: $desc ====="
    cat "$LOG"
    if test -e "$ASSERTFAIL" ; then
      echo "----- failed assertions:"
      cat "$ASSERTFAIL"
    fi
    echo "========================================="
    FAIL=$((FAIL+1)); echo "  ${RED}FAIL${RESET}: $desc"
    if $STRICT ; then
      echo "  --strict: aborting after first failure"
      exit 1
    fi
  fi
}

# == Helpers ==
newrepo() # dir
{
  jj git init --colocate "$1" >/dev/null 2>&1
}
newrepo_nc() # dir -- truly non-colocated (git store hidden under .jj/)
{
  jj git init --no-colocate "$1" >/dev/null 2>&1
}
no_pull_state() # repo -- succeeds iff no __jj_pull bookmarks and no __jj_pull git refs
{
  jj -R "$1" --no-pager --ignore-working-copy bookmark list 2>/dev/null | grep -q __jj_pull && return 1
  git --git-dir="$(jj -R "$1" git root)" for-each-ref refs/heads 2>/dev/null | grep -q __jj_pull && return 1
  return 0
}
mkcommit() # repo desc [parent]  -> commit id (detached head, @ moved to root child)
{
  local repo="$1" desc="$2" parent="${3:-root()}" cid
  ( cd "$repo" \
    && jj new "$parent" >/dev/null 2>&1 \
    && echo "$desc" > "$desc.file" \
    && jj metaedit -m "$desc" >/dev/null 2>&1 \
    && cid=$(jj log -r '@' --no-graph -T 'commit_id ++ "\n"' 2>/dev/null) \
    && jj new 'root()' -m "wc-$(basename "$repo")" >/dev/null 2>&1 \
    && echo "$cid" )
}
heads_of() # repo
{
  jj -R "$1" --no-pager --ignore-working-copy log -r 'heads(::)&mutable()' --no-graph -T 'commit_id ++ "\n"' 2>/dev/null
}
all_visible() # repo
{
  jj -R "$1" --no-pager --ignore-working-copy log -r 'all()' --no-graph -T 'commit_id ++ "\n"' 2>/dev/null
}
is_visible() { local out; out=$(all_visible "$1"); echo "$out" | grep -qx "$2"; } # repo id
is_head()    { local out; out=$(heads_of "$1");    echo "$out" | grep -qx "$2"; } # repo id
is_hidden()  { ! is_visible "$1" "$2"; }                                        # repo id
sync() { "$S" "${1:-.}"; }                                                     # from repo dir

# ================= T1: basic fetch of detached heads =================
t1()
(
  T="$BASE/t1"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A); B=$(mkcommit "$T/remote" B)
  ( cd "$T/local" && sync ../remote )
  assert "A fetched & visible"        is_visible "$T/local" "$A"
  assert "B fetched & visible"        is_visible "$T/local" "$B"
  assert "A is a detached head"       is_head    "$T/local" "$A"
  assert "B is a detached head"       is_head    "$T/local" "$B"
  assert "no pull bookmarks left"     test -z "$(cd "$T/local" && jj bookmark list 2>/dev/null | grep __jj_pull || true)"
)

# ================= T2: hidden commit propagation =================
t2()
(
  T="$BASE/t2"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A); B=$(mkcommit "$T/remote" B)
  ( cd "$T/local" && sync ../remote )
  ( cd "$T/remote" && jj abandon "$A" >/dev/null 2>&1 )
  C=$(mkcommit "$T/remote" C)
  ( cd "$T/local" && sync ../remote )
  assert "A abandoned locally"        is_hidden  "$T/local" "$A"
  assert "C imported as head"         is_head    "$T/local" "$C"
  assert "B still head"               is_head    "$T/local" "$B"
)

# ================= T3: local-only head survives + idempotency =================
t3()
(
  T="$BASE/t3"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A)
  ( cd "$T/local" && sync ../remote )
  L=$(mkcommit "$T/local" L)
  HEADS_BEFORE="$(heads_of "$T/local" | sort)"
  ( cd "$T/local" && sync ../remote )
  assert "L survives"                 is_visible "$T/local" "$L"
  assert "L still head"               is_head    "$T/local" "$L"
  ( cd "$T/local" && sync ../remote )   # idempotency
  assert "idempotent (heads unchanged)" test "$HEADS_BEFORE" = "$(heads_of "$T/local" | sort)"
  assert "L visible after 2nd run"    is_visible "$T/local" "$L"
  assert "A visible after 2nd run"    is_visible "$T/local" "$A"
  assert "A still a head after 2nd run" is_head   "$T/local" "$A"
)

# ================= T4: working copy is protected =================
t4()
(
  T="$BASE/t4"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A); B=$(mkcommit "$T/remote" B)
  ( cd "$T/local" && sync ../remote )
  ( cd "$T/local" && jj edit "$B" >/dev/null 2>&1 )   # @ = B
  ( cd "$T/remote" && jj abandon "$B" >/dev/null 2>&1 )
  D=$(mkcommit "$T/remote" D)
  ( cd "$T/local" && sync ../remote )
  assert "B (checked out) stays visible" is_visible "$T/local" "$B"
  assert "working file intact"            test -f "$T/local/B.file"
  assert "D imported"                     is_visible "$T/local" "$D"
  assert "A still visible"                is_visible "$T/local" "$A"
)

# ================= T5: diverged change (remote rewrote head) =================
t5()
(
  T="$BASE/t5"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A); B=$(mkcommit "$T/remote" B)
  ( cd "$T/local" && sync ../remote )
  # rewrite B at remote (same change id, new commit id)
  ( cd "$T/remote" && jj edit "$B" >/dev/null 2>&1 && echo B2 > B2.file && jj metaedit -m "B updated" >/dev/null 2>&1 )
  B2=$(cd "$T/remote" && jj log -r '@' --no-graph -T 'commit_id ++ "\n"')
  ( cd "$T/remote" && jj new 'root()' -m "wc-remote" >/dev/null 2>&1 )
  ( cd "$T/local" && sync ../remote )
  assert "old B version abandoned"       is_hidden  "$T/local" "$B"
  assert "new B version imported"        is_visible "$T/local" "$B2"
  assert "new B is a head"               is_head    "$T/local" "$B2"
)

# ================= T6: remote fetched our head, then abandoned it =================
t6()
(
  T="$BASE/t6"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  X=$(mkcommit "$T/local" X)
  ( cd "$T/remote" && sync ../local )          # remote fetches X from us
  assert "X now a head in remote"              is_head "$T/remote" "$X"
  ( cd "$T/remote" && jj abandon "$X" >/dev/null 2>&1 )
  ( cd "$T/remote" && jj new 'root()' -m "wc-remote" >/dev/null 2>&1 )
  ( cd "$T/local" && sync ../remote )          # sync back: abandonment must propagate
  assert "X abandoned locally"                 is_hidden "$T/local" "$X"
)

# ================= T7: dry-run changes nothing =================
t7()
(
  T="$BASE/t7"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A)
  OUT="$(cd "$T/local" && "$S" -n ../remote 2>&1)"
  printf '%s\n' "$OUT" >&2     # dump into the log for failure inspection
  HEADS_BEFORE="$(heads_of "$T/local" | sort)"
  assert "dry-run lists fetch"            sh -c 'echo "$1" | grep -q "Will fetch"' sh "$OUT"
  assert "dry-run details import"         sh -c 'echo "$1" | grep -q "as reachable heads"' sh "$OUT"
  assert "dry-run makes no changes"       test "$HEADS_BEFORE" = "$(heads_of "$T/local" | sort)"
  assert "A not visible after dry-run"    is_hidden "$T/local" "$A"
)

# ================= T8: revset none() abandons all known heads =================
t8()
(
  T="$BASE/t8"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A)
  ( cd "$T/local" && sync ../remote )
  L=$(mkcommit "$T/local" L)
  ( cd "$T/local" && "$S" -r 'none()' ../remote >/dev/null 2>&1 )
  assert "A abandoned"                    is_hidden "$T/local" "$A"
  assert "local-only L survives"          is_visible "$T/local" "$L"
)

# ================= T9: synced head with local child is not touched =================
t9()
(
  T="$BASE/t9"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A)
  ( cd "$T/local" && sync ../remote )
  CA=$(mkcommit "$T/local" childA "$A")     # local child on synced head A
  ( cd "$T/remote" && jj abandon "$A" >/dev/null 2>&1 )
  ( cd "$T/local" && sync ../remote )
  assert "A not abandoned (ancestor of child)" is_visible "$T/local" "$A"
  assert "child intact"                        is_visible "$T/local" "$CA"
  assert "child is head"                       is_head "$T/local" "$CA"
)

# ================= T10: head now ancestor of a remote head is kept =================
t10()
(
  T="$BASE/t10"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A); B=$(mkcommit "$T/remote" B)
  ( cd "$T/local" && sync ../remote )
  A2=$(mkcommit "$T/remote" A2 "$A")        # remote grows A2 on top of A
  ( cd "$T/local" && sync ../remote )
  assert "A kept (still remote ancestry)" is_visible "$T/local" "$A"
  assert "A2 imported"                    is_visible "$T/local" "$A2"
  assert "A2 is a head"                   is_head "$T/local" "$A2"
)

# ================= T11: bookmarked head survives =================
t11()
(
  T="$BASE/t11"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A)
  ( cd "$T/local" && sync ../remote )
  ( cd "$T/local" && jj bookmark create ba -r "$A" >/dev/null 2>&1 )
  ( cd "$T/remote" && jj abandon "$A" >/dev/null 2>&1 )
  ( cd "$T/local" && sync ../remote )
  assert "bookmarked A survives"          is_visible "$T/local" "$A"
)

# ================= T12: raw-fetched (never imported) head counts as known =================
t12()
(
  T="$BASE/t12"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  X=$(mkcommit "$T/local" X)
  # remote raw-fetches X's object into its odb without ever importing it
  REMOTE_GIT=$(cd "$T/remote" && jj git root); LOCAL_GIT=$(cd "$T/local" && jj git root)
  git --git-dir="$REMOTE_GIT" fetch -q --no-tags "$LOCAL_GIT" "$X"
  ( cd "$T/local" && sync ../remote )
  assert "X abandoned locally"            is_hidden "$T/local" "$X"
)

# ================= T13: custom -r revset restricts the remote head set =================
t13()
(
  T="$BASE/t13"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A); B=$(mkcommit "$T/remote" B)
  ( cd "$T/local" && sync ../remote )
  ( cd "$T/local" && "$S" -r 'description(substring:"B")' ../remote >/dev/null 2>&1 )
  assert "A discarded (outside restricted revset)" is_hidden "$T/local" "$A"
  assert "B kept"                                  is_visible "$T/local" "$B"
)

# ================= T14: bookmark naming regression =================
t14()
(
  T="$BASE/t14"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A)
  ( cd "$T/local" && sync ../remote )
  ( cd "$T/remote" && jj abandon "$A" >/dev/null 2>&1 )
  ( cd "$T/remote" && jj new 'root()' -m "wc-remote" >/dev/null 2>&1 )
  OUT="$(cd "$T/local" && "$S" -v ../remote 2>&1)"
  printf '%s\n' "$OUT" >&2     # dump into the log for failure inspection
  assert "verbose mentions carried merge"    sh -c 'echo "$1" | grep -q "carried-heads merge"' sh "$OUT"
  assert "verbose mentions discarded merge"   sh -c 'echo "$1" | grep -q "hidden-heads merge"' sh "$OUT"
  assert "no pull bookmarks left" test -z "$(cd "$T/local" && jj bookmark list 2>/dev/null | grep __jj_pull || true)"
)

# ================= T15: non-colocated repos =================
# Uses --no-colocate explicitly: `jj git init` defaults to colocated since
# jj 0.44, so the bare form would silently test the colocated path (see T21
# for the thorough non-colocated coverage including leftover-state checks).
t15()
(
  T="$BASE/t15"; mkdir -p "$T"
  jj git init --no-colocate "$T/remote" >/dev/null 2>&1; jj git init --no-colocate "$T/local" >/dev/null 2>&1
  A=$(mkcommit "$T/remote" A)
  ( cd "$T/local" && sync ../remote )
  ( cd "$T/remote" && jj abandon "$A" >/dev/null 2>&1 )
  B=$(mkcommit "$T/remote" B)
  ( cd "$T/local" && sync ../remote )
  assert "A abandoned"                    is_hidden "$T/local" "$A"
  assert "B imported"                     is_head "$T/local" "$B"
)

# ================= T16: misc CLI checks =================
t16()
(
  T="$BASE/t16"; mkdir -p "$T"; newrepo "$T/repo1"; newrepo "$T/repo2"
  assert "help exits 0"   "$S" --help
  assert "missing arg dies"      sh -c "'$S' >/dev/null 2>&1; test \$? -ne 0"
  assert "self-sync dies"        sh -c "cd '$T/repo1' && '$S' '$T/repo1' >/dev/null 2>&1; test \$? -ne 0"
  assert "ssh remote w/o path dies" sh -c "'$S' 'somehost:' >/dev/null 2>&1; test \$? -ne 0"
  assert "bad revset dies"       sh -c "cd '$T/repo1' && '$S' -r 'bogus_revset_fn()' '$T/repo2' >/dev/null 2>&1; test \$? -ne 0"
  assert "-r without value dies cleanly"    sh -c "'$S' -r 2>&1 | grep -q 'requires an argument'"
  assert "--revset without value dies cleanly" sh -c "'$S' --revset 2>&1 | grep -q 'requires an argument'"
)

# ================= T17: ssh remotes (host:path) via fake ssh =================
t17()
(
  T="$BASE/t17"; mkdir -p "$T"
  cat > "$T/ssh" <<'EOSSH'
#!/bin/sh
# Fake ssh: run the remote command locally, through the same command-line
# interface ssh would use.  Handles both the ssh command lines issued by
# jj-pull-heads.sh and git's ssh transport (git-upload-pack).
while test $# -gt 0 ; do
  case "$1" in
    -o|-p|-i) shift 2 ;;
    -*) shift ;;
    *) break ;;
  esac
done
host="$1"; shift
eval "$1"
EOSSH
  chmod +x "$T/ssh"
  export PATH="$T:$PATH"
  newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A); B=$(mkcommit "$T/remote" B)
  ( cd "$T/local" && "$S" "localhost:$T/remote" >/dev/null 2>&1 )
  assert "A fetched & visible"        is_visible "$T/local" "$A"
  assert "B fetched & visible"        is_visible "$T/local" "$B"
  ( cd "$T/remote" && jj abandon "$A" >/dev/null 2>&1 )
  C=$(mkcommit "$T/remote" C)
  ( cd "$T/local" && "$S" "localhost:$T/remote" >/dev/null 2>&1 )
  assert "A abandoned locally"        is_hidden  "$T/local" "$A"
  assert "C imported as head"         is_head    "$T/local" "$C"
  # round-trip: remote imports our head X (imported commits get no
  # refs/jj/keep/ refs of their own), then a THIRD repo that never saw X
  # syncs from the remote and needs X's object.  The raw-object fetch is
  # read-only; git 2.47's ssh+v2 upload-pack serves sha wants even without
  # uploadpack.allowAnySHA1InWant, so no remote config is needed here (if a
  # git version rejects the sha want, the script dies with a hint instead).
  X=$(mkcommit "$T/local" X)
  ( cd "$T/remote" && "$S" "localhost:$T/local" >/dev/null 2>&1 )
  assert "X now a head in remote"     is_head "$T/remote" "$X"
  newrepo "$T/local2"
  ( cd "$T/local2" && "$S" "localhost:$T/remote" >/dev/null 2>&1 )
  assert "X imported via raw object"  is_visible "$T/local2" "$X"
  assert "X is a head in local2"      is_head "$T/local2" "$X"
  # abandoned remotely -> discarded locally
  ( cd "$T/remote" && jj abandon "$X" >/dev/null 2>&1 )
  ( cd "$T/remote" && jj new 'root()' -m wc-remote >/dev/null 2>&1 )
  ( cd "$T/local" && "$S" "localhost:$T/remote" >/dev/null 2>&1 )
  assert "X abandoned locally"        is_hidden "$T/local" "$X"
)

# ================= T18: overlapping heads (already visible locally) re-sync idempotently =================
t18()
(
  T="$BASE/t18"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A); B=$(mkcommit "$T/remote" B)
  ( cd "$T/local" && sync ../remote )
  # second run: all remote heads already visible locally -> re-pinned/idempotent, nothing changes
  HEADS_BEFORE="$(heads_of "$T/local" | sort)"
  OUT="$(cd "$T/local" && sync ../remote 2>&1)"
  printf '%s\n' "$OUT" >&2     # dump into the log for failure inspection
  assert "re-sync abandons nothing"      test "$HEADS_BEFORE" = "$(heads_of "$T/local" | sort)"
  assert "A still visible"               is_visible "$T/local" "$A"
  assert "B still visible"               is_visible "$T/local" "$B"
  assert "no pull bookmarks left"        test -z "$(cd "$T/local" && jj bookmark list 2>/dev/null | grep __jj_pull || true)"
  # verbose re-sync reports the overlapping-heads count (every remote head
  # here is already visible locally, so the overlap set is non-empty)
  VOUT="$(cd "$T/local" && "$S" -v ../remote 2>&1)"
  printf '%s\n' "$VOUT" >&2     # dump into the log for failure inspection
  assert "verbose counts overlapping heads"  sh -c 'echo "$1" | grep -q "overlapping head(s)"' sh "$VOUT"
  # new remote head: dry-run reports the planned imports/abandons but changes nothing
  C=$(mkcommit "$T/remote" C)
  HEADS_BEFORE="$(heads_of "$T/local" | sort)"
  OUT="$(cd "$T/local" && "$S" -n ../remote 2>&1)"
  printf '%s\n' "$OUT" >&2     # dump into the log for failure inspection
  assert "dry-run plans remote commits"        sh -c 'echo "$1" | grep -q "Will fetch .* remote commit(s)"' sh "$OUT"
  assert "dry-run plans abandonment pass"      sh -c 'echo "$1" | grep -q "Will abandon up to .* local head(s)"' sh "$OUT"
  assert "dry-run makes no changes"            test "$HEADS_BEFORE" = "$(heads_of "$T/local" | sort)"
  ( cd "$T/local" && sync ../remote )
  assert "C imported as head"               is_head   "$T/local" "$C"
  assert "A still a head"                   is_head   "$T/local" "$A"
  assert "B still a head"                   is_head   "$T/local" "$B"
)

# ================= T19: overlap head kept when it is only an ancestor locally =================
t19()
(
  T="$BASE/t19"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A); B=$(mkcommit "$T/remote" B); A2=$(mkcommit "$T/remote" A2 "$A")
  ( cd "$T/local" && sync ../remote )   # A, B, A2 imported; A is ancestor of A2 (not a head) now
  HEADS_BEFORE="$(heads_of "$T/local" | sort)"
  ( cd "$T/local" && sync ../remote )   # all remote heads overlap
  assert "re-sync abandons nothing"      test "$HEADS_BEFORE" = "$(heads_of "$T/local" | sort)"
  assert "A still visible"               is_visible "$T/local" "$A"
  assert "A2 still a head"               is_head   "$T/local" "$A2"
  assert "B still a head"                is_head   "$T/local" "$B"
)

# ================= T20: --keep imports heads but skips abandonment =================
t20()
(
  T="$BASE/t20"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A); B=$(mkcommit "$T/remote" B)
  ( cd "$T/local" && sync ../remote )             # A, B imported
  ( cd "$T/remote" && jj abandon "$A" >/dev/null 2>&1 )
  C=$(mkcommit "$T/remote" C)
  OUT="$(cd "$T/local" && "$S" -k -n ../remote 2>&1)"
  printf '%s\n' "$OUT" >&2                        # dump into the log for failure inspection
  assert "dry-run --keep notes no abandonment"    sh -c 'echo "$1" | grep -q "no local heads will be abandoned"' sh "$OUT"
  assert "dry-run --keep omits abandon plan"      sh -c '! echo "$1" | grep -q "will abandon up to"' sh "$OUT"
  assert "dry-run --keep still plans fetch"       sh -c 'echo "$1" | grep -q "Will fetch"' sh "$OUT"
  assert "dry-run --keep makes no changes"        is_hidden "$T/local" "$C"
  OUT="$(cd "$T/local" && "$S" --keep ../remote 2>&1)"
  printf '%s\n' "$OUT" >&2                        # dump into the log for failure inspection
  assert "C imported with --keep"           is_head    "$T/local" "$C"
  assert "A kept with --keep"               is_visible "$T/local" "$A"
  assert "B kept"                           is_visible "$T/local" "$B"
  assert "no pull bookmarks left"           test -z "$(cd "$T/local" && jj bookmark list 2>/dev/null | grep __jj_pull || true)"
  # --keep only applies to the run it is given: the next regular sync abandons A
  ( cd "$T/local" && sync ../remote )
  assert "A abandoned by next plain sync"    is_hidden "$T/local" "$A"
  assert "C still a head"                    is_head   "$T/local" "$C"
)

# ================= T21: truly non-colocated repos (--no-colocate) =================
# jj git init defaults to colocated since jj 0.44, so T15 does not exercise
# the non-colocated path.  This does, and checks in particular that no
# __jj_pull state (bookmarks OR git refs) is left behind: in non-colocated
# repos `jj abandon` does not auto-export, so the carried-heads git ref would
# otherwise linger pointing at the hidden merge commit.
t21()
(
  T="$BASE/t21"; mkdir -p "$T"; newrepo_nc "$T/remote"; newrepo_nc "$T/local"
  A=$(mkcommit "$T/remote" A); B=$(mkcommit "$T/remote" B)
  ( cd "$T/local" && sync ../remote )
  assert "A fetched & visible (nc)"        is_visible "$T/local" "$A"
  assert "B fetched & visible (nc)"        is_visible "$T/local" "$B"
  assert "A is a detached head (nc)"       is_head    "$T/local" "$A"
  assert "B is a detached head (nc)"       is_head    "$T/local" "$B"
  assert "no pull state left (nc)"         no_pull_state "$T/local"
  # local-only head survives, abandonment propagates, nothing lingers
  L=$(mkcommit "$T/local" L)
  ( cd "$T/remote" && jj abandon "$A" >/dev/null 2>&1 )
  C=$(mkcommit "$T/remote" C)
  ( cd "$T/local" && sync ../remote )
  assert "A abandoned locally (nc)"        is_hidden  "$T/local" "$A"
  assert "C imported as head (nc)"         is_head    "$T/local" "$C"
  assert "B still head (nc)"               is_head    "$T/local" "$B"
  assert "local-only L survives (nc)"      is_head    "$T/local" "$L"
  assert "no pull state after 2nd (nc)"    no_pull_state "$T/local"
  ( cd "$T/local" && sync ../remote )      # idempotent re-run
  assert "no pull state after 3rd (nc)"    no_pull_state "$T/local"
  # --keep in non-colocated must also clean up the carried-heads ref
  D=$(mkcommit "$T/remote" D)
  ( cd "$T/local" && "$S" --keep ../remote >/dev/null 2>&1 )
  assert "D imported with --keep (nc)"     is_head    "$T/local" "$D"
  assert "no pull state after --keep (nc)" no_pull_state "$T/local"
)

# ================= T22: "nothing to sync" early exits =================
t22()
(
  T="$BASE/t22"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  # fresh local has no non-@ heads; -r none() -> remote contributes no heads
  HEADS_BEFORE="$(heads_of "$T/local" | sort)"
  OUT="$(cd "$T/local" && "$S" -r 'none()' ../remote 2>&1)"
  printf '%s\n' "$OUT" >&2
  assert "no heads either side message"   sh -c 'echo "$1" | grep -q "nothing to sync (no heads on either side)"' sh "$OUT"
  assert "nothing changed (no heads)"      test "$HEADS_BEFORE" = "$(heads_of "$T/local" | sort)"
  # local-only heads + -r none() -> no remote heads, no known local heads
  L=$(mkcommit "$T/local" L)
  HEADS_BEFORE="$(heads_of "$T/local" | sort)"
  OUT="$(cd "$T/local" && "$S" -r 'none()' ../remote 2>&1)"
  printf '%s\n' "$OUT" >&2
  assert "no remote/known message"         sh -c 'echo "$1" | grep -q "nothing to sync (no remote heads, no known local heads)"' sh "$OUT"
  assert "nothing changed (no remote)"     test "$HEADS_BEFORE" = "$(heads_of "$T/local" | sort)"
  assert "local-only L untouched"          is_head "$T/local" "$L"
)

# ================= T23: multiple known heads abandoned in one sync =================
# Exercises a multi-parent hidden-heads merge and confirms all wrapped
# heads are abandoned together when the remote discards them.
t23()
(
  T="$BASE/t23"; mkdir -p "$T"; newrepo "$T/remote"; newrepo "$T/local"
  A=$(mkcommit "$T/remote" A); B=$(mkcommit "$T/remote" B)
  ( cd "$T/local" && sync ../remote )
  ( cd "$T/remote" && jj abandon "$A" "$B" >/dev/null 2>&1 )
  ( cd "$T/remote" && jj new 'root()' -m wc-remote >/dev/null 2>&1 )
  ( cd "$T/local" && sync ../remote )
  assert "A abandoned"                      is_hidden "$T/local" "$A"
  assert "B abandoned"                      is_hidden "$T/local" "$B"
  assert "no pull bookmarks left"           test -z "$(cd "$T/local" && jj bookmark list 2>/dev/null | grep __jj_pull || true)"
  assert "no pull git refs left"            no_pull_state "$T/local"
)

# == Run all tests ==
echo "== Testing: $S"
echo "== jj: $(jj --version)"

run_test "T1: basic fetch of detached heads"                  t1
run_test "T2: hidden commit propagation"                      t2
run_test "T3: local-only head survives; idempotent re-run"    t3
run_test "T4: working copy is protected"                      t4
run_test "T5: diverged change (remote rewrote head)"          t5
run_test "T6: remote fetched our head, then abandoned it"     t6
run_test "T7: dry-run changes nothing"                        t7
run_test "T8: revset none() abandons all known heads"         t8
run_test "T9: synced head with local child is not touched"    t9
run_test "T10: head now ancestor of a remote head is kept"    t10
run_test "T11: bookmarked head survives"                      t11
run_test "T12: raw-fetched (never imported) head counts as known" t12
run_test "T13: custom -r revset restricts the remote head set"    t13
run_test "T14: bookmark naming regression"                    t14
run_test "T15: non-colocated repos"                           t15
run_test "T16: misc CLI checks"                               t16
run_test "T17: ssh remotes (host:path) via fake ssh"          t17
run_test "T18: overlapping heads (already visible locally) re-sync idempotently" t18
run_test "T19: overlap head kept when it is only an ancestor locally"   t19
run_test "T20: --keep imports heads but skips abandonment"                t20
run_test "T21: truly non-colocated repos (--no-colocate)"               t21
run_test "T22: nothing-to-sync early exits"                             t22
run_test "T23: multiple known heads abandoned in one sync"              t23
