# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

SHELL		:= /bin/bash -o pipefail
version_full	!= ./version.sh
version_bits    := $(subst _, , $(subst -, , $(subst ., , $(version_full))))
PREFIX		?= /usr/local
BINDIR		?= ${PREFIX}/bin
SHAREDIR	?= $(PREFIX)/share
PKGVERSION      := $(word 1, $(version_bits)).$(word 2, $(version_bits))
LIBEXEC		?= libexec/jj-fzf-$(PKGVERSION)
PRJDIR		?= $(PREFIX)/$(LIBEXEC)
Q		:= $(if $(findstring 1, $(V)),, @)
QGEN		 = @echo '  GEN     ' $@
INSTALL	:= install -c
RM	:= rm -f



all: check

check-deps: jj-fzf
	$Q ./jj-fzf --version
	$Q ./jj-fzf --help >/dev/null # check-deps

install:
	$(QGEN)
	mkdir -p $(DESTDIR)$(PRJDIR) $(DESTDIR)$(BINDIR)
	install -c version.sh jj-fzf $(DESTDIR)$(PRJDIR)
	@ # Note, .gitattributes:export-subst + git archive + tar are used to hardcode version in $(PRJDIR)/version.sh
	test ! -e .gitattributes || git archive HEAD version.sh | tar xC $(DESTDIR)$(PRJDIR)
	ln -sf ../$(LIBEXEC)/jj-fzf $(DESTDIR)$(BINDIR)/jj-fzf
uninstall:
	rm -r -f $(DESTDIR)$(PRJDIR) $(DESTDIR)$(BINDIR)/jj-fzf

shellcheck-warning: jj-fzf
	$Q shellcheck --version | grep -q 'script analysis' || { echo "$@: missing GNU shellcheck"; false; }
	shellcheck -W 3 -S warning -e SC2178,SC2207,SC2128 jj-fzf
shellcheck-error:
	$Q shellcheck --version | grep -q 'script analysis' || { echo "$@: missing GNU shellcheck"; false; }
	shellcheck -W 3 -S error jj-fzf
tests-basics.sh:
	$Q tests/basics.sh
check-gsed: jj-fzf
	$Q ! grep --color=auto -nE '[^\\]\bsed ' jj-fzf /dev/null \
	|| { echo "ERROR: use gsed" >&2 ; false; }
	$Q echo '  OK      gsed uses'
check: check-deps shellcheck-error check-gsed tests-basics.sh
