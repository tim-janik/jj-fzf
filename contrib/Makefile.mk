# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

SHELL		:= /usr/bin/env bash -o pipefail
SHELLSCRIPTS	:= jj-pull-heads.sh test-jj-pull-heads.sh
Q		:= $(if $(findstring 1, $(V)),, @)

# == shellcheck & tests ==
check:
	$(QGEN)
	$Q shellcheck --version | grep -q 'script analysis' || { echo "$@: missing GNU shellcheck"; false; }
	shellcheck -W 3 -S error $(SHELLSCRIPTS)
	$Q ./test-jj-pull-heads.sh
.PHONY: check
