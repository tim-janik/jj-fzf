#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
ABSPATHSCRIPT=$(readlink -f "$0")	# Resolve symlinks to find installdir

# == Imports ==
# Import jj_show_diff and helpers
source "${BASH_SOURCE[0]%/*}"/common.sh

# == Preview Rendering ==
# Pattern to match revisions
REVPAT='^[^a-z()0-9]*([k-xyz]{7,})([?]*)\ '	# line start, ignore --graph, parse revision letters, catch '??'-postfix
# Pattern to match operation ids
OPRPAT='^[^a-z0-9]*([0-9a-f]{9,})[?]*\ '	# line start, ignore --graph, parse hex letters, space separator
case "${1-}" in
  preview_revision)
    # Render preview if revision is found
    if [[ " $2 " =~ $REVPAT ]] ; then			# match beginning of jj log line
      REVISION="${BASH_REMATCH[1]}"
      if [[ "${BASH_REMATCH[2]}" == '??' ]] ; then		# divergent change_id
	# https://martinvonz.github.io/jj/latest/FAQ/#how-do-i-deal-with-divergent-changes-after-the-change-id
	jj --no-pager --ignore-working-copy show -T builtin_log_oneline -r "${BASH_REMATCH[1]}" 2>&1 || :
	echo
	REVISION=$(echo " $2 " | grep -Po '(?<= )[a-f0-9]{8,}(?= )') || exit 0	# find likely commit id
      fi
      { jj --no-pager --ignore-working-copy log --color=always --no-graph -T "$JJ_FZF_SHOWDETAILS" -s -r "$REVISION"
	jj_show_diff --color=always -T '"\n"' -r "$REVISION"
      } 2>&1 | head -n 3000
    fi							# else no valid revision
    ;;
  preview_oplog)
    [[ " $2 " =~ $OPRPAT ]] && {
      jj --no-pager --ignore-working-copy --at-op "${BASH_REMATCH[1]}" --color=always op log --no-graph -n 1 -T builtin_op_log_comfortable
      jj --no-pager --ignore-working-copy --at-op "${BASH_REMATCH[1]}" --color=always log -s -r .. # -T builtin_log_oneline
    }
    ;;
  preview_opshow)
    [[ " $2 " =~ $OPRPAT ]] && {
      jj --no-pager --ignore-working-copy --at-op "${BASH_REMATCH[1]}" --color=always op log --no-graph -n 1 -T builtin_op_log_comfortable
      jj --no-pager --ignore-working-copy --at-op "${BASH_REMATCH[1]}" --color=always log --no-graph -s -r "@"
      jj --no-pager --ignore-working-copy --at-op "${BASH_REMATCH[1]}" --color=always show -T ' "\n" ' -r "@"
    }
    ;;
  preview_oppatch)
    [[ " $2 " =~ $OPRPAT ]] && {
      jj --no-pager --ignore-working-copy --color=always op show -p "${BASH_REMATCH[1]}"
    } | head -n 3000
    ;;
  preview_opdiff)
    [[ " $2 " =~ $OPRPAT ]] && {
      jj --no-pager --ignore-working-copy --color=always op diff -f "${BASH_REMATCH[1]}" -t @
    }
    ;;
  preview_evolog)
    [[ " $2 " =~ ' '$BIGHEXPAT' ' ]] && {
      jj --no-pager --ignore-working-copy evolog --color=always -n1 -p -T 'builtin_log_detailed(commit)' -r "${BASH_REMATCH[1]}" |
	head -n 3000
    }
    ;;
esac

# == Done ==
exit 0
