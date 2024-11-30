#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail
SCRIPTNAME="${0##*/}"
TEST=
die()
{
  set +x
  R='\033[31m'
  Z='\033[0m'
  [ -n "$*" ] &&
    echo -e "$SCRIPTNAME: $R**ERROR**:${TEST:+ $TEST:}$Z ${*:-aborting}" >&2
  exit 127
}
#PS4="$SCRIPTNAME:\${LINENO}: " && set -x

export JJ_FZF_ERROR_DELAY=0 # instant errors for testing

# == Helpers ==
assert1error()
{
  local L="$(wc -l <<<"$*")"
  test "$L" == 1 ||
    die $'output exceeds one line: \\\n' "$*"
  grep -Eq '\bERROR:' <<<"$*" ||
    die "output contains no ERROR message: $*"
}
assert0error()
{
  grep -Eq '\bERROR:' <<<"$*" &&
    die "output contains an ERROR message: $*"
}
assert_zero()
{
  test "$1" == 0 ||
    die "command exit status was not zero: $1"
}
assert_nonzero()
{
  test "$1" != 0 ||
    die "command exit status failed to be non-zero: $1"
}
OK()
{
  printf "  %-7s" OK
  echo "${TEST:-}$*"
}

# == TESTS ==
TEST='jj-fzf-functions-fail-early'
( set +e
  OUT="$(export EDITOR=false JJ_CONFIG='' && ./jj-fzf describe 'zzzzaaaa' 2>&1)"
  assert_nonzero $?
  assert1error "$OUT"
) && OK

TEST='jj-fzf-new'
( set +e
  WC="$(jj log --no-pager --ignore-working-copy --no-graph -T commit_id -r @)"
  OUT="$(export JJ_CONFIG='' && ./jj-fzf new '@' 2>&1)"
  assert_zero $?
  assert0error "$OUT"
  NEW="$(jj log --no-pager --ignore-working-copy --no-graph -T commit_id -r @)"
  test "$WC" != "$NEW" ||
    die "failed to create new revision"
) && OK


