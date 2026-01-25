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
jjfzf_status		# snapshot dirty working tree

# == Config ==
TITLE='Bookmarks & Tags'
jjfzf_log_detailed	# for preview, assigns $JJFZF_LOG_DETAILED_CONFIG
JJFZF_COMMITID=$(jj --no-pager --ignore-working-copy log --no-graph -T commit_id -r "$INPUT_REV") ||
  die "Unknown revision: $INPUT_REV"
export JJFZF_COMMITID
B=() H=()

# == Aliases ==
# Bookmarks are managed locally, @git, @origin and possibly other remotes.
# There are varying states, depending on whether a bookmark is tracked,
# new/delete is unpushed, or @remote disagrees with a moved @git after
# fetch (conflicted).
# For the UI, we try to map the states of a bookmark name onto 1 dimension,
# by defining a hierarchy of states for local bookmark names where more
# important / dominant states shadow others.
# In addition we list remote bookmarks that have no local name.
#
# Possible states:
# [Pending]	(local, tracked, to be pushed to @origin)
# [Deleted]	(but still tracked @origin)
# [Conflicted]	(local, tracked, undecided @git != @origin)
# [Tracked]	(local and @origin)
# [Untracked]	(exists locally and possibly-different @origin)
# [Local]	(not @origin)
# [Remote]	(only @origin, not local, untracked)
cat > $JJFZF_TEMPD/bm.toml <<\__EOF
[template-aliases]
# Hierarchical state categories (1D) for a bookmark name
'bookmark_state1d(untracked)'='''
if(tracked && !present, "Pending",
  if(!present, "Deleted",
    if(conflict, "Conflicted",
      if(tracked && remote && remote != "git", "Tracked",
	if(!tracked && !remote, "Local",
	  if(!tracked && remote != "git", untracked,
	    "OTHER_REMOTE"
	  )
	)
      )
    )
  )
)'''
# Format local bookmark with 1D state
bookmark_local1d='''
bookmark_state1d("Untracked") ++ '¸'
++ name ++ '¸' ++ if(remote,"@"++remote) ++ '¸'
++ pad_end(32, label("bookmark", name), " ") ++ " "
++ pad_end(13,
	       label(if(conflict || (!present && !tracked), "conflict"),
			"[" ++ bookmark_state1d("Untracked") ++ "]") )
++ if(present && !conflict,
     format_commit_summary_with_refs(self.normal_target(), "") )
++ "\n"
'''
# Format @remote bookmark with 1D state
bookmark_remote1d='''
if(present && !tracked && remote && remote != "git",
  bookmark_state1d("Remote") ++ '¸'
  ++ name ++ if(remote,"@"++remote) ++ '¸' ++ if(remote,"@"++remote) ++ '¸'
  ++ pad_end(32, label("bookmark", name ++ '@' ++ remote), " ") ++ " "
  ++ pad_end(13, "[" ++ bookmark_state1d("Remote") ++ "]", " ")
  ++ if(present && !conflict,
       format_commit_summary_with_refs(self.normal_target(), "") )
) ++ "\n"
'''
# Format tags
tag_local1d = '''
"Tag¸"
++ name ++ '¸@git¸'
++ pad_end(32, label("tag", name), " ") ++ " "
++ pad_end(13, "[" ++ "Tag" ++ "]", " ")
++ format_commit_summary_with_refs(self.normal_target(), "") ++ "\n"
'''
__EOF

# == jjfzf_b_l ==
# jj bookmark list
jjfzf_b_l()
(
  ERR=0
  [[ " $* " =~ --color ]] && COLOR='' || COLOR="$JJFZF_COLOR"
  jj --no-pager --ignore-working-copy --config-file=$JJFZF_TEMPD/bm.toml \
     bookmark list $COLOR "$@" 2>$JJFZF_TEMPD/err || ERR=$?
  grep -Fv 'Hint:' $JJFZF_TEMPD/err >&2 || :
  exit $ERR
)
export -f jjfzf_b_l

