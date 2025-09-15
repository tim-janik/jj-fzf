#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x

readonly SCREENCAST_SESSION=revset-demo
source $(dirname $(readlink -f "${BASH_SOURCE[0]}"))/prepare.sh	"$@" # for $TEMPD and funcs

# == Config ==
export JJ_CONFIG=$(make_jj_config)
clone_jj_repo $TEMPD/$SCREENCAST_SESSION

D() ( K Down )
U() ( K Up )
Tab() ( K Tab )

# == SCRIPT ==
start_screencast $TEMPD/$SCREENCAST_SESSION \
		 'jj-fzf' Enter M-h
D; D; S

# -- Revset --
X 'The "Revset >" prompt configures the `jj log` revision set'
T 'description(faq)'; P

K C-u; S
T 'heads(immutable())'; P
T '::'; P; D; S

# -- Ctrl-U --
X 'Use Ctrl-U to clear the entire input field'
K C-u; P

T 'tags()'; P
T '..'; P; D; S

K C-u; S
T 'author_date(before:2024-01-17)'; P

# -- Alt+Enter --
X 'The current revset can be persisted with Alt-Enter'
K M-Enter; P
T '..'; P;
K C-u; P

# == EXIT ==
P
stop_screencast

# (cd $TEMPD/$SCREENCAST_SESSION && bash --norc )

jj --repository $TEMPD/$SCREENCAST_SESSION \
   config get 'jj-fzf.log_revset' |
  grep -q 'author_date.*before.*2024-01-17' &&
  echo '  OK    ' "$0 passed" ||
    die 'failed to validate screencast result, missing: author_date'
