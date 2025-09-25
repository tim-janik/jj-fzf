#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
die() { echo "${BASH_SOURCE[0]##*/}: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }
ABSPATHSCRIPT=$(readlink -f "${BASH_SOURCE[0]}")	# Resolve symlinks to find installdir

# == Setup & Options ==
source "${ABSPATHSCRIPT%/*}"/setup.sh	# preflight.sh
jjfzf_tempd				# assigns $JJFZF_TEMPD
echo > $JJFZF_TEMPD/reparent.env
PRINTOUT=
while test $# -ne 0 ; do
  case "$1" in \
    -x)			set -x ;;
    --help-bindings)	PRINTOUT="$1" ;;
    *)         		break ;;
  esac
  shift
done

# == Config ==
TITLE='Change Parents'
export JJFZF_REPARENT_SRC="${1-@}"
echo "OP='|'"			>> $JJFZF_TEMPD/reparent.env
echo 'SP=false'			>> $JJFZF_TEMPD/reparent.env
echo 'II='			>> $JJFZF_TEMPD/reparent.env

# == Bindings ==
B=() H=()

H+=( 'Alt-A:  Add currently selected revisions as new parents' )
B+=( --bind "alt-a:execute-silent( sed 's/^OP=.*/OP=\"|\"/' -i $JJFZF_TEMPD/reparent.env )+refresh-preview" )

H+=( 'Alt-D:  Delete selected revisions from list of existing parents' )
B+=( --bind "alt-d:execute-silent( sed 's/^OP=.*/OP=\"~\"/' -i $JJFZF_TEMPD/reparent.env )+refresh-preview" )

H+=( 'Alt-I:  Ignore-immutable permits rebasing immutable commits' )
B+=( --bind "alt-i:execute-silent( sed 's/^II=-.*/II=x/; s/^II=$/II=--ignore-immutable/; s/^II=x.*/II=/' -i $JJFZF_TEMPD/reparent.env )+refresh-preview" )

H+=( 'Alt-P:  Simplify-parents of the revision (after any rebasing)' )
B+=( --bind "alt-p:execute-silent( sed 's/^SP=false/SP=x/; s/^SP=true/SP=false/; s/^SP=x/SP=true/' -i $JJFZF_TEMPD/reparent.env )+refresh-preview" )

B+=( --bind 'enter:execute( jjfzf_handle_reparenting RUN {+2} )+close+close+close' )
B+=( --input-label " Enter: Run Reparenting Commands " )

# == jjfzf_reparent_list ==
# Determine new parent revset
jjfzf_reparent_revset()
(
  set -Eeuo pipefail
  source $JJFZF_TEMPD/reparent.env
  MODIFY_PARENTS="( $(jjfzf_ccrevs "$@") )"
  OLD_PARENTS_REVSET="($JJFZF_REPARENT_SRC-)"
  if test "$OP" == '|' ; then
    NEW_PARENTS_REVSET="($MODIFY_PARENTS | $OLD_PARENTS_REVSET) ~ $JJFZF_REPARENT_SRC"
  else
    NEW_PARENTS_REVSET="$OLD_PARENTS_REVSET ~ $MODIFY_PARENTS"
  fi
  echo "$NEW_PARENTS_REVSET"
)
export -f jjfzf_reparent_revset

