#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail
SCRIPTNAME="${0##*/}"
SCRIPTDIR="$(readlink -f "$0")" && SCRIPTDIR="${SCRIPTDIR%/*}"
TEST=
die()
{
  ( set +x
    R='\033[31m'
    Z='\033[0m'
    [ -n "$*" ] &&
      echo -e "$SCRIPTNAME: $R**ERROR**:${TEST:+ $TEST:}$Z ${*:-aborting}"
  ) >&2
  exit 77
}
DEVERR=/dev/null
[[ " $* " =~ -x ]] && {
  DEVERR=/dev/stderr
  PS4="+ $SCRIPTNAME:\${LINENO}: "
  set -x
}

export JJ_FZF_ERROR_DELAY=0 # instant errors for testing

# == Helpers ==
jj-fzf()
{
  $SCRIPTDIR/jj-fzf "$@"
}
assert1error()
{
  grep -Eq '\bERROR:' <<<"$*" ||
    die "output contains no ERROR message: $*"
}
assert0error()
{
  ! grep -Eq '\bERROR:' <<<"$*" ||
    die "output contains an ERROR message: $*"
}
assert0errorinerror()
{
  ! grep -Eq 'ERRORINERROR' <<<"$*" ||
    die "output contains an ERRORINERROR message: $*"
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
TEST_OK()
{
  printf '  %-7s %s\n' OK "$*"
}
mkcommits() # mkcommits A B 'A|B ->C'
( # Create empty test commits with bookamrks
  while test $# -ne 0 ; do
    P=@ && [[ "$1" =~ (.+)-\>(.+) ]] && P="${BASH_REMATCH[1]}" C="${BASH_REMATCH[2]}" || C="$1"; shift
    jj --no-pager new -m="$C" -r all:"$P"
    jj bookmark set -r @ "$C"
  done >$DEVERR 2>&1
)

# == Setup Environment ==
TEMPD="`mktemp --tmpdir -d jjfzftstXXXXXX`" || die "mktemp failed"
trap "cd '$TEMPD/..' && rm -rf '$TEMPD'" 0 HUP INT QUIT TRAP USR1 PIPE TERM
echo "$$" > $TEMPD/testing.sh.pid
cd $TEMPD/
clear_repo()
{
  REPO="${1:-repo}"
  cd $TEMPD/
  rm -rf $TEMPD/$REPO
  mkdir $TEMPD/$REPO
  cd $TEMPD/$REPO
  git init >$DEVERR 2>&1
  jj git init --colocate >$DEVERR 2>&1
}

# == TESTS ==
TEST='jj-fzf-functions-fail-early'
clear_repo
( set -e
  # Test that jj-fzf describe does not continue with $EDITOR
  # once an invalid change_id has been encountered.
  export JJ_CONFIG='' EDITOR='echo ERRORINERROR'
  OUT="$(set +x; jj-fzf describe 'zzzzaaaa' 2>&1)" && E=$? || E=$?
  assert_nonzero $E
  assert1error "$OUT"
  assert0errorinerror "$OUT"
); TEST_OK "$TEST"

TEST='jj-fzf-new'
clear_repo && mkcommits A B
( set -e
  export JJ_CONFIG=''
  WC="$(jj log --no-pager --ignore-working-copy --no-graph -T commit_id -r @)"
  OUT="$(set +x; jj-fzf new A B 2>&1)" && E=$? || E=$?
  assert_zero $E
  assert0error "$OUT"
  NEW="$(jj log --no-pager --ignore-working-copy --no-graph -T commit_id -r @)"
  test "$WC" != "$NEW" ||
    die "failed to create new revision"
); TEST_OK "$TEST"

# clear_repo && mkcommits A B 'A ->C' 'B|C ->D' && jj new >$DEVERR 2>&1
# jj log --no-pager -r ..@
