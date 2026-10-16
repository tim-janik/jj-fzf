#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail

tokens=$(awk -F '`' '{ for (i = 2; i < NF; i += 2) print $i }' "$1" | sort -u)
status=0
while IFS= read -r token ; do
  case "$token" in
    make\ *) target="${token#make }"
             awk -v target="$target" '
               /^[^#[:space:]][^:=]*:([^=]|$)/ {
                 sub(/:.*/, "")
                 for (i = 1; i <= NF; i++)
                   if ($i == target) found = 1
               }
               END { exit !found }
             ' GNUmakefile Makefile.mk || {
               echo "$1: missing make target: $target" >&2; status=1;
             } ;;
    */*)     test -e "$token" || { echo "$1: missing path: $token" >&2; status=1; } ;;
  esac
done <<< "$tokens"
exit "$status"
