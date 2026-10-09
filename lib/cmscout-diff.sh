#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail
# Git external diff: <path> <old-file> <old-hex> <old-mode> <new-file> <new-hex> <new-mode> [<new-path> <info>]
test $# -ge 7 || { echo "* Unmerged path $1"; exit 0; }
# shellcheck disable=SC2086 # split flags
exec cmscout ${CMSCOUT_FLAGS-} -B "$2" -A "$5" "a/$1" "b/${8:-$1}"