# == Nearest Bookmark ==
rev_bookmarks()
{
  T='self.local_bookmarks()++"\n"'
  test "$1" == -t && { shift ; T="$T ++ ' ' ++ self.tags()" ; }
  jj --no-pager --ignore-working-copy log --no-graph -T "$T" "$@" 2>/dev/null |
    tr ' ' '\n' | sed -r '/@/d; s/[*?].*//;' || :
}
# Identify input bookmark name or find first local bookmark in $INPUT_REV
P=()	# PIDs to run jj queries in parellel
(jjfzf_b_l --color=never -T 'name++"\n"' -- "exact:'$INPUT_REV'" 2>$JJFZF_TEMPD/err0 |
   sed -r '1q'
 grep -v '^Warning: ' $JJFZF_TEMPD/err0 >&2 || true	# ignore non-matching names
)						> $JJFZF_TEMPD/res0 & P+=($!)
(jj tag list -T 'name++"\n"' -- "exact:'$INPUT_REV'" 2>$JJFZF_TEMPD/err1 |
   sed -r '1q'
 grep -v '^Warning: ' $JJFZF_TEMPD/err1 >&2 || true	# ignore non-matching names
)						> $JJFZF_TEMPD/res1 & P+=($!)
(rev_bookmarks -t -r "$INPUT_REV")		> $JJFZF_TEMPD/res2 & P+=($!)
(rev_bookmarks -r "$INPUT_REV"-)		> $JJFZF_TEMPD/res3 & P+=($!)
(rev_bookmarks -r "$INPUT_REV"+)		> $JJFZF_TEMPD/res4 & P+=($!)
(rev_bookmarks -r .."$INPUT_REV")		> $JJFZF_TEMPD/res5 & P+=($!)
NEAREST=()
for i in "${!P[@]}"; do
  wait "${P[i]}" || exit $?
  NEAREST+=( $(cat $JJFZF_TEMPD/res$i) )
  rm -f $JJFZF_TEMPD/res$i
done

# == jjfzf_bookmark_list0 ==
jjfzf_bookmark_list0()
(
  # Keep things simple and only consider remote bookmarks @origin.
  set -Eeuo pipefail
  # Run jj commands in parallel to speed up listings
  jjfzf_b_l -a -T 'if(!remote, name) ++ "\n"' > $JJFZF_TEMPD/bm_lnames & P_lnames=$!
  jjfzf_b_l -a -T 'if(!remote || remote == "origin", bookmark_local1d )'  > $JJFZF_TEMPD/bm_local1d & P_local1d=$!
  jjfzf_b_l --remote origin -T 'if(!tracked && remote == "origin", name) ++ "\n"' > $JJFZF_TEMPD/bm_onames & P_onames=$!
  jjfzf_b_l --remote origin -T 'if(!tracked && remote == "origin", bookmark_remote1d )'  > $JJFZF_TEMPD/bm_origin1d & P_origin1d=$!
  jj --no-pager --ignore-working-copy --config-file=$JJFZF_TEMPD/bm.toml \
     tag list $JJFZF_COLOR -T tag_local1d > $JJFZF_TEMPD/bm_tags.lst & P_tags=$!
  # Truely local bookmark names
  wait "$P_lnames" || exit $?
  LOCAL_BOOKMARKS=( $(cat $JJFZF_TEMPD/bm_lnames) )
  wait "$P_local1d" || exit $?
  for B in "${LOCAL_BOOKMARKS[@]}" ; do
    for S in "Pending" "Deleted" "Conflicted" "Tracked" "Untracked" "Local" ; do # "UNKNOWN"
      grep -m1 "^$S¸$B¸" $JJFZF_TEMPD/bm_local1d && break
    done
  done		>  $JJFZF_TEMPD/bm_refs.lst
  # Bookmarks untracked @origin
  wait "$P_onames" || exit $?
  ORIGIN_BOOKMARKS=( $(cat $JJFZF_TEMPD/bm_onames) )
  wait "$P_origin1d" || exit $?
  for B in "${ORIGIN_BOOKMARKS[@]}" ; do
    jjfzf_contained "$B" "${LOCAL_BOOKMARKS[@]}" && continue
    S=Remote
    grep -m1 "^$S¸$B@[^¸]*¸" $JJFZF_TEMPD/bm_origin1d && break
  done		>> $JJFZF_TEMPD/bm_refs.lst
  # Add spacer and save spacer position
  echo '¸¸¸'	>> $JJFZF_TEMPD/bm_refs.lst
  wc -l < $JJFZF_TEMPD/bm_refs.lst > $JJFZF_TEMPD/bm_start_pos
  # list tags
  wait "$P_tags" || exit $?
  cat $JJFZF_TEMPD/bm_tags.lst >> $JJFZF_TEMPD/bm_refs.lst
  # 0-termination
  sed '/¸.*¸/s/^/\x00/ ; 1s/^\x00//' < $JJFZF_TEMPD/bm_refs.lst > $JJFZF_TEMPD/bm_refs0.lst
)
export -f jjfzf_bookmark_list0
jjfzf_bookmark_list0	# setup $JJFZF_TEMPD/bm_start_pos

