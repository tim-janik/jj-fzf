#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x

# Read file and output character by character
while IFS= read -r -n1 char; do
    printf "%s" "$char"
    sleep "$1"
done < "$2"
