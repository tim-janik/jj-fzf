#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
die() { echo "${BASH_SOURCE[0]##*/}: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }
ABSPATHSCRIPT=$(readlink -f "${BASH_SOURCE[0]}")	# Resolve symlinks to find installdir

# == Setup & Options ==
source "${ABSPATHSCRIPT%/*}"/setup.sh	# preflight.sh
jjfzf_tempd				# assigns $JJFZF_TEMPD
echo > $JJFZF_TEMPD/rebase.env
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
TITLE='Rebase & Duplicate'
ARGS=("$@")
export JJFZF_CREVS="$(jjfzf_ccrevs "$@")"	# OR-combined revisions
echo 'DP='			>> $JJFZF_TEMPD/rebase.env
echo 'CH='			>> $JJFZF_TEMPD/rebase.env
echo 'TO=--destination'		>> $JJFZF_TEMPD/rebase.env
echo 'SP=false'			>> $JJFZF_TEMPD/rebase.env
echo 'II='			>> $JJFZF_TEMPD/rebase.env
if [[ $JJFZF_CREVS =~ \| ]] ; then
  echo 'FR=--revisions'		>> $JJFZF_TEMPD/rebase.env	# multi revs
else
  echo 'FR=--source'		>> $JJFZF_TEMPD/rebase.env	# single rev
fi
jjfzf_status		# snapshot dirty working tree
B=() H=()

# == Bindings ==
PDUP='change-prompt(Duplicate Target > )'
PRBS='change-prompt(Rebase Target > )'
B+=( --bind "start:$PRBS" )

H+=( "Alt-D:  Duplicate — copies the specified revisions" )
B+=( --bind "alt-d:$PDUP+execute-silent( sed 's/^CH=.*/CH=/;   s/^DP=.*/DP=1/; s/^FR=.*/FR=--revisions/' -i $JJFZF_TEMPD/rebase.env )+refresh-preview" )

H+=( "Alt-C:  Children — duplicate the revisions with descendants" )
B+=( --bind "alt-c:$PDUP+execute-silent( sed 's/^CH=.*/CH=::/; s/^DP=.*/DP=1/; s/^FR=.*/FR=--source/   ' -i $JJFZF_TEMPD/rebase.env )+refresh-preview" )

H+=( "Alt-B:  Branch — rebase whole branches relative to destination's ancestors" )
B+=( --bind "alt-b:$PRBS+execute-silent( sed 's/^CH=.*/CH=/;   s/^DP=.*/DP=/;  s/^FR=.*/FR=--branch/   ' -i $JJFZF_TEMPD/rebase.env )+refresh-preview" )

H+=( "Alt-S:  Source — rebase a revision together with descendants" )
B+=( --bind "alt-s:$PRBS+execute-silent( sed 's/^CH=.*/CH=/;   s/^DP=.*/DP=/;  s/^FR=.*/FR=--source/   ' -i $JJFZF_TEMPD/rebase.env )+refresh-preview" )

H+=( "Alt-R:  Revision — rebase only given revisions, moves descendants onto parent" )
B+=( --bind "alt-r:$PRBS+execute-silent( sed 's/^CH=.*/CH=/;   s/^DP=.*/DP=/;  s/^FR=.*/FR=--revisions/' -i $JJFZF_TEMPD/rebase.env )+refresh-preview" )

H+=( 'Alt-P:  Simplify-Parents of the revisions after rebasing' )
B+=( --bind "alt-p:execute-silent( sed 's/^SP=false/SP=x/; s/^SP=true/SP=false/; s/^SP=x/SP=true/' -i $JJFZF_TEMPD/rebase.env )+refresh-preview" )

H+=( 'Alt-I:  Ignore-Immutable permits rebasing immutable commits' )
B+=( --bind "alt-i:execute-silent( sed 's/^II=-.*/II=x/; s/^II=$/II=--ignore-immutable/; s/^II=x.*/II=/' -i $JJFZF_TEMPD/rebase.env )+refresh-preview" )

H+=( "Ctrl-D: Destination — pick the target to rebase onto" )
B+=( --bind "ctrl-d:execute-silent( sed 's/^TO=.*/TO=--destination/' -i $JJFZF_TEMPD/rebase.env )+refresh-preview" )

H+=( "Ctrl-A: After — pick the target to insert after" )
B+=( --bind "ctrl-a:execute-silent( sed 's/^TO=.*/TO=--insert-after/' -i $JJFZF_TEMPD/rebase.env )+refresh-preview" )

H+=( "Ctrl-B: Before — pick the target to insert before" )
B+=( --bind "ctrl-b:execute-silent( sed 's/^TO=.*/TO=--insert-before/' -i $JJFZF_TEMPD/rebase.env )+refresh-preview" )

# == Header Help ==
HEADER_HELP=$(printf "%s\n" "${H[@]}" | jjfzf_bold_keys)
B+=( --header "$HEADER_HELP" )

# == jjfzf_rebase_enter ==
# Perform rebase or duplicate and simplify-parents
jjfzf_rebase_enter()
(
  set -Eeuo pipefail #-x
  TARGET="$1"
  source $JJFZF_TEMPD/rebase.env
  # duplicate revisions
  if test -n "$DP" ; then
    jjfzf_run +n jj duplicate $II $TO "$TARGET" -r "$JJFZF_CREVS$CH"
  else # rebase revisions
    jjfzf_run +n jj rebase $II $TO "$TARGET" $FR "$JJFZF_CREVS"
  fi
  # simplify-parents
  if $SP; then
    jjfzf_run +n jj simplify-parents -r "$JJFZF_CREVS"
  fi
)
export -f jjfzf_rebase_enter
B+=( --bind 'enter:become( jjfzf_rebase_enter {2} )' )
B+=( --input-label " Enter: Run Rebase Commands " )

# == jjfzf_rebase_plan ==
# Planning of unconfirmed JJ command
jjfzf_rebase_plan()
(
  set -Eeuo pipefail #-x
  TARGET="$1"
  source $JJFZF_TEMPD/rebase.env
  echo
  test -z "$DP" ||
    echo "jj duplicate $II $TO $TARGET -r '$JJFZF_CREVS'$CH"
  test -n "$DP" ||
    echo "jj rebase $II $TO $TARGET $FR '$JJFZF_CREVS'"
  echo
  test $SP == true &&
    echo "jj simplify-parents -r '$JJFZF_CREVS'"
  echo
  T="${TO#--}" && echo "${T^^}:" && # TO
    jjfzf_oneline_graph -r "$TARGET" | sed q
  echo
  F="${FR#--}" && echo "${F^^}:" && # FROM
    jjfzf_oneline -r "$JJFZF_CREVS" | sed -r 's/^/  /'
  echo
  echo "COMMON:" &&
    jjfzf_oneline_graph -r "heads( ::($JJFZF_CREVS) & ::$TARGET)" | sed q
)
export -f jjfzf_rebase_plan
B+=( --preview 'jjfzf_rebase_plan {2}' )
B+=( --preview-label " Commands " )

# == jjfzf_mark_revs ==
# Add marker to input revisions
jjfzf_log0_marked_revs()
(
  set -Eeuo pipefail #-x
  echo > $JJFZF_TEMPD/rebase.sed
  for a in "${ARGS[@]}" ; do
    echo "/$a/s/(¸¸)/\1 /" >> $JJFZF_TEMPD/rebase.sed
  done
  jjfzf_log0 |
    sed -r -f $JJFZF_TEMPD/rebase.sed
)
export -f jjfzf_log0_marked_revs

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
  --color=border:magenta,label:magenta
  --border-label "-[ ${TITLE^^} — JJ-FZF ]-"
  --footer "${TITLE}"
  --bind 'focus:+transform-ghost( R={2} && echo -n "${R:0:12}" )'
)
test -z "${FZF_POS-}" ||
  FZF_ARGS+=( --bind "load:+pos($FZF_POS)+unbind(load)" )
jjfzf_status
export JJFZF_LOAD_LIST=jjfzf_log0_marked_revs
unset FZF_DEFAULT_OPTS FZF_DEFAULT_COMMAND
jjfzf_load --stdout |
  fzf +m "${FZF_ARGS[@]}" "${B[@]}" \
      --read0 '-d¸' --accept-nth=2 --with-nth '{1} {4..}'
