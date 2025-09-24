#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x

# Avoid interference with use of `cd`
unset CDPATH

# $JJFZF_ABSPATHLIB points to jj-fzf/lib
[[ "${BASH_SOURCE[0]}" = "${BASH_SOURCE[0]#/}" ]] &&
  JJFZF_ABSPATHLIB="$PWD/${BASH_SOURCE[0]}" || JJFZF_ABSPATHLIB="${BASH_SOURCE[0]}"
export JJFZF_ABSPATHLIB="${JJFZF_ABSPATHLIB%/*}"

# Check for dependencies, define sed(), etc
source "$JJFZF_ABSPATHLIB"/../preflight.sh

# Common definitions also used by preview.sh
source "$JJFZF_ABSPATHLIB"/common.sh

# Bash function exports needs sub-shell to be bash too
export JJFZF_ORIGPWD="$PWD"	# save original PWD for interactive subshells
export JJFZF_ORIGSHELL="${JJFZF_ORIGSHELL-$SHELL}"	# save original $SHELL
export SHELL=bash

# Pager config
command -v less >/dev/null && JJFZF_PAGER="less -Rc" || JJFZF_PAGER="more"
export JJFZF_PAGER

# JJ compatible --collor=-... arg
test -z "${NO_COLOR-}" && JJFZF_COLOR=--color=always || JJFZF_COLOR=--color=never
export JJFZF_COLOR
# abandon-unreachable=true can be dangerous: https://github.com/jj-vcs/jj/discussions/7248#discussioncomment-14135120
export JJFZF_KEEPCOMMITS=--config=git.abandon-unreachable-commits=false

# == JJFZF_TEMPD ==
# Ensure temporary directory
jjfzf_tempd()
{
  test -n "${JJFZF_TEMPD-}" || {
    JJFZF_TEMPD=$(mktemp --tmpdir -d jjfzf.XXXXXX) &&
      trap "rm -rf '$JJFZF_TEMPD'" 0 ||
	{ echo "$0: mktemp failed" >&2 ; exit 1 ; }
    export JJFZF_TEMPD
  }
}

# == jjfzf_wrap_args ==
# Fold arguments at wrap width
jjfzf_wrap_args()
(
  WRAP_WIDTH="$1" && shift	# first argument = max line width
  LINE=""
  for ARG in "$@"; do
    # if adding ARG exceeds WRAP_WIDTH, start a new one
    if (( ${#LINE} + ${#ARG} + (${#LINE} > 0 ? 1 : 0) > WRAP_WIDTH )); then
      printf '%s\n' "$LINE"
      LINE="$ARG"
    else
      LINE="$LINE${LINE:+ }$ARG"
    fi
  done
  test -n "$LINE" &&
    printf '%s\n' "$LINE"
)
export -f jjfzf_wrap_args

# == jjfzf_config ==
# Handle jj config without errors
jjfzf_config()
(
  set -Eeuo pipefail
  JJ="jj --no-pager --ignore-working-copy"
  case "$1" in
    get)	$JJ config get "$2" 2>/dev/null || : ;;
    set)	$JJ config set --repo "$2" "$3" ;;
    toggle)
      T="$($JJ config get "$2" 2>/dev/null || :)"
      test "$T" == 0 -o "$T" == false && T=true || T=false
      $JJ config set --repo "$2" "$T"
      ;;
  esac
  exit 0
)
export -f jjfzf_config

# == jjfzf_config_quote ==
# Add quotes and escapes to a stream to be usable as toml config value
jjfzf_config_quote() # [prefix] [postfix]
(
  echo -n "''' \"${1-}"
  sed -r 's/([\\"])/\\\1/g;'"s/'/\\\\x27/g"
  echo -n "${2-}\" '''"
)
export -f jjfzf_config_quote

# == jjfzf_status ==
# Snapshot and show jj status if it changed
jjfzf_status()
(
  CID=$(jj --no-pager --ignore-working-copy log --no-graph -r @ -T commit_id)
  ( set -x
    jj --no-pager status $JJFZF_COLOR
  ) > $JJFZF_TEMPD/status 2>&1
  test $(jj --no-pager --ignore-working-copy log --no-graph -r @ -T commit_id) == "$CID" ||
    cat $JJFZF_TEMPD/status >&2
  rm -f $JJFZF_TEMPD/status
)
export -f jjfzf_status

# == jjfzf_revset ==
# Determine jj log revset, supports reading $JJFZF_REVSET_OVERRIDE
jjfzf_revset()
(
  set -Eeuo pipefail
  JJ="jj --no-pager --ignore-working-copy"
  test -n "${JJFZF_REVSET_OVERRIDE-}" && REVSET=$(cat "$JJFZF_REVSET_OVERRIDE" 2>/dev/null) || REVSET=
  test -n "$REVSET" || REVSET=$($JJ config get jj-fzf.log_revset 2>/dev/null) || :
  test -n "$REVSET" || REVSET=$($JJ config get revsets.log 2>/dev/null) || :
  test -n "$REVSET" || REVSET=::
  echo "$REVSET"
)
export -f jjfzf_revset
export JJFZF_REVSET_OVERRIDE=	# has to be changed *after* `source setup.sh`

