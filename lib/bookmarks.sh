#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
die() { echo "${BASH_SOURCE[0]##*/}: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }
ABSPATHSCRIPT=$(readlink -f "${BASH_SOURCE[0]}")	# Resolve symlinks to find installdir

# == Setup & Options ==
source "${ABSPATHSCRIPT%/*}"/setup.sh	# preflight.sh
jjfzf_tempd				# assigns $JJFZF_TEMPD
PRINTOUT=
echo 'MODE=V'	> $JJFZF_TEMPD/bookmarks.env
INPUT_REV=@
while test $# -ne 0 ; do
  case "$1" in \
    --help-bindings) PRINTOUT="$1" ;;
    -B|-m)	echo 'MODE=B' > $JJFZF_TEMPD/bookmarks.env ; FZF_ARGS+=( --disabled ) ;;
    -T)		echo 'MODE=T' > $JJFZF_TEMPD/bookmarks.env ; FZF_ARGS+=( --disabled ) ;;
    -D)		echo 'MODE=D' > $JJFZF_TEMPD/bookmarks.env ;;
    -O)		echo 'MODE=O' > $JJFZF_TEMPD/bookmarks.env ;;
    -V)		echo 'MODE=V' > $JJFZF_TEMPD/bookmarks.env ;;
    -x)		set -x ;;
    -*)		true ;;
    *)		INPUT_REV="$1" ;;
    *)		break ;;
  esac
  shift
done

# == Config ==
TITLE='Bookmarks & Tags'
jjfzf_log_detailed	# for preview, assigns $JJFZF_LOG_DETAILED_CONFIG
export JJFZFT="jj --no-pager --ignore-working-copy log --no-graph -T"
JJFZF_COMMITID=$($JJFZFT commit_id -r "$INPUT_REV") ||
  die "Unknown revision: $INPUT_REV"
export JJFZF_COMMITID
jjfzf_status		# snapshot dirty working tree
B=() H=()

# == Nearest Bookmark ==
rev_bookmarks()
{
  T='self.local_bookmarks()++"\n"'
  test "$1" == -t && { shift ; T="$T ++ ' ' ++ self.tags()" ; }
  $JJFZFT "$T" "$@" 2>/dev/null |
    tr ' ' '\n' | sed -r '/@/d; s/[*?].*//;' || :
}
# Identify input bookmark name or find first local bookmark in $INPUT_REV
NEAREST=( $(jj bookmark list -T 'name++"\n"' -- "$INPUT_REV" | sed -r '1q')
	  $(jj tag list -T 'name++"\n"' -- "$INPUT_REV" | sed -r '1q')
	  $(rev_bookmarks -t -r "$INPUT_REV")
	  $(rev_bookmarks -r "$INPUT_REV"-)
	  $(rev_bookmarks -r "$INPUT_REV"+)
	  $(rev_bookmarks -r .."$INPUT_REV") )

# == Bookmark & Tag List ==
jjfzf_format_refs() # width label
(
  while read MARK rest ; do
    MARK="${MARK%:}"
    printf "%-$1s $2 %s\n" "$MARK" "$rest"
  done
)
jjfzf_bookmark_list()
{
  true > $JJFZF_TEMPD/bm_refs.lst
  # bookmarks tracked @origin
  jj --no-pager --ignore-working-copy bookmark list --color=never -T 'name++"\n"' -t --remote origin |
    sort | uniq > $JJFZF_TEMPD/bm_origin.lst
  # local bookmarks
  jj --no-pager --ignore-working-copy bookmark list $JJFZF_COLOR -T 'name++"\n"' > $JJFZF_TEMPD/bm_local.lst
  # loop over local bookmarks to extend formatting
  while read MARK ; do
    jj --no-pager --ignore-working-copy bookmark list $JJFZF_COLOR "$MARK" > $JJFZF_TEMPD/bm_1.lst
    # sed reorders conflicted
    sed -r ':0; /^\s/!s/ \(conflicted\):/: (conflicted)/; N; $!b0; s/\n\s+/ /g' -i $JJFZF_TEMPD/bm_1.lst
    grep -qFx "$MARK" $JJFZF_TEMPD/bm_origin.lst &&
      LABEL="[Bookmark] (tracked)" || LABEL="[Bookmark]"
    jjfzf_format_refs 40 "$LABEL" < $JJFZF_TEMPD/bm_1.lst >> $JJFZF_TEMPD/bm_refs.lst
  done < $JJFZF_TEMPD/bm_local.lst
  # spacer
  echo				>> $JJFZF_TEMPD/bm_refs.lst
  # save spacer pos
  export JJFZF_REFS_START_POS=$(wc -l < $JJFZF_TEMPD/bm_refs.lst)
  # list tags
  jj --no-pager --ignore-working-copy tag list $JJFZF_COLOR > $JJFZF_TEMPD/bm_tags.lst
  # format, adds "[Tag]"
  jjfzf_format_refs 45 "[Tag]" < $JJFZF_TEMPD/bm_tags.lst	>> $JJFZF_TEMPD/bm_refs.lst
}
jjfzf_bookmark_list

