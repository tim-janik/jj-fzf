#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
die() { echo "${BASH_SOURCE[0]##*/}: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }
ABSPATHSCRIPT=$(readlink -f "${BASH_SOURCE[0]}")	# Resolve symlinks to find installdir

# == Setup & Options ==
source "${ABSPATHSCRIPT%/*}"/setup.sh	# preflight.sh
jjfzf_tempd				# assigns $JJFZF_TEMPD
echo 'DIFF=1'	> $JJFZF_TEMPD/evolog.env
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
TITLE='Evolution Log'
export JJFZF_EVOLOG_SRC=$(jj --no-pager --ignore-working-copy log --no-graph -T commit_id -r "${1-@}")
LONG_IDS="--config=template-aliases.'format_short_change_id(id)'='id.shortest(32)'"
FOOTER="$TITLE for Change ID:"$'\n'
FOOTER="$FOOTER"$(jj --no-pager --ignore-working-copy log --no-graph $LONG_IDS $JJFZF_COLOR -T 'format_short_change_id_with_hidden_and_divergent_info(self)' -r "${1-@}")
jjfzf_log_detailed	# for preview, assigns $JJFZF_LOG_DETAILED_CONFIG
B=() H=()

# == Bindings ==
RELOAD="reload-sync(cat $JJFZF_TEMPD/jjfzf_list)"	# see jjfzf_load

# Inject
H+=( 'Alt-J: Inject the selected commit as historic parent before the input revision.' )
B+=( --bind "alt-j:execute( jjfzf_evolog_inject {2} ; jjfzf_load_and_status )+$RELOAD+close+close+close" )
jjfzf_evolog_inject()
(
  set -Eeuo pipefail
  COMMIT="$1"
  WORKING_COPY=$(jj --no-pager --ignore-working-copy log --no-graph -r @ -T change_id) # FIXME: divergent?
  jjfzf_inject "$JJFZF_EVOLOG_SRC" "$COMMIT" && ERR=0 || ERR=$?
  jjfzf_run jj edit "$WORKING_COPY" || ERR=$?
  exit $ERR
)
export -f jjfzf_evolog_inject

# Enter
H+=( 'Enter: Show evolution of the change ID in the input revision up to the currently selected commit.' )
B+=( --bind 'enter:execute( jjfzf_evolog_info {2} | $JJFZF_PAGER )' )

# == Header Help ==
HEADER_HELP=$(printf "%s\n" "${H[@]}")
B+=( --header "$HEADER_HELP" )

# == jjfzf_evolog_info ==
# Show evolog info, diff and @ history
jjfzf_evolog_info()
(
  set -Eeuo pipefail #-x
  COMMITID="$1"
  jj --no-pager --ignore-working-copy $JJFZF_COLOR evolog -p -r "$COMMITID" |
    sed '3001q'
)
export -f jjfzf_evolog_info

# == jjfzf_evolog0 ==
# Show `jj evolog` with 0-termination and extractable commit id
jjfzf_evolog0()
(
  set -Eeuo pipefail
  JJEVOLOG="jj --no-pager --ignore-working-copy evolog -r $JJFZF_EVOLOG_SRC"
  TMPL=" '¸'++stringify(commit.commit_id().short(32))++'¸¸' ++ builtin_evolog_compact "
  $JJEVOLOG $JJFZF_COLOR -T "$TMPL" |
    sed '/¸¸/s/^/\x00/ ; 1s/^\x00//'
)
export -f jjfzf_evolog0

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
  --color=border:green,label:green
  --border-label "-[ ${TITLE^^} — JJ-FZF ]-"
  --preview-label " Evolution Info "
  --footer "${FOOTER}"
  --bind 'focus:+transform-ghost( R={2} && echo -n "${R:0:18}" )'
  --prompt 'EVOLOG > '
)
jjfzf_status
export JJFZF_LOAD_LIST=jjfzf_evolog0
unset FZF_DEFAULT_OPTS FZF_DEFAULT_COMMAND
jjfzf_load --stdout |
  fzf +m "${B[@]}" "${FZF_ARGS[@]}" \
      --read0 '-d¸' --accept-nth=2 --with-nth '{1} {4..}' \
      --preview 'jjfzf_evolog_info {2}'
