#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail

die() { echo "$0: ${*:-aborting}" >&2; exit 1; }
test $# -le 2 || die 'Usage: check-removals.sh [BASE [HEAD]]'
base="${1-}"
tip="${2-HEAD}"
if ! git rev-parse --git-dir >/dev/null 2>&1 ; then
  test -z "$base" || die 'Cannot check an explicit commit range outside a Git checkout'
  echo '  SKIP    Removal evidence needs Git history'
  exit 0
fi
if test -z "$base" ; then
  for ref in refs/remotes/origin/trunk refs/heads/trunk ; do
    if git rev-parse --verify "$ref^{commit}" >/dev/null 2>&1 ; then
      base="$ref"
      break
    fi
  done
fi
test -n "$base" || die 'Missing trunk history; pass a base commit explicitly'
base=$(git rev-parse --verify --end-of-options "$base^{commit}") || die 'Invalid base commit'
tip=$(git rev-parse --verify --end-of-options "$tip^{commit}") || die 'Invalid head commit'
commits=$(git rev-list --no-merges "$tip" "^$base")
status=0
for commit in $commits ; do
  removed=$(git diff --numstat -M "$commit^!" -- \
              jj-fzf GNUmakefile '*.sh' '*.py' '*.awk' '*.el' '*.mk' '*.yml' '*.yaml' \
              ':!tests/**' ':!**/test_*' ':!**/test-*' ':!**/*-test.*' ':!*.g.*' |
            awk '$1 != "-" { n += $2 - $1 } END { print n + 0 }')
  test "$removed" -ge 10 || continue
  message=$(git log -1 --format=%B "$commit")
  grep -qE '^Evidence:[[:blank:]]*[^[:space:]]' <<< "$message" && continue
  echo "$(git log -1 --format='%h %s' "$commit"): removes $removed source lines without a nonempty Evidence: paragraph" >&2
  status=1
done
exit "$status"