# == jjfzf_handle_reparenting ==
# Perform reparenting or print reparenting plan
jjfzf_handle_reparenting()
(
  set -Eeuo pipefail
  source $JJFZF_TEMPD/reparent.env
  # Preview operation or run it
  if test "$1" == PREVIEW ; then
    PREVIEW=true
    pecho() { echo "$@" ; }
    run() { true ; }
  else
    test "$1" == RUN || exit 127
    PREVIEW=false
    pecho() { true ; }
    run() { jjfzf_run "$@" ; }
  fi
  shift	# eat preview arg
  # determine old and new parents
  OLD_PARENTS_REVSET="($JJFZF_REPARENT_SRC-)"
  OLD_PARENTS_LIST=( $(jjfzf_chronological_change_ids "$OLD_PARENTS_REVSET") )
  NEW_PARENTS_REVSET="$(jjfzf_reparent_revset "$@")"
  DEST_LIST=( $(jjfzf_chronological_change_ids "coalesce( $NEW_PARENTS_REVSET, root() )") )
  pecho
  # reparent revisions
  if test " ${OLD_PARENTS_LIST[*]}" != " ${DEST_LIST[*]}" ; then
    pecho jj rebase $II --source "$JJFZF_REPARENT_SRC" "${DEST_LIST[@]/#/-d}"
    run +n jj rebase $II --source "$JJFZF_REPARENT_SRC" "${DEST_LIST[@]/#/-d}"
  else
    pecho "# No rebase needed:" "$JJFZF_REPARENT_SRC"
  fi
  pecho
  # simplify-parents
  if $SP; then
    pecho jj simplify-parents $II -r "$JJFZF_REPARENT_SRC"
    run +n jj simplify-parents $II -r "$JJFZF_REPARENT_SRC"
  else
    pecho
  fi
  if $PREVIEW ; then
    pecho
    pecho "ADD PARENTS:"
    if test "$OP" == '|' ; then
      jj --no-pager --ignore-working-copy log $JJFZF_COLOR --no-graph -T builtin_log_oneline -r "($NEW_PARENTS_REVSET) ~ ($OLD_PARENTS_REVSET)" --reversed |
	sed "s/^/+ /"
    fi
    pecho
    pecho "REMOVE PARENTS:"
    if test "$OP" != '|' ; then
      jj --no-pager --ignore-working-copy log $JJFZF_COLOR --no-graph -T builtin_log_oneline -r "($OLD_PARENTS_REVSET) & ~ ($NEW_PARENTS_REVSET)" --reversed |
	sed "s/^/- /"
    fi
  fi
)
export -f jjfzf_handle_reparenting

# == jjfzf_mark_revs ==
# Add marker to input revisions
jjfzf_log0_marked_revs()
(
  set -Eeuo pipefail #-x
  echo > $JJFZF_TEMPD/reparent.sed
  echo "/$JJFZF_REPARENT_SRC/s/(¸¸)/\1 /" >> $JJFZF_TEMPD/reparent.sed
  jjfzf_log0 |
    sed -r -f $JJFZF_TEMPD/reparent.sed
)
export -f jjfzf_log0_marked_revs

# == jjfzf_header ==
# Help text
export JJFZF_HELP=$(printf "%s\n" "${H[@]}" | jjfzf_bold_keys)
jjfzf_header()
(
  set -Eeuo pipefail #-x
  echo "$JJFZF_HELP"
)
export -f jjfzf_header

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
  --color=border:yellow,label:yellow
  --border-label "-[ ${TITLE^^} — JJ-FZF ]-"
  --preview-label " Command "
  --bind 'focus:+transform-ghost( R={2} && echo -n "${R:0:12}" )'
  --prompt 'Parent > '
  --bind "start,resize,alt-h:+transform-header: jjfzf_header "
  --bind "start:+toggle-preview-wrap"
  --footer "${TITLE}"
)
test -z "${FZF_POS-}" ||
  FZF_ARGS+=( --bind "load:+pos($FZF_POS)+unbind(load)" )
jjfzf_status
export JJFZF_LOAD_LIST=jjfzf_log0_marked_revs
unset FZF_DEFAULT_OPTS FZF_DEFAULT_COMMAND
jjfzf_load --stdout |
  fzf -m "${FZF_ARGS[@]}" "${B[@]}" \
      --read0 '-d¸' --accept-nth=2 --with-nth '{1} {4..}' \
      --preview 'jjfzf_handle_reparenting PREVIEW {+2}'
