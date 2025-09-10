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
QSKIP		:= $(if $(findstring s,$(MAKEFLAGS)),: )
QECHO		 = @QECHO() { Q1="$$1"; shift; QR="$$*"; QOUT=$$(printf '  %-8s ' "$$Q1" ; echo "$$QR") && $(QSKIP) echo "$$QOUT"; }; QECHO

# == Check presence of dependencies ==
check-deps: preflight.sh jj-fzf
	$(QGEN)
	$Q ./preflight.sh
	$Q ./jj-fzf --version >/dev/null || { echo "$@: ERROR: failed to start ./jj-fzf as \`bash\` script" >&2; false; }
.PHONY: check-deps
all check: check-deps

# == doc/jj-fzf.1 ==
doc/jj-fzf.1: doc/jj-fzf.1.md jj-fzf Makefile.mk
	$(QGEN)
	$Q TEMPD="`mktemp -d`" && cd "$$TEMPD" && jj git init 2>/dev/null \
	&& $(abspath ./jj-fzf) --help-bindings > $(abspath doc/keys.tmp) \
	&& cd / && rm -r -f "$$TEMPD" # jj-fzf needs a .jj repo to run
	$Q sed -r $$'/```jj-fzf --help-bindings```/ { r doc/keys.tmp\n d ; }' $< > doc/jj-fzf.1.tmp.md
	$Q pandoc $(man/markdown-flavour) -s -p \
		-M date="$(word 2, $(version_full))" \
		-M footer="jj-fzf-$(word 1, $(version_full))" \
		-t man doc/jj-fzf.1.tmp.md -o $@.tmp
	$Q rm -f doc/keys.tmp doc/jj-fzf.1.tmp.md && mv $@.tmp $@
