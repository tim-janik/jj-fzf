#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
die() { echo "${BASH_SOURCE[0]##*/}: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }

show_help()
{
  cat <<-__EOF__
	Usage: "${BASH_SOURCE[0]##*/} [OPTIONS...] <revset> [--] <command>..

	Apply <command> to each of <revset> without changing descendants.
	Run shell <command> for each commit in <revset>.
	Use \`--restore-descendants\` to run commands without affecting descendants.

	Options:
	  -h, --help	Display this help and exit
	  -E		Ignore errors when running <command>
	  --restore-descendants
			Preserve the content when rebasing descendants
	Arguments:
	  revset         Revisions to process
	  command        Shell command to execute
	__EOF__
}

# == Parse Options ==
ONERR=false
REVSET=
RESTORE_DESCENDANTS=
while test $# -ne 0 ; do
  case "$1" in \
    -E)				ONERR=true ;;
    -h|--help)			show_help; exit 0 ;;
    --restore-descendants)	RESTORE_DESCENDANTS=--restore-descendants ;;
    --)				shift ; break ;;
    -*)				die "unknown option: $1" ;;
    *)				test -z "$REVSET" && REVSET="$1" || break ;;
  esac
  shift
done
test -n "$REVSET" || {
  echo "${BASH_SOURCE[0]##*/}: missing <revset>" >&2
  show_help
  exit 1
}
test -n "$*" || die "missing <command>"
# COMMAND == "$@"

# == failsafe ==
START_OP=$(jj op log -n1 --no-graph -T 'self.id().short()')
echo ">> Command to undo script effects:" >&2
echo "     jj op restore $START_OP" >&2

# == Save Workgion Copy ==
AT_HEAD_ID=$(jj --no-pager --ignore-working-copy log --color=never --no-graph -T change_id -r @)

# == find commit IDs ==
readarray -t COMMITIDS < <( jj --no-pager --ignore-working-copy log --no-graph --color=never -T 'commit_id ++ "\n"' -r "$REVSET" )

# == run commands ==
jj new @ # keeps $AT_HEAD_ID alive even if empty
for CID in "${COMMITIDS[@]}" ; do
  ( set -xe
    # prepare for changes
    jj new "$CID"
    # run command, then integrate or abandon changes
    ("$@") || $ONERR &&
        jj restore --from @ --to @- $RESTORE_DESCENDANTS ||
          jj abandon @
  )
done
ERR="$?"

# == Restore Workgion Copy ==
jj edit "$AT_HEAD_ID"

# == Recovery Msg ==
if test "$ERR" == 0 ; then
  echo "# Rewrite done, exit_status=$ERR" >&2
else
  echo "# Rewrite failed, exit_status=$ERR" >&2
fi
echo "# To rewind, use:" >&2
echo "  jj op restore $START_OP" >&2
