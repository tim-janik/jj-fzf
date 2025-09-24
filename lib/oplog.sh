#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
die() { echo "${BASH_SOURCE[0]##*/}: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }
ABSPATHSCRIPT=$(readlink -f "${BASH_SOURCE[0]}")	# Resolve symlinks to find installdir

# == Setup & Options ==
source "${ABSPATHSCRIPT%/*}"/setup.sh	# preflight.sh
jjfzf_tempd				# assigns $JJFZF_TEMPD
echo 'DIFF=1'	> $JJFZF_TEMPD/oplog.env
PRINTOUT=
while test $# -ne 0 ; do
  case "$1" in \
    --help-bindings)	PRINTOUT="$1" ;;
    -x)			set -x ;;
    *)         		break ;;
  esac
  shift
done

# == Config ==
TITLE='Operation Log'
jjfzf_log_detailed	# for preview, assigns $JJFZF_LOG_DETAILED_CONFIG
B=() H=()

# == Bindings ==
RELOAD="reload-sync(cat $JJFZF_TEMPD/jjfzf_list)"	# see jjfzf_load

# Inject
H+=( 'Alt-J: Inject working copy of the selected operation as historic commit before @' )
B+=( --bind "alt-j:execute( jjfzf_op_inject {2} ; jjfzf_load_and_status )+$RELOAD+close+close+close" )
jjfzf_op_inject()
(
  set -Eeuo pipefail
  COMMIT="$(jj --no-pager --ignore-working-copy --at-op "$1" show --tool true -T commit_id -r @)"
  jjfzf_inject "$COMMIT"
)
export -f jjfzf_op_inject

# Restore operation
H+=( 'Alt-R: Restore repository to the selected operation via `jj op restore`' )
B+=( --bind "alt-r:execute( jjfzf_run jj --no-pager op restore {2} )+$RELOAD+down" )

# Revert operation
H+=( 'Alt-V: Revert the effects of the selected operation via `jj op revert`' )
B+=( --bind "alt-v:execute( jjfzf_run jj --no-pager op revert {2} )+$RELOAD+down" )

# Redo
H+=( 'Alt-Y: Redo the last undo operation (marked `⋯`)' )
B+=( --bind "alt-y:execute( jjfzf_run jj --no-pager redo )+$RELOAD+down" )

# Undo
H+=( 'Alt-Z: Undo the next operation (not already marked `⋯`)' )
B+=( --bind "alt-z:execute( jjfzf_run jj --no-pager undo )+$RELOAD+down" )

# Enter
H+=( 'Enter: Info browser for the selected operation' )
B+=( --bind 'enter:execute( jjfzf_op_info {2} | $JJFZF_PAGER )' )

# == Header Help ==
HEADER_HELP=$(printf "%s\n" "${H[@]}")
B+=( --header "$HEADER_HELP" )

# == jjfzf_op_info ==
# Show operation info, diff and @ history
jjfzf_op_info()
(
  set -Eeuo pipefail #-x
  OPID="$1"
  jj --no-pager --ignore-working-copy $JJFZF_COLOR op show -p "$OPID"
  echo
  echo
  echo "jj --at-operation=$OPID log -p -r ..@"
  jj --no-pager --ignore-working-copy $JJFZF_COLOR --at-operation="$OPID" log -p -r ..@ |
    sed '3001q'
)
export -f jjfzf_op_info

# == jjfzf_operation_id_resolve ==
# Resolve operations by following undo/redo steps
jjfzf_operation_id_resolve()
(
  op_id="${1-@}"
  while :; do
    next=$(
      jj --no-pager --ignore-working-copy op show --color=never --no-graph --no-op-diff -T "self.id() ++ ' ' ++ self.description().first_line()" "$op_id" |
	# Detect "restore to operation" indirection
	sed -rn 's/.*\brestore to operation ([0-9a-f]{32,}).*/\1/p'
	)
    [ -z "$next" ] && break	# Followed all indirections
    op_id="$next"
  done
  echo "$op_id"
)
export -f jjfzf_operation_id_resolve

# == jjfzf_oplog0 ==
# Show `jj op log` but mark undone operations with '⋯'
jjfzf_oplog0()
(
  set -Eeuo pipefail
  JJOPLOG="jj --no-pager --ignore-working-copy op log"
  # Determine range of undo operations
  LAST_OPID=$(jjfzf_operation_id_resolve @)
  TMPL=" '¸'++stringify(self.id().short(32))++'¸¸' ++ builtin_op_log_compact "
  if test "$LAST_OPID" != @ ; then
    $JJOPLOG $JJFZF_COLOR -T "$TMPL" |
      sed -r "1,/${LAST_OPID:0:32}¸¸/{ /${LAST_OPID:0:32}¸¸/! s/([@~◆×○])/⋯/ }" # ⮌ ⋯ ⤺↶
  else
    $JJOPLOG $JJFZF_COLOR -T "$TMPL"
  fi |
    sed '/¸¸/s/^/\x00/ ; 1s/^\x00//'
)
export -f jjfzf_oplog0

# == PRINTOUT ==
[[ "$PRINTOUT" == --help-bindings ]] && {
  for h in "${H[@]}" ; do
    echo "$h" |
      sed -r 's/^([^ ]+): *([^ ]+) *(.*)/\n### _\1_: **\2**\n\2 \3/'
  done
  echo
  exit 0
}

# == fzf ==
FZF_ARGS+=(
  --color=border:blue,label:blue
  --border-label "-[ ${TITLE^^} — JJ-FZF ]-"
  --preview-label " Operation Info "
  --footer "${TITLE}"
  --bind 'focus:+transform-ghost( R={2} && echo -n "${R:0:18}" )'
  --prompt 'OPLOG > '
)
jjfzf_status
export JJFZF_LOAD_LIST=jjfzf_oplog0
unset FZF_DEFAULT_OPTS FZF_DEFAULT_COMMAND
jjfzf_load --stdout |
  fzf +m "${B[@]}" "${FZF_ARGS[@]}" \
      --read0 '-d¸' --accept-nth=2 --with-nth '{1} {4..}' \
      --preview 'jjfzf_op_info {2}'