man/markdown-flavour	:= -f markdown+hard_line_breaks+autolink_bare_uris+emoji+lists_without_preceding_blankline-smart
CLEANFILES += doc/jj-fzf.1 doc/*.tmp*
all: doc/jj-fzf.1

# == SCRIPTS ==
LIBSCRIPTS   := lib/common.sh lib/exectool.sh lib/preview.sh
SHELLSCRIPTS := jj-fzf preflight.sh version.sh sfx.sh

# == tests ==
tests-basics.sh:
	$Q tests/basics.sh
.PHONY: tests-basics.sh

# == shellcheck ==
shellcheck-warning: $(SHELLSCRIPTS) $(LIBSCRIPTS)
	$(QGEN)
	$Q shellcheck --version | grep -q 'script analysis' || { echo "$@: missing GNU shellcheck"; false; }
	shellcheck -W 3 -S warning -e SC2178,SC2207,SC2128 $(SHELLSCRIPTS) $(LIBSCRIPTS)
shellcheck-error:
	$(QGEN)
	$Q shellcheck --version | grep -q 'script analysis' || { echo "$@: missing GNU shellcheck"; false; }
	shellcheck -W 3 -S error $(SHELLSCRIPTS) $(LIBSCRIPTS)
check-help:
	$(QGEN)
	$Q ./jj-fzf --help | grep -qF jj-fzf || { echo "$@: ERROR: failed to render \`./jj-fzf --help\`" >&2; false; }
check: check-deps check-help shellcheck-error tests-basics.sh

# == install & uninstall ==
install: all
	$(QGEN)
	mkdir -p $(DESTDIR)$(PRJDIR)/doc $(DESTDIR)$(PRJDIR)/lib $(DESTDIR)$(BINDIR) $(DESTDIR)$(MANDIR)/man1
	install -c $(SHELLSCRIPTS) $(DESTDIR)$(PRJDIR)
	install -c $(LIBSCRIPTS) $(DESTDIR)$(PRJDIR)/lib
	@ # Note, .gitattributes:export-subst + git archive + tar are used to hardcode version in $(PRJDIR)/version.sh
	test ! -e .gitattributes || git archive HEAD version.sh | tar xC $(DESTDIR)$(PRJDIR)
	install -c doc/jj-fzf.1 $(DESTDIR)$(PRJDIR)/doc
	ln -sf ../../../$(LIBEXEC)/doc/jj-fzf.1 $(DESTDIR)$(MANDIR)/man1/
	ln -sf ../$(LIBEXEC)/jj-fzf $(DESTDIR)$(BINDIR)/jj-fzf
installcheck:
	$(QGEN)
	$Q $(DESTDIR)$(BINDIR)/jj-fzf --version >/dev/null \
	|| { echo "$@: ERROR: failed to start $(DESTDIR)$(BINDIR)/jj-fzf" >&2; false; }
	$Q man $(DESTDIR)$(PRJDIR)/doc/jj-fzf.1 | grep -qF jj-fzf \
	|| { echo "$@: ERROR: failed to render $(DESTDIR)$(PRJDIR)/doc/jj-fzf.1" >&2; false; }
uninstall:
	$(QGEN)
	rm -r -f $(DESTDIR)$(PRJDIR) $(DESTDIR)$(BINDIR)/jj-fzf $(DESTDIR)$(MANDIR)/man1/jj-fzf.1

# == distcheck ==
distcheck:
	@$(eval distversion != git describe --match='v[0-9]*.[0-9]*.[0-9]*' | sed 's/^v//')
	@$(eval distname := jj-fzf-$(distversion))
	$(QECHO) MAKE $(distname).tar.zst
	$Q test -n "$(distversion)" || { echo -e "#\n# $@: ERROR: no dist version, is git working?\n#" >&2; false; }
	$Q git describe --dirty | grep -qve -dirty || echo -e "#\n# $@: WARNING: working tree is dirty\n#"
	$Q rm -r -f artifacts/ && mkdir -p artifacts/
	$Q # Generate ChangeLog with ^^-prefixed records. Tab-indent commit bodies, kill whitespaces and multi-newlines
	$Q git log --abbrev=13 --date=short --first-parent HEAD	\
		--pretty='^^%ad  %an 	# %h%n%n%B%n'		>  artifacts/ChangeLog \
	&& sed 's/^/	/; s/^	^^// ; s/[[:space:]]\+$$// '	-i artifacts/ChangeLog \
	&& sed '/^\s*$$/{ N; /^\s*\n\s*$$/D }'			-i artifacts/ChangeLog
	$Q # Generate and compress artifacts/jj-fzf-*.tar.zst
	$Q git archive --prefix=$(distname)/ --add-file artifacts/ChangeLog -o artifacts/$(distname).tar HEAD
	$Q rm -f artifacts/$(distname).tar.zst && zstd --ultra -22 --rm artifacts/$(distname).tar && ls -lh artifacts/$(distname).tar.zst
	$Q T=`mktemp -d` && cd $$T && tar xf $(abspath artifacts/$(distname).tar.zst) \
	&& cd jj-fzf-$(distversion) \
	&& nice make all -j`nproc` \
	&& make PREFIX=$$T/inst install \
	&& make PREFIX=$$T/inst installcheck -j`nproc` \
	&& (set -x && $$T/inst/bin/jj-fzf --version) \
	&& make PREFIX=$$T/inst uninstall \
	&& (set -x && $$PWD/jj-fzf --version) \
	&& cd / && rm -r "$$T"
	$Q echo "Archive ready: artifacts/$(distname).tar.zst" | sed '1h; 1s/./=/g; 1p; 1x; $$p; $$x'
CLEANDIRS += artifacts

# == artifacts/jj-fzf.sfx ==
artifacts/jj-fzf.sfx: all
	$(QGEN)
	$Q rm -rf xinst/
	$Q $(MAKE) install DESTDIR=xinst/
	$Q cd xinst/ && $(abspath sfx.sh) --sfxsh-pack /usr/local/bin/jj-fzf $(abspath $@) *
	$Q rm -rf xinst/
	$Q echo "SFX archive ready: $@" | sed '1h; 1s/./=/g; 1p; 1x; $$p; $$x'

# == clean ==
clean:
	rm -f $(CLEANFILES)
	rm -f -r $(CLEANDIRS)
.PHONY: clean

