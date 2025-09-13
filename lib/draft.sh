#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
ABSPATHSCRIPT=$(readlink -f "$0")	# Resolve symlinks to find installdir

# == Imports ==
source "${ABSPATHSCRIPT%/*}"/setup.sh	# preflight.sh

# == Options ==
KEEP=false
HINT=false
COMMIT=
while test $# -ne 0 ; do
  case "$1" in \
    --keep)		KEEP=true ;;
    --hint)		HINT=true ;;
    *)                  COMMIT="$1" ; break ;;
  esac
  shift
done

# jj config hint
if $HINT ; then
  cat >&2 <<\__EOF
# For commit message generation of a non-merge commit, jj-fzf used to list
# edited files, add Signed-off-by and append a diff. In newer JJ versions,
# this can all be configured via `jj config` templates. Note that using
# commit_trailers may interfere with empty descriptiopn editing.
# See also: https://jj-vcs.github.io/jj/latest/config/#default-description
# The following config is similar to the old jj-fzf describe command:
__EOF
  cat <<\__EOF
[templates]
draft_commit_description = '''
concat(
  coalesce(
    description,
    if(diff.files(),
      diff.files().map(|e| e.path().display()).join(', ') ++ ": \n")
    ++ default_commit_description ++ "\n" ++
    format_signed_off_by_trailer(self)
    , "\n"),
  surround(
    "\nJJ: This commit contains the following changes:\n", "",
    indent("JJ:     ", diff.stat(72)),
  ),
  "JJ: ignore-rest\n\n",
  diff.git(),
)
'''
__EOF
  exit 0
fi

# == Draft Merge Commit Message ==
test -n "$COMMIT" ||
  die "Missing commit"
JJ='jj --no-pager --ignore-working-copy --color=never'

# Keep existing description
DESCRIPTION="$($JJ log --no-graph -r "$COMMIT" -T 'description')"
if $KEEP && test -n "$DESCRIPTION" ; then
  printf "%s\n" "$DESCRIPTION"
  exit 0
fi

find_first_bookmark()
(
  $JJ log --no-graph -T 'concat(separate(" ",bookmarks), " ", change_id)' -r "$1" |
    awk '{print $1;}'
)

# List parents
PARENTS=( $($JJ log --no-graph -T 'commit_id ++ "\n"' -r "$COMMIT-" --reversed) )

# Output merge message
if test "${#PARENTS[@]}" -ge 2 ; then
  MERGE_BASE=$(git merge-base --octopus "${PARENTS[@]}")
  if test "${#PARENTS[@]}" -eq 2 ; then
    echo "Merge branch '$(find_first_bookmark ${PARENTS[1]})' into '$(find_first_bookmark ${PARENTS[0]})'"
  else
    echo "Merge branches:" "${PARENTS[@]}"
  fi
  for c in "${PARENTS[@]}"; do
    test "$c" == "$MERGE_BASE" &&
      continue
    if test "${#PARENTS[@]}" -eq 2 ; then
      echo -e "\n* Branch commit log:"	# "$c ^$MERGE_BASE"
    else
      echo -e "\n* Branch '$(find_first_bookmark $c)' commit log:"
    fi
    git log --pretty=$'\f%s%+b' $c ^$MERGE_BASE |
      sed '/^\([A-Z][a-z0-9-]*-by\|Cc\):/d' | # strip Signed-off-by:
      sed '/^$/d ; s/^/\t/ ; s/^\t\f$/  (no description)/ ; s/^\t\f/  /' || :
  done
  # echo && $JJ log --no-graph -r "$COMMIT" -T ' format_signed_off_by_trailer(self) '
fi

exit 0