# == Start Position ==
# Position at nearest bookmark
[[ ${#NEAREST[@]} -ge 1 ]] &&
  NEAREST_POS=$(sed -r 's/\x1b\[[0-9;]*[mK]//g' $JJFZF_TEMPD/bm_refs.lst |
		  grep -m 1 -n "\b${NEAREST[0]}\b" | cut -d: -f1) &&
  test -n "$NEAREST_POS" &&
  JJFZF_REFS_START_POS="$NEAREST_POS"
B+=( --bind "load:+pos($JJFZF_REFS_START_POS)" )

# == jjfzf_refs_transform ==
export JJFZF_BOOKMARK_AT=$(jjfzf_jjlog "$JJFZF_LOG_DETAILED_CONFIG" $JJFZF_COLOR --no-graph -T builtin_log_compact -r "$JJFZF_COMMITID" )
# Adjust prompt, etc according to mode
jjfzf_refs_transform()
(
  source $JJFZF_TEMPD/bookmarks.env	# MODE
  AT=$'\n \n '	# place holder for builtin_log_compact
  case "$MODE" in
    T)
      T='Create Tag'; I='Create new tag'; P='New Tag Name > '; AT=$' at:\n'"$JJFZF_BOOKMARK_AT"; G=""
      ;;
    B)
      T='Set Bookmark'; I='Move or create bookmark'; P='Bookmark Name > '; AT=$' at:\n'"$JJFZF_BOOKMARK_AT"
      [[ "$1" =~ \[Bookmark\] ]] && G="${1%% *}" || G=''
      ;;
    D)
      T='Delete Ref'; I='Delete bookmark or tag'; P='Delete Ref > '; G="${1%% *}";
      ;;
    O)
      T='Track @ Origin'; I='Track origin bookmark'; P='Bookmark to track > '
      [[ "$1" =~ \[Bookmark\] ]] && G="${1%% *}" || G=''
      ;;
    V|*)
      T='View Ref'; I='View details'; P='View Ref > '; G="${1%% *}";
      ;;
  esac
  echo -n "+refresh-preview"
  echo -n "+change-prompt($P)"
  echo -n "+change-ghost($G)"
  echo -n "+change-input-label( Enter: $I )"
  # echo -n "+change-footer-label( $T )"
  echo -n "+change-footer:${I}$AT"
)
export -f jjfzf_refs_transform
REFRESH='transform(jjfzf_refs_transform {})'
FZF_ARGS+=( --bind "start,focus,change:+$REFRESH" )

# == Bindings ==
H+=( 'Alt-B: Create new or move existing bookmark' )
B+=( --bind "alt-b,insert:clear-query+disable-search+search()+execute-silent( sed 's/^MODE=.*/MODE=B/' -i $JJFZF_TEMPD/bookmarks.env )+$REFRESH" )
H+=( 'Alt-T: Create new tag' )
B+=( --bind "alt-t:clear-query+disable-search+search()+execute-silent( sed 's/^MODE=.*/MODE=T/' -i $JJFZF_TEMPD/bookmarks.env )+$REFRESH" )
H+=( 'Alt-D: Delete bookmark or tag' )
B+=( --bind "alt-d,ctrl-delete:enable-search+search()+execute-silent( sed 's/^MODE=.*/MODE=D/' -i $JJFZF_TEMPD/bookmarks.env )+$REFRESH" )
H+=( 'Alt-O: Track bookmark @ origin' )
B+=( --bind "alt-o:enable-search+search()+execute-silent( sed 's/^MODE=.*/MODE=O/' -i $JJFZF_TEMPD/bookmarks.env )+$REFRESH" )
H+=( 'Alt-V: View details' )
B+=( --bind "alt-v:execute-silent( echo {q} > $JJFZF_TEMPD/refs_query )+enable-search+execute-silent( sed 's/^MODE=.*/MODE=V/' -i $JJFZF_TEMPD/bookmarks.env )+$REFRESH+transform-query( cat $JJFZF_TEMPD/refs_query )" )

# == Header Help ==
HEADER_HELP=$(printf "%s\n" "${H[@]}")
B+=( --header "$HEADER_HELP" )

