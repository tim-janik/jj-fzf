#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
ABSPATHSCRIPT=$(readlink -f "$0")	# Resolve symlinks to find installdir

# == Imports ==
# Import jj_show_diff and helpers
source "${BASH_SOURCE[0]%/*}"/common.sh

# == Preview Rendering ==
case "${1:-}" in
  preview_revision)
    shift
    # Pattern to match revisions
    REVPAT='^[^a-z()0-9]*([k-xyz]{7,})([?]*)\ '		# line start, ignore --graph, parse revision letters, catch '??'-postfix
    # Render preview if revision is found
    if [[ "${*-} " =~ $REVPAT ]] ; then			# match beginning of jj log line
      REVISION="${BASH_REMATCH[1]}"
      if [[ "${BASH_REMATCH[2]}" == '??' ]] ; then		# divergent change_id
	# https://martinvonz.github.io/jj/latest/FAQ/#how-do-i-deal-with-divergent-changes-after-the-change-id
	jj --no-pager --ignore-working-copy show -T builtin_log_oneline -r "${BASH_REMATCH[1]}" 2>&1 || :
	echo
	REVISION=$(echo " $2 " | grep -Po '(?<= )[a-f0-9]{8,}(?= )') || exit 0	# find likely commit id
      fi
      { jj --no-pager --ignore-working-copy log --color=always --no-graph -T "$JJ_FZF_SHOWDETAILS" -s -r "$REVISION"
	jj_show_diff --color=always -T '"\n"' -r "$REVISION"
      } 2>&1 | head -n 2000
    fi							# else no valid revision
    ;;
esac

# == Done ==
exit 0
