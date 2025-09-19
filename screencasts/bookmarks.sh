#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x

readonly SCREENCAST_SESSION=bookmarks-demo
source $(dirname $(readlink -f "${BASH_SOURCE[0]}"))/prepare.sh	"$@" # for $TEMPD and funcs

# == Config ==
export JJ_CONFIG=$(make_jj_config)
clone_jj_repo $TEMPD/$SCREENCAST_SESSION
( stdio_to_dev_null
  cd $TEMPD/$SCREENCAST_SESSION
  jj b c release-candidate -r qxttrqlv
  jj b t main@origin
)

D() ( K Down )
U() ( K Up )
Tab() ( K Tab )

# == SCRIPT ==
start_screencast $TEMPD/$SCREENCAST_SESSION \
		 'jj-fzf' Enter F11 M-h F11
D; D; D

# -- main --
X 'Use Alt-B to edit bookmarks or tags'
D; D; S
K M-b; S
X 'Use Alt-B to move/create a bookmark: main'
K M-b; P
K Enter; P

# -- Create Bookmark --
X 'Use Alt-B and Alt-D to delete a ref: release-candidate'
U; U; U; S
K M-b; S
K M-d; P
K Enter; P

# -- tag --
X 'Use Alt-B and Alt-T to create a new tag: v0.28.2'
U; S
K M-b; S
K M-t; S
T 'v0.28.2'; P
K Enter; P

# == EXIT ==
P; D
stop_screencast

# (cd $TEMPD/$SCREENCAST_SESSION && bash --norc )

( cd $TEMPD/$SCREENCAST_SESSION
  git tag -n1 |
    fgrep -q release-candidate && die 'failed to delete tag: release-candidate'
  git log -1 --format=%s main -- |
    fgrep -q 'builtin merge' || die 'failed to create bookmark: main'
  git log -1 --format=%s v0.28.2 |
    fgrep -q 'release: 0.28.2' || die 'failed to tag v0.28.2'
)

printf '  %-8s %s\n' OK "$SCREENCAST_SESSION passed"