# == jjfzf_log_detailed ==
# Extend builtin_log_detailed
# TODO: It'd be nice if JJ had a builtin_log_detailed + Parents + PRIVATE marker
jjfzf_log_detailed()
{
  local STAR='""++'
  test -n "$JJFZF_PRIVATE" &&	# see also JJFZF_PRIVATE_CONFIG
    STAR=" if(self.contained_in(\"$JJFZF_PRIVATE\") \&\& !immutable, label(\"committer\", \"🌟\")++\" \") ++ "
  local PARENTS=' "Parents  :" ++ commit.parents().map(|c| " " ++ c.change_id()) ++ "\n" '
  JJFZF_LOG_DETAILED_CONFIG="$(
	jjfzf_config get "template-aliases.'builtin_log_detailed(commit)'" |
	  sed -r -e 's/(\bcommit\.change_id\(\)\s*\++\s*"\\n"),/\1,'"$PARENTS"',/' \
	         -e 's/(\bif\(commit\.description\()/'"$STAR"'\1/'
	)"
  export JJFZF_LOG_DETAILED_CONFIG=--config="template-aliases.'builtin_log_detailed(commit)'=''' $JJFZF_LOG_DETAILED_CONFIG '''"
}

# == jjfzf_jjlog ==
# Just run a non-snapshotting jj log
jjfzf_jjlog()
(
  ARGS=(--ignore-working-copy --no-pager)
  # avoid underlines hiding +- diff chars
  ARGS+=( '--config=colors."diff token"={underline=false}' )
  test -n "$JJFZF_PRIVATE_CONFIG" && ARGS+=( "$JJFZF_PRIVATE_CONFIG" )
  jj "${ARGS[@]}" log "$@"
)
export -f jjfzf_jjlog

# == jjfzf_log0 ==
# Write current log with 0-separation
jjfzf_log0()
(
  set -Eeuo pipefail
  JJ="jj --no-pager --ignore-working-copy"
  REVSET="$(jjfzf_revset)"
  TMPL=$($JJ config get jj-fzf.log_template 2>/dev/null) ||
    TMPL=$($JJ config get templates.log 2>/dev/null) ||
    TMPL=builtin_log_oneline
  jjfzf_jjlog $JJFZF_COLOR -r "$REVSET" \
      -T " '¸'++stringify(if(self.divergent(),commit_id,change_id))++'¸¸' ++ $TMPL " 2>&1 |
    sed '/¸¸/s/^/\x00/ ; 1s/^\x00//'
)
export -f jjfzf_log0

# == jjfzf_load ==
# Wrapper to write log or oplog or evolog to $JJFZF_TEMPD/jjfzf_list, also supports --stdout
jjfzf_load()
(
  set -Eeuo pipefail
  if test "${1-}" != "--stdout" ; then
    $JJFZF_LOAD_LIST > $JJFZF_TEMPD/jjfzf_list 2>&1
  else
    $JJFZF_LOAD_LIST 2>&1 |
      tee $JJFZF_TEMPD/jjfzf_list
  fi
)
export -f jjfzf_load

# == jjfzf_load_and_status ==
# Ensure JJ snapshot before jjfzf_load
jjfzf_load_and_status()
{
  jjfzf_status || :
  jjfzf_load
}
export -f jjfzf_load_and_status

# == jjfzf_run ==
# Run JJ command, show command and error message, update $JJFZF_TEMPD/jjfzf_list
jjfzf_run()
(
  set -Eeuo pipefail
  IGNORE=false NOLOAD=false
  while test $# -ne 0 ; do
    case "$1" in \
      +e)	IGNORE=true ;;
      +n)	NOLOAD=true ;;
      +*)	true ;; # skip
      *)	break ;;
    esac
    shift
  done
  ERR=0
  if test -n "${1-}" ; then
    ( set -x; "$@" ) || {
      ERR=$?
      echo "jj-fzf: command exit_status=$ERR" >&2
      $IGNORE ||
	read -t 1 || :
      $IGNORE && ERR=0
    }
  fi
  $NOLOAD || jjfzf_load_and_status
  exit $ERR
)
export -f jjfzf_run

# == jjfzf_oneline ==
jjfzf_oneline_graph()
(
  jjfzf_jjlog $JJFZF_COLOR -T builtin_log_oneline "$@"
)
export -f jjfzf_oneline_graph

# == jjfzf_oneline ==
jjfzf_oneline()
(
  jjfzf_jjlog $JJFZF_COLOR --no-graph -T builtin_log_oneline "$@"
)
export -f jjfzf_oneline

# == jjfzf_ccrevs ==
# Concat arguments into a single OR-ed revset
jjfzf_ccrevs()
(
  set -Eeuo pipefail
  REVS=( "$@" )
  IFS='|'
  echo "${REVS[*]}"
)
export -f jjfzf_ccrevs

