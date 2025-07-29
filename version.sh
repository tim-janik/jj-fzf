#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail

# Commit information provided by git-archive in export-subst format string, see gitattributes(5)
read VDESCRIBE VDATE <<<' $Format: %(describe:match=v[0-9]*.[0-9]*.[0-9]*) %ci $ '

# Use baked-in version info if present
! [[ "$VDATE" =~ % ]] &&
  echo "${VDESCRIBE#v} $VDATE" && exit

# Use version info from git repository, needs non-shallow clones
# Prefer exact tags (even if light, like nightly) over annotated tags
cd $(dirname $(readlink -f "$0"))
VDESCRIBE=$(git describe --exact-match --tags --match='v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null ||
	      git describe --match='v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null) &&
  echo "${VDESCRIBE#v} `git -P log -1 --pretty=%ci`" && exit

# Fallback, unversioned
echo "0.0.0-unversioned0 2001-01-01 01:01:01 +0000"
