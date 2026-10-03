# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

# == Check Dependencies ==
jj --help >/dev/null
PATH="$SCRIPTDIR/..:$PATH"	# ensure jj-fzf is in $PATH
jj-fzf --version >/dev/null

# == VARIABLE Setup ==
export JJFZF_ERROR_DELAY=0 # instant errors for testing
TEMPD=

# == OPTIONS ==
DEVERR=/dev/null
[[ " $* " =~ -x ]] && {
  # EPOCHREALTIME (bash >= 5.0) is recomputed per reference, so the PS4
  # prompt carries a per-trace-line timestamp fork-free; deltas between
  # consecutive lines show each command's duration.
  PS4="+ \${EPOCHREALTIME} \${BASH_SOURCE[0]##*/}:\${LINENO}: "
  DEVERR=/dev/stderr
  set -x
}
[[ " $* " =~ -v ]] &&
  DEVERR=/dev/stderr

# == Utils ==
die()
{
  local R=$'\033[31m' Z=$'\033[0m'
  [ -n "$*" ] &&
    echo "${BASH_SOURCE[1]}:${BASH_LINENO[0]}:${FUNCNAME[1]}: $R**ERROR**:$Z ${*:-aborting}" >&2;
  exit 127
}
die-() # die, using *caller* as origin
{
  local R=$'\033[31m' Z=$'\033[0m'
  [ -n "$*" ] &&
    echo "${BASH_SOURCE[2]}:${BASH_LINENO[1]}:${FUNCNAME[2]}: $R**ERROR**:$Z ${*:-aborting}" >&2;
  exit 127
}
temp_dir()
{
  test -n "$TEMPD" || {
    TEMPD="`mktemp --tmpdir -d jjfzf0XXXXXX`" || die "mktemp failed"
    trap "rm -rf '$TEMPD'" 0 HUP INT QUIT TRAP USR1 PIPE TERM
    echo "$$" > $TEMPD/jjfzf-tests.pid
  }
}

# == lib_source ==
# Source a line-1 range of lib/$1 into the test shell to reach internal
# functions without triggering the script's top-level fzf UI. Runs from a
# sandbox so relative `source`s resolve, with positional args cleared for
# the scripts' option parsing loops.
lib_source()
{ # LIBFILE SEDEXPR
  local LIBFILE="$1" SEDEXPR="$2"
  # Must stay: only line-1 ranges, mid-file ranges would couple tests to script internals
  [[ "$SEDEXPR" == 1,* ]] ||
    die "lib_source: only ranges starting at line 1 are supported: $SEDEXPR"
  mkdir -p $TEMPD/libtest
  cp $SCRIPTDIR/../preflight.sh $TEMPD/preflight.sh
  cp $SCRIPTDIR/../lib/setup.sh $TEMPD/libtest/setup.sh
  sed -n "$SEDEXPR" "$SCRIPTDIR/../lib/$LIBFILE" > $TEMPD/libtest/part.sh
  local -a OLDARGS=("$@") # source without positional args, so option loops
  set --			# in the sourced script see no arguments
  source $TEMPD/libtest/part.sh
  set -- "${OLDARGS[@]}"
  rm -fr $TEMPD/libtest
}

# == Repository ==
tear_down()
(
  REPO="${1:-repo}"
  test -n "$TEMPD" &&
    rm -rf $TEMPD/$REPO
)
clear_repo()
(
  REPO="${1:-repo}"
  test -n "$TEMPD" || die "missing TEMPD"
  cd $TEMPD/
  rm -rf $TEMPD/$REPO
  mkdir $TEMPD/$REPO
  cd $TEMPD/$REPO
  git init >$DEVERR 2>&1
  jj git init --colocate >$DEVERR 2>&1
  echo "$PWD"
)
cd_new_repo()
{
  RP=$(clear_repo "$@")
  cd "$RP"
}
mkcommits()
( # Create empty test commits with bookamrks
  while test $# -ne 0 ; do
    P=@ && [[ "$1" =~ (.+)-\>(.+) ]] &&
      P="${BASH_REMATCH[1]}" C="${BASH_REMATCH[2]}" || C="$1"
    shift
    jj --no-pager new -m="$C" -r "$P"
    jj bookmark set -r @ "$C"
  done >$DEVERR 2>&1		# mkcommits A B 'A|B ->C'
)
get_commit_id()
(
  REF="$1"
  COMMIT_ID=$(jj --ignore-working-copy log --no-graph -T commit_id -r "description(exact:\"$REF\n\")" 2>/dev/null) &&
    test -n "$COMMIT_ID" ||
      COMMIT_ID=$(jj --ignore-working-copy log --no-graph -T commit_id -r "$REF") || exit
  echo "$COMMIT_ID"
)
get_change_id()
(
  COMMIT_ID=$(get_commit_id "$@")
  UNIQUECHANGE='if(self.divergent(), "", change_id)'
  # only allow non-divergent: https://www.jj-vcs.dev/latest/guides/divergence/
  CHANGE_ID=$(jj --ignore-working-copy log --no-graph -T "$UNIQUECHANGE" -r " $COMMIT_ID ") || exit
  echo "$CHANGE_ID"
)
commit_count()
(
  R="${1:-::}"
  jj --ignore-working-copy log --no-graph -T '"\n"' -r "$R" | wc -l
)
jj_log()
(
  jj --ignore-working-copy log -T builtin_log_oneline -r ::
)
jj_status()
(
  jj status >$DEVERR 2>&1
)

# == Assertions ==
assert_commit_count()
(
  V="$1"
  C="$(commit_count "${2:-::}")"
  test "$C" -eq "$V" ||
    die- "assert_commit_count: mismatch: $C == $V"
)
assert_@()
(
  V="$1"
  C="$(get_change_id '@')"
  test "$C" == "$V" && return
  C="$(get_commit_id '@')"
  test "$C" == "$V" && return
  die- "assert_@: mismatch: $C == $V"
)
assert_@-()
(
  V="$1"
  C="$(get_change_id '@-')"
  test "$C" == "$V" && return
  C="$(get_commit_id '@-')"
  test "$C" == "$V" && return
  die- "assert_@-: mismatch: $C == $V"
)
assert_commits_eq()
(
  U="$1"
  V="$2"
  C="$(get_commit_id "$U")"
  D="$(get_commit_id "$V")"
  test "$C" == "$D" ||
    die- "assert_commits_eq: mismatch: $C == $D"
)
assert_nonzero()
{
  V="$1"
  test 0 != "$V" ||
    die- "assert_nonzero: mismatch: 0 != $V"
}
assert_zero()
{
  V="$1"
  test 0 == "$V" ||
    die- "assert_zero: mismatch: 0 == $V"
}
assert0error()
{
  ! grep -Eq '\bERROR:' <<<"$*" ||
    die- "assert0error: unexpected ERROR message: $*"
}
assert1error()
{
  grep -Eiq '\bERROR:' <<<"$*" ||
    die- "assert1error: missing mandatory ERROR message: $*"
}

# == Errors ==
bash_error()
{
  local code="$?" D=$'\033[2m' Z=$'\033[0m'
  echo "$D${BASH_SOURCE[1]}:${BASH_LINENO[0]}:${FUNCNAME[1]}:trap: exit status: $code$Z" >&2
  exit "$code"
}
trap 'bash_error' ERR
