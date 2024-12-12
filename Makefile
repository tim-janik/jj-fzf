# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

SHELL	::= /bin/bash -o pipefail
prefix	 ?= /usr/local
bindir	 ?= ${prefix}/bin
INSTALL	::= install -c
RM	::= rm -f
Q	::= $(if $(findstring 1, $(V)),, @)

all: check

check-deps: jj-fzf
	$Q ./jj-fzf --version
	$Q ./jj-fzf --help >/dev/null # check-deps
install: check-deps
	$(INSTALL) -t "$(bindir)" jj-fzf
uninstall:
	$(RM) "$(bindir)/jj-fzf"

shellcheck-warning: jj-fzf
	$Q shellcheck --version | grep -q 'script analysis' || { echo "$@: missing GNU shellcheck"; false; }
	shellcheck -W 3 -S warning -e SC2178,SC2207,SC2128 jj-fzf
shellcheck-error:
	$Q shellcheck --version | grep -q 'script analysis' || { echo "$@: missing GNU shellcheck"; false; }
	shellcheck -W 3 -S error jj-fzf
tests-basics.sh:
	$Q tests/basics.sh
check-gsed: jj-fzf
	$Q ! grep --color=auto -E '[^\\]\bsed ' jj-fzf \
	|| { echo "ERROR: use gsed" >&2 ; false; }
	$Q echo '  OK      gsed uses'
check: check-deps shellcheck-error check-gsed tests-basics.sh