# == jjfzf_refs_enter ==
# Handle create / delete / etc
jjfzf_refs_enter()
(
  set -Eeuo pipefail
  source $JJFZF_TEMPD/bookmarks.env	# MODE
  QUERY="$2" REF="${1%% *}"
  [[ "$1" =~ \[Tag\] ]] && ISTAG=true || ISTAG=false
  [[ "$1" =~ \[Bookmark\] ]] && ISBOOKMARK=true || ISBOOKMARK=false
  NEWNAME="$QUERY"
  case "$MODE" in
    T)
      test -z "$NEWNAME" -o -z "$JJFZF_COMMITID" || {
	jjfzf_run +n git tag "$NEWNAME" "$JJFZF_COMMITID"
	jjfzf_run +n jj --no-pager $JJFZF_KEEPCOMMITS status # import tag
      }
      ;;
    B)
      test -z "$NEWNAME" && [[ "$1" =~ \[Bookmark\] ]] && NEWNAME="$REF"
      test -z "$NEWNAME" -o -z "$JJFZF_COMMITID" || {
	jjfzf_run +n jj --no-pager bookmark set --allow-backwards -r "$JJFZF_COMMITID" -- "$NEWNAME"
      }
      ;;
    D)
      $ISBOOKMARK && {
	jjfzf_run +n jj --no-pager $JJFZF_KEEPCOMMITS bookmark delete "exact:$REF"
      }
      $ISTAG && {
	GIT_DIR=$(jj --no-pager --ignore-working-copy git root) ||
	  die "need Git to delete tag: $REF"
	export GIT_DIR
	jjfzf_run +n git tag -d "$REF"
	jjfzf_run +n jj --no-pager $JJFZF_KEEPCOMMITS status # import deletion
      }
      ;;
    O)
      if $ISBOOKMARK ; then
	ATORIGIN=$(jj --no-pager --ignore-working-copy bookmark list \
		      -T 'name++if(remote,"@"++remote)++"\n"' -a |
		     grep -xF "$REF@origin") || :
	if test -n "$ATORIGIN" ; then	# present @origin
	  TRACKED=$(jj --no-pager --ignore-working-copy bookmark list \
		       -T 'name++if(remote,"@"++remote)++"\n"' -t "$REF")
	  if test -z "$TRACKED" ; then
	    jjfzf_run +n jj --no-pager bookmark track -- "$REF"@origin
	  else
	    jjfzf_run +n jj --no-pager bookmark untrack -- "$REF"@origin
	  fi
	else	# needs push to be present @origin
	  jjfzf_run +n jj git push $JJFZF_COLOR --allow-new --remote origin --bookmark "$REF" --dry-run > $JJFZF_TEMPD/bpush.log 2>&1 \
	    && STATUS=0 || STATUS=$?
	  cat $JJFZF_TEMPD/bpush.log
	  if test $STATUS != 0 || grep -qEi 'nothing *changed|won.?t push|rejected *commit' $JJFZF_TEMPD/bpush.log ; then
	    read -p "Press Enter..."
	  else
	    read -p 'Proceed with bookmark push and submit changes? (y/N) ' YN
	    [[ "${YN:0:1}" =~ [yY] ]] &&
	      jjfzf_run +n jj git push $JJFZF_COLOR --allow-new --bookmark "$REF"
	  fi
	fi
      fi
      ;;
    V|*)
      test -z "$REF" ||
	(
	  jj --no-pager --ignore-working-copy tag list $JJFZF_COLOR -- "exact:$REF"
	  jj --no-pager --ignore-working-copy bookmark list $JJFZF_COLOR -- "exact:$REF"
	  echo
	  REVS="${REF+coalesce( tags(exact:$REF) , bookmarks(exact:$REF) )}"
	  jjfzf_jjlog "$JJFZF_LOG_DETAILED_CONFIG" $JJFZF_COLOR --no-graph -r "$REVS" -p \
		      -T 'concat( builtin_log_oneline , builtin_log_detailed , diff.stat() , "\n" )'
	) | $JJFZF_PAGER
      ;;
  esac
)
export -f jjfzf_refs_enter
B+=( --bind "enter:execute( jjfzf_refs_enter {} {q} )+transform: source $JJFZF_TEMPD/bookmarks.env && [[ \$MODE != V ]] && echo 'close+close'" )

# == Preview ==
# Show commit(s) with diff and full info
jjfzf_ref_info()
(
  set -Eeuo pipefail
  jjfzf_jjlog "$JJFZF_LOG_DETAILED_CONFIG" $JJFZF_COLOR --no-graph -r "$1" -p \
	      -T 'concat( builtin_log_oneline , builtin_log_detailed , diff.stat() , "\n" )'
)
export -f jjfzf_ref_info
B+=( --preview ' L={} && test -n "$L" && jjfzf_ref_info "${L%% *}" ' )
B+=( --preview-label " Ref Info " )

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
  --color=border:red,label:red
  --border-label "-[ ${TITLE^^} — JJ-FZF ]-"
)
unset FZF_DEFAULT_OPTS FZF_DEFAULT_COMMAND
fzf -m "${FZF_ARGS[@]}" "${B[@]}" \
    < $JJFZF_TEMPD/bm_refs.lst