# == Start Position ==
# Position at nearest bookmark
JJFZF_REFS_START_POS="$(cat "$JJFZF_TEMPD/bm_start_pos")"
[[ ${#NEAREST[@]} -ge 1 ]] &&
  NEAREST_POS=$(sed -r 's/\x1b\[[0-9;]*[mK]//g' $JJFZF_TEMPD/bm_refs.lst |
		  grep -m 1 -n "\b${NEAREST[0]}\b" | cut -d: -f1) &&
  test -n "$NEAREST_POS" &&
  JJFZF_REFS_START_POS="$NEAREST_POS"
B+=( --bind "load:+pos($JJFZF_REFS_START_POS)" )

# == jjfzf_refs_transform ==
export JJFZF_BOOKMARK_AT=$(jjfzf_jjlog $JJFZF_COLOR --no-graph -T builtin_log_compact -r "$JJFZF_COMMITID" )
# Adjust prompt, etc according to mode
jjfzf_refs_transform()
(
  source $JJFZF_TEMPD/bookmarks.env	# MODE
  [[ "${2-}" == "Tag" ]] && ISTAG=true || ISTAG=false
  AT=$'\n \n '	# place holder for builtin_log_compact
  case "$MODE" in
    T)
      T='Create Tag'; I='Create new tag'; P='New Tag Name > '; AT=$' at:\n'"$JJFZF_BOOKMARK_AT"; G=""
      ;;
    B)
      T='Set Bookmark'; I='Move or create bookmark'; P='Bookmark Name > '; AT=$' at:\n'"$JJFZF_BOOKMARK_AT"
      $ISTAG && G='' || G="${1%% *}"
      ;;
    D)
      T='Delete Ref'; I='Delete bookmark or tag'; P='Delete Ref > '; G="${1%% *}";
      ;;
    O)
      T='Track @ Origin'; I='Track origin bookmark'; P='Bookmark to track > '
      $ISTAG && G='' || G="${1%% *}"
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
REFRESH='transform(jjfzf_refs_transform {2} {1})'
FZF_ARGS+=( --bind "start,focus,change:+$REFRESH" )

# == Bindings ==
H+=( 'Alt-B: Create new or move existing bookmark' )
B+=( --bind "alt-b,insert:clear-query+disable-search+search()+execute-silent( sed 's/^MODE=.*/MODE=B/' -i $JJFZF_TEMPD/bookmarks.env )+$REFRESH" )
H+=( 'Alt-T: Create new tag' )
B+=( --bind "alt-t:clear-query+disable-search+search()+execute-silent( sed 's/^MODE=.*/MODE=T/' -i $JJFZF_TEMPD/bookmarks.env )+$REFRESH" )
H+=( 'Alt-D: Delete bookmark or tag' )
B+=( --bind "alt-d,ctrl-delete:enable-search+search()+execute-silent( sed 's/^MODE=.*/MODE=D/' -i $JJFZF_TEMPD/bookmarks.env )+$REFRESH" )
H+=( 'Alt-O: Toggle tracking of bookmark @ origin' )
B+=( --bind "alt-o:enable-search+search()+execute-silent( sed 's/^MODE=.*/MODE=O/' -i $JJFZF_TEMPD/bookmarks.env )+$REFRESH" )
H+=( 'Alt-V: View details' )
B+=( --bind "alt-v:execute-silent( echo {q} > $JJFZF_TEMPD/refs_query )+enable-search+execute-silent( sed 's/^MODE=.*/MODE=V/' -i $JJFZF_TEMPD/bookmarks.env )+$REFRESH+transform-query( cat $JJFZF_TEMPD/refs_query )" )

