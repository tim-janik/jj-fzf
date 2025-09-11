#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x

# File hash *before* editing
PREHASH="$(sha256sum "$1" 2>/dev/null)"

# Determine original editor
JJ_EDITOR="${JJFZF_EDITOR-}"
jj --no-pager --ignore-working-copy config get ui.editor 2>/dev/null
test -z "$JJ_EDITOR" &&
  JJ_EDITOR="$(jj --no-pager --ignore-working-copy config get ui.editor 2>/dev/null)"
test -z "$JJ_EDITOR" &&
  JJ_EDITOR="${VISUAL:-${EDITOR:-pico}}"

# Edit files
ERR=0
"$JJ_EDITOR" "$@" || ERR=$?

# Report "no-edit" as error
if test $ERR == 0 ; then
  POSTHASH="$(sha256sum "$1" 2>/dev/null)"
  test "$PREHASH" == "$POSTHASH" &&
    ERR=1
fi

exit $ERR