# == jjfzf_list_commit_ids ==
# Produce newline-separated commit_id list from revset
jjfzf_list_commit_ids()
(
  CIDTMPL='commit_id ++ "\n"'
  # forward chronological needs --reversed
  jj --no-pager --ignore-working-copy log --color=never --no-graph -T "$CIDTMPL" -r "$(jjfzf_ccrevs "$@")"
)
export -f jjfzf_list_commit_ids

# == jjfzf_list_change_ids ==
# Produce newline-separated change_id list (or commit_id if divergent) from revset
jjfzf_list_change_ids()
(
  CIDTMPL='if(self.divergent(),commit_id,change_id) ++ "\n"'
  jj --no-pager --ignore-working-copy log --color=never --no-graph -T "$CIDTMPL" -r "$(jjfzf_ccrevs "$@")"
)
export -f jjfzf_list_change_ids

# == jjfzf_chronological_change_ids ==
# Produce newline-separated change_id list (or commit_id if divergent) in forward chronological order
jjfzf_chronological_change_ids()
(
  CIDTMPL='if(self.divergent(),commit_id,change_id) ++ "\n"'
  # forward chronological needs --reversed
  jj --no-pager --ignore-working-copy log --color=never --no-graph -T "$CIDTMPL" --reversed -r "$(jjfzf_ccrevs "$@")"
)
export -f jjfzf_chronological_change_ids

# == jjfzf_inject ==
# Inject revisions as historic commits before @
jjfzf_inject()
(
  set -Eeuo pipefail
  REV="$1" && shift
  for ((i=$#; i>0; i--)); do
    C="${!i}"
    AUTHOR="$($JJFZFT 'self.author().name()' -r "$C")"
    EMAIL="$($JJFZFT 'self.author().email()' -r "$C")"
    TIMESTAMP="$($JJFZFT 'self.author().timestamp()' -r "$C")"
    DESCRIPTION="$($JJFZFT 'self.description()' -r "$C")"
    ARGS=(
      --config "user.name=\"$AUTHOR\""
      --config "user.email=\"$EMAIL\""
      --message="$DESCRIPTION"
    )
    export JJ_TIMESTAMP="$(date --rfc-3339=ns -d "$TIMESTAMP")"
    if [[ "$REV" == @ ]] ; then
      jjfzf_run +n jj --no-pager new --no-edit --insert-before @ "${ARGS[@]}"
      jjfzf_run +n jj --no-pager restore --restore-descendants --from "$C" --to @-
    fi
  done # TODO: JJ ideally would support metadata copies for jj restore --restore-descendants
)
export -f jjfzf_inject

# == jjfzf_exec_usershell ==
# Exec $USERSHELL
jjfzf_exec_usershell()
{
  set -Eeuo pipefail
  USERSHELL="$JJFZF_ORIGSHELL"
  T=$(tty 2>/dev/null || tty <&1 2>/dev/null || tty <&2 2>/dev/null) || :
  if test -n "$T" ; then
    echo -e "\n#\n# Type \"exit\" to leave subshell\n#"
    for func in $(compgen -A function); do
      unset -f "$func"
    done	# remove all exported functions
    unset CDPATH
    test -d "$JJFZF_ORIGPWD" && cd "$JJFZF_ORIGPWD" || :
    for var in $(compgen -v); do
      [[ "$var" =~ ^JJFZF ]] &&
	unset "$var"
    done	# remove all exported variables
    # Use 'exec' to avoid an unwanted intermediate parent process, see: pstree -ps $$
    exec /usr/bin/env "$USERSHELL" <$T 1>$T 2>$T
  fi
}
export -f jjfzf_exec_usershell

# == fzf ==
FZF_ARGS=(
  --ansi
  --track
  --no-tac
  --no-sort
  --extended
  --exact
  # --no-mouse
  --style default
  --border
  --input-border=line
  --header-border=line
  --preview-border=left
  --info default
  --layout reverse-list
  --scrollbar '▍'	# '▌'
  --scroll-off 2
  --highlight-line
  --preview-label-pos 2
  --input-label-pos 2
  --list-label-pos 2
  --footer-label-pos 2
  --header-first
  --header-label-pos 2
  --list-label ' JJ-LOG '
  --bind 'page-down:half-page-down'
  --bind 'page-up:half-page-up'
  --bind "scroll-down:offset-up"
  --bind "scroll-up:offset-down"
  --bind "alt-up:preview-up"
  --bind "alt-down:preview-down"
  --bind "alt-<:first"
  --bind "alt->:last"
  --bind 'ctrl-u:deselect-all+clear-query'
  --bind "ctrl-alt-w:toggle-wrap+toggle-preview-wrap"
  --bind "ctrl-x:jump"
  --bind "ctrl-z:execute( jjfzf_exec_usershell )+refresh-preview"
  --bind='f11:change-preview-window(bottom,50%,border-horizontal|hidden|)'
  --preview-window 'right,border-left'
  --info-command='echo -e " \x1b[33;1m$FZF_POS\x1b[m/$FZF_INFO "'
)
# Ctrl-U : Clear query or selection