# == Header Help ==
HEADER_HELP=$(printf "%s\n" "${H[@]}" | jjfzf_bold_keys)
B+=( --header "$HEADER_HELP" )

# == jjfzf_refs_enter ==
# Handle create / delete / etc
jjfzf_refs_enter()
(
  set -Eeuo pipefail
  source $JJFZF_TEMPD/bookmarks.env	# MODE
  QUERY="$2" REF="${1%% *}"
  STATE1D="${3-}"
  [[ "$STATE1D" == "Tag" ]] && ISTAG=true || ISTAG=false
  NEWNAME="$QUERY"
  case "$MODE" in
    T)
      test -z "$NEWNAME" -o -z "$JJFZF_COMMITID" || {
	jjfzf_run +n jj --no-pager tag set --allow-move -r "$JJFZF_COMMITID" "$NEWNAME"
	jjfzf_run +n jj --no-pager $JJFZF_KEEPCOMMITS status # import tag
      }
      ;;
    B)
      test -z "$NEWNAME" -a $ISTAG == false && NEWNAME="$REF"
      test -z "$NEWNAME" -o -z "$JJFZF_COMMITID" || {
	jjfzf_run +n jj --no-pager bookmark set --allow-backwards -r "$JJFZF_COMMITID" -- "$NEWNAME"
      }
      ;;
    D)
      if [[ "$STATE1D" == "Tag" ]] ; then
	jjfzf_run +n jj --no-pager $JJFZF_KEEPCOMMITS tag delete "$REF"
      else
	jjfzf_run +n jj --no-pager $JJFZF_KEEPCOMMITS bookmark delete "exact:$REF"
      fi
      ;;
    O)
      if [[ "$STATE1D" == "Remote" ]] ; then
	jjfzf_run +n jj --no-pager bookmark track -- "$REF"
      elif [[ "$STATE1D" == "Pending" ]] ; then
	jjfzf_run +n jj --no-pager bookmark untrack -- "$REF"@origin
      elif [[ "$STATE1D" == "Tracked" ]] ; then
	jjfzf_run +n jj --no-pager bookmark untrack -- "$REF"@origin
      elif [[ "$STATE1D" == "Untracked" ]] ; then
	jjfzf_run +n jj --no-pager bookmark track -- "$REF"@origin
      elif [[ "$STATE1D" == "Local" ]] ; then
	jjfzf_run +n jj --no-pager bookmark track -- "$REF"@origin
      fi
      ;;
    V|*)
      test -z "$REF" ||
	(
	  jj --no-pager --ignore-working-copy tag list $JJFZF_COLOR -- "exact:$REF"
	  jj --no-pager --ignore-working-copy bookmark list $JJFZF_COLOR -- "exact:$REF"
	  echo
	  REVS="${REF+coalesce( tags(exact:'$REF') , bookmarks(exact:'$REF'), $REF )}"
	  jjfzf_jjlog "$JJFZF_LOG_DETAILED_CONFIG" $JJFZF_COLOR --no-graph -r "$REVS" -p \
		      -T 'concat( builtin_log_oneline , builtin_log_detailed , diff.stat() , "\n" )'
	) |& $JJFZF_PAGER
      ;;
  esac
)
export -f jjfzf_refs_enter
B+=( --bind "enter:execute( jjfzf_refs_enter {2} {q} {1} )+transform: source $JJFZF_TEMPD/bookmarks.env && [[ \$MODE != V ]] && echo 'close+close'" )

# == Preview ==
# Show commit(s) with diff and full info
jjfzf_ref_info()
(
  set -Eeuo pipefail
  jjfzf_jjlog "$JJFZF_LOG_DETAILED_CONFIG" $JJFZF_COLOR --no-graph -r "$1" -p \
	      -T 'concat( builtin_log_oneline , builtin_log_detailed , diff.stat() , "\n" )'
)
export -f jjfzf_ref_info
B+=( --preview ' L={4} && test -n "$L" && jjfzf_ref_info "${L%% *}" ' )
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
export JJFZF_LOAD_LIST=jjfzf_bookmark_list0
fzf -m "${FZF_ARGS[@]}" "${B[@]}" \
    --read0 '-d¸' --accept-nth=2 --with-nth '{4..}' \
    < $JJFZF_TEMPD/bm_refs0.lst
