#!/usr/bin/env bash
set -Eeuo pipefail #-x

# Usage: popfile.sh <target>
TARGET="$1"

# Consume files from $POPFILE_LIST, write into <target>
IFS='; ' read -r -a FILES <<< "${POPFILE_LIST-}"
for f in "${FILES[@]}" ; do
  test -r "$f" && {
    cat "$f" > "$TARGET"
    rm "$f"
    exit 0
  }
done

# Consume files from $KEEPFILE_LIST, keepping <target>
IFS='; ' read -r -a FILES <<< "${KEEPFILE_LIST-}"
for f in "${FILES[@]}" ; do
  test -r "$f" && {
    rm "$f"
    exit 0
  }
done

# Finally, empty <target>
echo -n > "$TARGET"

exit 0
