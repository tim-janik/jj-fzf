# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

all:
SHELL		:= /usr/bin/env bash -o pipefail
version_full	!= ./version.sh
version_bits    := $(subst _, , $(subst -, , $(subst ., , $(version_full))))
PREFIX		?= /usr/local
BINDIR		?= ${PREFIX}/bin
SHAREDIR	?= $(PREFIX)/share
MANDIR		?= $(SHAREDIR)/man
PKGVERSION      := $(word 1, $(version_bits)).$(word 2, $(version_bits))
LIBEXEC		?= libexec/jj-fzf-$(PKGVERSION)
PRJDIR		?= $(PREFIX)/$(LIBEXEC)
CLEANFILES	:= *.tmp
CLEANDIRS	:=
Q		:= $(if $(findstring 1, $(V)),, @)
QGEN		 = @echo '  GEN     ' $@
INSTALL	:= install -c
RM	:= rm -f

# == doc/jj-fzf.1 ==
doc/jj-fzf.1: doc/jj-fzf.1.md jj-fzf Makefile.mk
	$(QGEN)
	$Q ./jj-fzf --help-bindings > doc/keys.tmp
	$Q sed -r $$'/```jj-fzf --help-bindings```/ { r doc/keys.tmp\n d ; }' $< > doc/jj-fzf.1.tmp.md
	$Q pandoc $(man/markdown-flavour) -s -p \
		-M date="$(word 2, $(version_full))" \
		-M footer="jj-fzf-$(word 1, $(version_full))" \
		-t man doc/jj-fzf.1.tmp.md -o $@.tmp
	$Q rm -f doc/keys.tmp doc/jj-fzf.1.tmp.md && mv $@.tmp $@
man/markdown-flavour	:= -f markdown+hard_line_breaks+autolink_bare_uris+emoji+lists_without_preceding_blankline-smart
CLEANFILES += doc/jj-fzf.1 doc/*.tmp*
all: doc/jj-fzf.1

check-deps: jj-fzf
	$Q ./jj-fzf --version
	$Q ./jj-fzf --help >/dev/null # check-deps

install: doc/jj-fzf.1
	$(QGEN)
	mkdir -p $(DESTDIR)$(PRJDIR)/doc $(DESTDIR)$(BINDIR) $(DESTDIR)$(MANDIR)/man1
	install -c version.sh jj-fzf $(DESTDIR)$(PRJDIR)
	@ # Note, .gitattributes:export-subst + git archive + tar are used to hardcode version in $(PRJDIR)/version.sh
	test ! -e .gitattributes || git archive HEAD version.sh | tar xC $(DESTDIR)$(PRJDIR)
	install -c doc/jj-fzf.1 $(DESTDIR)$(PRJDIR)/doc
	ln -sf ../../../$(LIBEXEC)/doc/jj-fzf.1 $(DESTDIR)$(MANDIR)/man1/
	ln -sf ../$(LIBEXEC)/jj-fzf $(DESTDIR)$(BINDIR)/jj-fzf
uninstall:
	$(QGEN)
	rm -r -f $(DESTDIR)$(PRJDIR) $(DESTDIR)$(BINDIR)/jj-fzf $(DESTDIR)$(MANDIR)/man1/jj-fzf.1

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

# == clean ==
clean:
	rm -f $(CLEANFILES)
	rm -f -r $(CLEANDIRS)
.PHONY: clean

