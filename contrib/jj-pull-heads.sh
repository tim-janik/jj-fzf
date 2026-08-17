#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x

SCRIPTNAME="${BASH_SOURCE[0]##*/}"
die() { echo "$SCRIPTNAME: **ERROR**: ${*:-aborting}" >&2; exit 127; }
vecho() { if $VERBOSE ; then echo "$*" >&2; fi; }

# == Temp dir ==
# Helper files for this run (removed on exit)
TEMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/jj-pull-heads.XXXXXX")" ||
  die "mktemp failed"
trap 'rm -rf "$TEMPDIR"' EXIT

# Handle -x before option parsing so traces cover the parsing loop too.
test "${1-}" = -x && { shift; set -x; }

# == Help ==
show_help()
{
  sed "s/__PROG__/$SCRIPTNAME/g" <<-'EOF'
	Usage: __PROG__ [OPTIONS...] <remote-repo>

	Synchronize mutable heads from <remote-repo> (a jj repository) into the
	current jj repo:

	  - heads of the remote repo are imported into the current repo as
	    new head commits (orphaned children of __jj_pull_carried_heads_)
	  - local heads known to the remote repo by commit id, are abandoned
	    if they are unreachable (hidden) in the remote repo, mirroring
	    rewrites or abandonments made in the remote

	Mechanism (per sync):
	  1. Local heads are collected (REVSET minus the working copy commit).
	  2. Local heads whose commit objects exist in the remote repo's git
	     object database are wrapped into a temporary merge commit with
	     bookmark `__jj_pull_hidden_heads_`.
	  3. The remote's mutable heads (REVSET) are fetched via raw git and
	     wrapped into a temporary merge commit with bookmark
	     `__jj_pull_carried_heads_`.
	  4. Both bookmarks are imported into jj; then `__jj_pull_hidden_heads_`
	     is deleted in the git backend and the deletion is imported. jj's
	     git.abandon-unreachable-commits cleanup thereby abandons the local
	     heads that are no longer reachable from the remote heads ancestries.
	     `__jj_pull_carried_heads_` protects the freshly fetched remote heads
	     in the process.
	  5. `jj abandon __jj_pull_carried_heads_` (with cleanup disabled per
	     git.abandon-unreachable-commits=false) dissolves the merge, leaving
	     the fetched remote heads as detached heads (orphaned children).

	The remote repo is strictly read-only. <remote-repo> may also be given
	as [user@]host:path to access a repository on another machine via ssh
	Fetching relies on refs/jj/keep/* refs in the remote git backend; heads
	without one (e.g. commits that were imported into the remote from
	elsewhere) additionally need uploadpack.allowAnySHA1InWant on the
	remote to be fetched by raw commit id.
	The remote jj must support the same revsets and templates as the
	local jj. Local heads the remote repo has never seen are left
	untouched, as is the working copy commit (@).

	Options:
	  -h, --help        Display this help and exit
	  -r, --revset REV  Revset expression for remote heads to sync
	                    (default: 'heads(::)&mutable()')
	                    Local heads are always collected as
	                    'heads(::)&mutable()&~@' (all mutable heads
	                    except the working copy).
	  -n, --dry-run     Show what will be synced without executing
	  -k, --keep        Import remote heads but do not abandon stale
	                    local heads the remote no longer has
	  -v, --verbose     Print progress messages

	Examples:
	  __PROG__ /path/to/other/jj/repo
	  __PROG__ otherhost:~/projects/foo
	  __PROG__ -k ../debugging-repository
	EOF
}

# == Parse Options ==
REMOTE_REPO=
REVSET='heads(::)&mutable()'
DRYRUN=false
VERBOSE=false
KEEP=false
while test $# -ne 0 ; do
  case "$1" in
    -h|--help)		show_help; exit 0 ;;
    -r|--revset)	test $# -ge 2 || die "-r/--revset requires an argument"; REVSET="$2"; shift ;;
    -n|--dry-run)	DRYRUN=true ;;
    -k|--keep)		KEEP=true ;;
    -v|--verbose)	VERBOSE=true ;;
    -x)			set -x ;;
    -*)			die "unknown option: $1" ;;
    *)			test -z "$REMOTE_REPO" && REMOTE_REPO="$1" || die "extra argument: $1" ;;
  esac
  shift
done
test -n "${REMOTE_REPO:-}" || { show_help; die "missing <remote-repo>"; }

# == Find local repo ==
LOCAL_JJ_ROOT="$(jj root)" ||
  die "current directory is not inside a jj repository"
LOCAL_JJ_ROOT="$(readlink -f "$LOCAL_JJ_ROOT")"
vecho "== Local jj:   $LOCAL_JJ_ROOT"

LOCAL_GIT_DIR="$(jj -R "$LOCAL_JJ_ROOT" git root)" ||
  die "failed to find git backend for local: $LOCAL_JJ_ROOT"
vecho "== Local Git:  $LOCAL_GIT_DIR"

# == Split remote path ==
# <remote-repo> is either a local path or [user@]host:path for ssh access
REMOTE_HOST=
if [[ "$REMOTE_REPO" =~ ^([A-Za-z0-9_][A-Za-z0-9._@-]*):(.+)$ ]] ; then
  REMOTE_HOST="${BASH_REMATCH[1]}"
  REMOTE_PATH="${BASH_REMATCH[2]}"
else
  REMOTE_REPO="$(readlink -f "$REMOTE_REPO")"
  test -d "$REMOTE_REPO" || die "remote directory not found: $REMOTE_REPO"
  REMOTE_PATH="$REMOTE_REPO"
fi
vecho "== Remote jj:  $REMOTE_REPO"

# == Find git backends ==
# Quote one argument for the remote shell (POSIX-safe single quoting)
shellquote() { local s="$1"; printf "'%s'" "${s//\'/\'\\\'\'}"; }

# Run a jj command in the local repository
# No --ignore-working-copy here: jj git export below must snapshot the WC.
jj_local() { jj -R "$LOCAL_JJ_ROOT" --no-pager --color=never "$@"; }

# Newer jj requires explicit import and export commands for colocated repos
jj_local_git_import() { jj_local --quiet git import "$@"; }
jj_local_git_export() { jj_local --quiet git export; }

# Run a git command in the local git backend
git_local() { git --git-dir="$LOCAL_GIT_DIR" "$@"; }

# Run a jj command in the remote repository, directly or via ssh
# --ignore-working-copy: the remote is strictly read-only, never touch its WC.
jj_remote()
(
  if test -n "$REMOTE_HOST" ; then
    qargs=()
    for a in "$@" ; do
      qargs+=("$(shellquote "$a")")
    done
    ssh -oBatchMode=yes "$REMOTE_HOST" "jj -R $(shellquote "$REMOTE_PATH") --no-pager --ignore-working-copy --color=never ${qargs[*]}"
  else
    jj -R "$REMOTE_PATH" --no-pager --ignore-working-copy --color=never "$@"
  fi
)

# Run a git command against the remote git backend, directly or via ssh
git_remote()
(
  if test -n "$REMOTE_HOST" ; then
    qargs=()
    for a in "$@" ; do
      qargs+=("$(shellquote "$a")")
    done
    ssh -oBatchMode=yes "$REMOTE_HOST" "git --git-dir=$(shellquote "$REMOTE_GIT_DIR") ${qargs[*]}"
  else
    git --git-dir="$REMOTE_GIT_DIR" "$@"
  fi
)

REMOTE_GIT_DIR="$(jj_remote git root)" ||
  die "failed to find git backend for remote: $REMOTE_REPO"
vecho "== Remote Git: ${REMOTE_HOST:-}${REMOTE_HOST:+:}$REMOTE_GIT_DIR"

# Prevent syncing a repo into itself (only meaningful for local remotes)
if test -z "$REMOTE_HOST" ; then
  REMOTE_CANON="$(readlink -f "$REMOTE_GIT_DIR")"
  LOCAL_CANON="$(readlink -f "$LOCAL_GIT_DIR")"
  if test "$REMOTE_CANON" = "$LOCAL_CANON" ; then
    die "remote and local are the same repository"
  fi
fi

vecho "== Revset:     $REVSET"

# == Enumerate local heads (excluding the working copy) ==
vecho "== Enumerating local heads..."
LOCAL_REVSET='heads(::) & mutable() & ~@'
LOCAL_HEAD_IDS_OUT="$(jj_local --ignore-working-copy log --no-graph -T 'commit_id ++ "\n"' -r "$LOCAL_REVSET")" ||
  die "failed to evaluate revset at local ($LOCAL_REVSET): $LOCAL_HEAD_IDS_OUT"
LOCAL_HEAD_IDS=()
# Guard the empty case: mapfile on an empty here-string yields one empty element.
if test -n "$LOCAL_HEAD_IDS_OUT" ; then
  mapfile -t LOCAL_HEAD_IDS <<< "$LOCAL_HEAD_IDS_OUT"
fi
vecho "  Found ${#LOCAL_HEAD_IDS[@]} local heads"

# == Enumerate remote heads ==
vecho "== Enumerating remote heads..."
REMOTE_HEAD_IDS_OUT="$(jj_remote log --no-graph -T 'commit_id ++ "\n"' -r "$REVSET")" ||
  die "failed to evaluate revset at remote ($REVSET): $REMOTE_HEAD_IDS_OUT"
REMOTE_HEAD_IDS=()
if test -n "$REMOTE_HEAD_IDS_OUT" ; then
  mapfile -t REMOTE_HEAD_IDS <<< "$REMOTE_HEAD_IDS_OUT"
fi
vecho "  Found ${#REMOTE_HEAD_IDS[@]} remote heads"

if test "${#REMOTE_HEAD_IDS[@]}" -eq 0 -a "${#LOCAL_HEAD_IDS[@]}" -eq 0 ; then
  echo "$SCRIPTNAME: nothing to sync (no heads on either side)" >&2
  exit 0
fi

# == Count remote heads already visible locally (verbose only; informational) ==
# Overlap heads are no-op fetches and are protected by the carried merge, so this count drives no logic.
OVERLAP_HEAD_IDS=()
if $VERBOSE && test "${#REMOTE_HEAD_IDS[@]}" -gt 0 ; then
  vecho "== Counting overlapping heads..."
  LOCAL_VISIBLE_IDS_FILE="$TEMPDIR/visible-ids"
  # Visible set can be huge: dump to file, then grep -Ff to intersect.
  jj_local --ignore-working-copy log --no-graph -T 'commit_id ++ "\n"' -r '::heads(::)' > "$LOCAL_VISIBLE_IDS_FILE" ||
    die "failed to evaluate revset at local (::heads(::))"
  OVERLAP_HEAD_IDS_OUT="$(printf '%s\n' "${REMOTE_HEAD_IDS[@]}" | grep -Fxf "$LOCAL_VISIBLE_IDS_FILE" || true)"
  if test -n "$OVERLAP_HEAD_IDS_OUT" ; then
    mapfile -t OVERLAP_HEAD_IDS <<< "$OVERLAP_HEAD_IDS_OUT"
  fi
  vecho "  Counting ${#OVERLAP_HEAD_IDS[@]} overlapping head(s) (local and remote)"
fi

# == Split local heads into known/unknown at remote ==
# Bulk-check object existence in remote Git via cat-file --batch-check
# Also works for ancestry commits of refs/jj/keep/ refs
vecho "== Enumerating local heads known remotely..."
KNOWN_HEAD_IDS=()
if test "${#LOCAL_HEAD_IDS[@]}" -gt 0 ; then
  KNOWN_HEAD_IDS_OUT="$(printf '%s\n' "${LOCAL_HEAD_IDS[@]}" |
    git_remote cat-file --batch-check='%(objectname)' |
    grep -v ' missing$' || true)"
  if test -n "$KNOWN_HEAD_IDS_OUT" ; then
    mapfile -t KNOWN_HEAD_IDS <<< "$KNOWN_HEAD_IDS_OUT"
  fi
fi
vecho "  Found ${#KNOWN_HEAD_IDS[@]} local head(s) known at remote, that might have been abandoned"

# == Check for work ==
# Dry-run must print the plan, so force verbose for the vecho calls below.
$DRYRUN && VERBOSE=true
vecho "== Planning sync..."
if test "${#REMOTE_HEAD_IDS[@]}" -eq 0 -a "${#KNOWN_HEAD_IDS[@]}" -eq 0 ; then
  echo "$SCRIPTNAME: nothing to sync (no remote heads, no known local heads)" >&2
  exit 0
fi
vecho "  Will fetch ${#REMOTE_HEAD_IDS[@]} remote commit(s) as reachable heads"
if $KEEP ; then
  vecho "  Option --keep: no local heads will be abandoned"
else
  vecho "  Will abandon up to ${#KNOWN_HEAD_IDS[@]} local head(s) (shared remotely) if they became unreachable remotely"
fi
$DRYRUN && {
  echo "$SCRIPTNAME: dry-run requested, nothing was modified, exiting" >&2
  exit 0
}

# == Fetch remote heads into local object database ==
# Read-only remote: batch-fetch refs/jj/keep/<id>, then leftovers by raw
# commit id (over ssh needs uploadpack.allowAnySHA1InWant).
FETCH_REMOTE_URL="$REMOTE_GIT_DIR"
if test -n "$REMOTE_HOST" ; then
  # REMOTE_GIT_DIR is absolute; ssh URLs require a leading '/'
  FETCH_REMOTE_URL="ssh://$REMOTE_HOST/${REMOTE_GIT_DIR#/}"
fi
fetch_remote_heads()
{
  local ids=("$@") missing=() id
  test "${#ids[@]}" -gt 0 || return 0
  echo "fetching ${#ids[@]} head(s) via refs/jj/keep refs from $FETCH_REMOTE_URL..." >&2
  # Tolerate failure: ids lacking refs/jj/keep/ are refetched by raw object id below.
  git_local fetch --no-tags "$FETCH_REMOTE_URL" "${ids[@]/#/refs\/jj\/keep\/}" >/dev/null 2>&1 || true
  for id in "${ids[@]}" ; do
    git_local cat-file -e "$id" || missing+=("$id")
  done
  if test "${#missing[@]}" -gt 0 ; then
    echo "fetching ${#missing[@]} head(s) by raw object id from $FETCH_REMOTE_URL..." >&2
    git_local fetch --no-tags "$FETCH_REMOTE_URL" "${missing[@]}" ||
      die "raw-object fetch failed for ${missing[0]} (${#missing[@]} total): remote has no refs/jj/keep refs for them; enable uploadpack.allowAnySHA1InWant there"
  fi
}
if test "${#REMOTE_HEAD_IDS[@]}" -gt 0 ; then
  vecho "== Fetching heads from remote..."
  fetch_remote_heads "${REMOTE_HEAD_IDS[@]}"
fi

# == Create temporary merge commits ==
vecho "== Creating merge commits..."

# Ensure local heads exist in the local git object db (needed for
# non-colocated repos; harmless for colocated ones)
jj_local_git_export ||
  die "jj git export failed"

# The empty tree (well-known git hash)
EMPTY_TREE="$(printf '' | git_local hash-object -t tree --stdin)"

# Ensure git commit-tree has an identity
export GIT_AUTHOR_NAME="__jj_pull_"
export GIT_AUTHOR_EMAIL="__jj_@pull_"
export GIT_COMMITTER_NAME="__jj_pull_"
export GIT_COMMITTER_EMAIL="__jj_@pull_"

# hidden-heads merge: local heads the remote knows about; after the
# bookmark is dropped, jj's cleanup abandons those the remote discarded
HIDDEN_HEADS_MERGE=""
if test "$KEEP" = false -a "${#KNOWN_HEAD_IDS[@]}" -gt 0 ; then
  PARENT_ARGS=()
  for commit_id in "${KNOWN_HEAD_IDS[@]}" ; do
    PARENT_ARGS+=(-p "$commit_id")
  done
  MSG="__jj_pull_hidden_heads_ merge (${#KNOWN_HEAD_IDS[@]} heads)"
  HIDDEN_HEADS_MERGE="$(git_local commit-tree -m "$MSG" "${PARENT_ARGS[@]}" "$EMPTY_TREE")" ||
    die "failed to create hidden-heads merge commit"
  git_local update-ref refs/heads/__jj_pull_hidden_heads_ "$HIDDEN_HEADS_MERGE"
  vecho "  hidden-heads merge contains: ${#KNOWN_HEAD_IDS[@]} known local heads"
fi

# Carried-heads merge: fetched remote heads
CARRIED_HEADS_MERGE=""
if test "${#REMOTE_HEAD_IDS[@]}" -gt 0 ; then
  PARENT_ARGS=()
  for commit_id in "${REMOTE_HEAD_IDS[@]}" ; do
    PARENT_ARGS+=(-p "$commit_id")
  done
  MSG="__jj_pull_carried_heads_ merge (${#REMOTE_HEAD_IDS[@]} heads)"
  CARRIED_HEADS_MERGE="$(git_local commit-tree -m "$MSG" "${PARENT_ARGS[@]}" "$EMPTY_TREE")" ||
    die "failed to create carried-heads merge commit"
  git_local update-ref refs/heads/__jj_pull_carried_heads_ "$CARRIED_HEADS_MERGE"
  vecho "  carried-heads merge contains: ${#REMOTE_HEAD_IDS[@]} remote heads"
fi

# == Import both bookmarks into jj ==
jj_local_git_import --config git.abandon-unreachable-commits=false ||
  die "jj git import failed"

# == Drop hidden-heads bookmark via git, import => cleanup abandons stale heads ==
if test -n "$HIDDEN_HEADS_MERGE" ; then
  vecho "== Delete __jj_pull_hidden_heads_..."
  git_local update-ref -d refs/heads/__jj_pull_hidden_heads_
  echo "Importing deletion of hidden heads merge - hides local heads no longer reachable from remote refs..." >&2
  jj_local_git_import --config git.abandon-unreachable-commits=true ||
    die "jj git import failed"
fi

# == Dissolve pull merge, keeping parents as orphans ==
if test -n "$CARRIED_HEADS_MERGE" ; then
  vecho "== Abandon __jj_pull_carried_heads_..."
  # --config git.abandon-unreachable-commits=false prevents jj from cleaning
  # up the parent commits that were just fetched and are now orphaned.
  echo "Abandoning carried heads merge - leaves fetched detached heads..." >&2
  jj_local --config git.abandon-unreachable-commits=false abandon __jj_pull_carried_heads_ ||
    die "jj abandon __jj_pull_carried_heads_ failed"
  # Export the deletion: in non-colocated repos jj abandon does not drop the git ref.
  jj_local_git_export ||
    die "jj git export failed"
fi

echo "Pull complete." >&2
