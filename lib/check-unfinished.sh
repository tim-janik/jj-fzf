#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x

# Usage: check-unfinished.sh [FILE...]

# enable color?
tty -s && C="--color=always" || C=

# check for keywords
if
  grep -s $C '\bFIX''ME\b' "$@" /dev/null
then
  exit 101	# matches indicate errors
fi

# exit status
exit 0
