#!/usr/bin/env bash
set -Eeuo pipefail #-x
ABSPATHSCRIPT=`readlink -f "$0"` && function die { echo "${ABSPATHSCRIPT##*/}: **ERROR**: ${*:-aborting}" >&2; exit 127 ; }

SFXSHTMPDIR="$(mktemp -d -t sfxsh.XXXXXX)"
trap 'rm -rf "$SFXSHTMPDIR"' EXIT

if test " ${1-}" == ' --sfxsh-pack' ; then
  EXE="$2" TB="$3" && shift 3
  tar zcf "$TB".tmp "$@"
  ( cat "$0"
    echo '$SFXSHTMPDIR'/"${EXE#/}" '"$@"'
    echo 'exit'
    echo '#''__SFXSH_TAR__'
    cat "$TB".tmp
  ) > "$TB"
  chmod +x "$TB"
  rm -f "$TB".tmp
  ls -al "$TB"
  exit 0
fi

OFFSET=$(sed '/#''__SFXSH_TAR__/q' "$0" | wc -c) ||
  die "failed to detect tarball"
dd iseek=1 ibs="$OFFSET" if="$0" 2>/dev/null | ( cd $SFXSHTMPDIR && tar zxf - ) ||
  die "failed to extract tarball"

export SFXSHTMPDIR

