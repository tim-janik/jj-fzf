# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

all:
SHELL		:= /usr/bin/env bash -o pipefail

# == Version ==
# Baked .version, else .version as git archive bakes it.
version_info != grep -xm1 '^v\?[0-9][^$$]*' .version || git archive HEAD .version | tar -xOf -
TAG := $(word 1, $(version_info))
version_date := $(wordlist 2, 4, $(version_info))
version = $(patsubst v%,%,$(TAG))
version_bits	:= $(subst _, , $(subst -, , $(subst ., , $(version))))
version_major	:= $(word 1, $(version_bits))
version_minor	:= $(word 2, $(version_bits))
version_micro	:= $(word 3, $(version_bits))
version:
	@echo "$(version)  $(version_date)"
.PHONY: version
ifeq ($(and $(version_micro),$(word 4, $(version_info))),)	# do we have any version?
$(error Missing version information, need git describe or .version)
endif

PREFIX		?= /usr/local
BINDIR		?= ${PREFIX}/bin
SHAREDIR	?= $(PREFIX)/share
MANDIR		?= $(SHAREDIR)/man
PKGVERSION      := $(version_major).$(version_minor)
LIBEXEC		?= libexec/jj-fzf-$(PKGVERSION)
PRJDIR		?= $(PREFIX)/$(LIBEXEC)
CLEANFILES	:= *.tmp
CLEANDIRS	:=
Q		:= $(if $(findstring 1, $(V)),, @)
QGEN		 = @echo '  GEN     ' $@
QSKIP		:= $(if $(findstring s,$(MAKEFLAGS)),: )
QECHO		 = @QECHO() { Q1="$$1"; shift; QR="$$*"; QOUT=$$(printf '  %-8s ' "$$Q1" ; echo "$$QR") && $(QSKIP) echo "$$QOUT"; }; QECHO

# == Require GNU Make >= 4.0 for $(file) ==
ifneq ($(filter 3.%,$(MAKE_VERSION)),)
  $(error GNU Make >= 4.0 is required (found $(MAKE_VERSION)))
endif

# == Check presence of dependencies ==
check-deps: preflight.sh jj-fzf
	$(QGEN)
	$Q ./preflight.sh
	$Q ./jj-fzf --version >/dev/null || { echo "$@: ERROR: failed to start ./jj-fzf as \`bash\` script" >&2; false; }
.PHONY: check-deps
all check: check-deps

# == CmdRunReplace ==
define CmdRunReplace
/^!!!!/ {
  cmd = substr($$0, 5)
  while (( (cmd " 2>&1 || echo __CMDRR_ERROR__=$$?") | getline line) > 0) { print line }
  close(cmd)
  next
}
{ print }
endef

# == doc/jj-fzf.1 ==
doc/jj-fzf.1: doc/jj-fzf.1.md Makefile.mk jj-fzf $(wildcard lib/*)
	$(file > doc/cmdrr.awk, $(CmdRunReplace))
	$(QGEN)
	$Q TEMPD="`mktemp -d`" && cd "$$TEMPD" \
	&& jj git init 2>/dev/null && ln -s $(abspath .)/* . \
	&& awk -f $(abspath doc/cmdrr.awk) $(abspath $<) > $(abspath doc/jj-fzf+cmds.1.md) \
	&& cd / && rm -r -f "$$TEMPD"	# jj-fzf needs a .jj repo to run
	$Q ! grep -B3 -Fn '__CMDRR_ERROR__' doc/jj-fzf+cmds.1.md /dev/null
	$Q grep -iq 'alt-r.*rebase' doc/jj-fzf+cmds.1.md || { echo 'doc/jj-fzf+cmds.1.md: missing Alt-R'; false; }
	$Q pandoc $(man/markdown-flavour) -s -p \
		-M date="$(word 1, $(version_date))" \
		-M footer="jj-fzf-$(version)" \
		doc/jj-fzf+cmds.1.md -t man -o $@.tmp
	$Q rm -f doc/cmdrr.awk doc/keys.tmp doc/jj-fzf.1.tmp.md && mv $@.tmp $@
man/markdown-flavour	:= -f markdown+autolink_bare_uris+emoji+lists_without_preceding_blankline-smart
CLEANFILES += doc/jj-fzf.1 doc/*.tmp*
all: doc/jj-fzf.1

# == jj-fzf-help.md ==
# Man page for the jj-fzf wiki
doc/jj-fzf.1.gfm.md: doc/jj-fzf.1
	pandoc $(man/markdown-flavour) -s -p \
		-M date="$(word 1, $(version_date))" \
		-M footer="jj-fzf-$(version)" \
		doc/jj-fzf+cmds.1.md -t gfm -o $@

# == SCRIPTS ==
SHELLSCRIPTS := jj-fzf $(wildcard *.sh lib/*.sh)

# == tests ==
tests-basics.sh:
	$Q tests/basics.sh
.PHONY: tests-basics.sh
tests-regressions.sh:
	$Q tests/regressions.sh
.PHONY: tests-regressions.sh
tests-features.sh:
	$Q tests/features.sh
.PHONY: tests-features.sh

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
check: check-deps check-help shellcheck-error tests-basics.sh tests-regressions.sh tests-features.sh

# == test ==
test: test-screencasts
.PHONY: test test-screencasts
SCREENCAST.SCRIPTS := oplog.sh bookmarks.sh revset.sh intro.sh rebasing.sh splitting.sh merging.sh megamerge.sh
define TEST_SCREENCAST
test-screencast-$1: screencasts/$1
	$$(QECHO) RUN $$<
	$Q cd screencasts && ./$1 --hide --fast
.PHONY: test-screencast-$1
test-screencasts: test-screencast-$1
endef
$(foreach F, $(SCREENCAST.SCRIPTS), $(eval $(call TEST_SCREENCAST,$F)))

# == install & uninstall ==
PRJ_INSTALL_FILES := $(wildcard README.md NEWS.md jj-fzf *.sh)
LIB_INSTALL_FILES := $(wildcard lib/*.awk lib/*.py lib/*.sh)
install: all
	$(QGEN)
	mkdir -p $(DESTDIR)$(PRJDIR)/doc $(DESTDIR)$(PRJDIR)/lib $(DESTDIR)$(BINDIR) $(DESTDIR)$(MANDIR)/man1
	install -c $(PRJ_INSTALL_FILES) $(DESTDIR)$(PRJDIR)
	install -c $(LIB_INSTALL_FILES) $(DESTDIR)$(PRJDIR)/lib
	echo '$(version_info)' > $(DESTDIR)$(PRJDIR)/.version
	install -c doc/jj-fzf.1 $(DESTDIR)$(PRJDIR)/doc
	ln -sf ../../../$(LIBEXEC)/doc/jj-fzf.1 $(DESTDIR)$(MANDIR)/man1/
	ln -sf ../$(LIBEXEC)/jj-fzf $(DESTDIR)$(BINDIR)/jj-fzf
installcheck:
	$(QGEN)
	$Q test "`$(DESTDIR)$(BINDIR)/jj-fzf --version`" = "jj-fzf $(patsubst v%,%,$(version_info))" \
	|| { echo "$@: ERROR: failed to start $(DESTDIR)$(BINDIR)/jj-fzf" >&2; false; }
	$Q man $(DESTDIR)$(PRJDIR)/doc/jj-fzf.1 > $@.tmp \
	&& grep -qF jj-fzf $@.tmp && rm -f $@.tmp \
	|| { echo "$@: ERROR: failed to render $(DESTDIR)$(PRJDIR)/doc/jj-fzf.1" >&2; false; }
uninstall:
	$(QGEN)
	rm -r -f $(DESTDIR)$(PRJDIR) $(DESTDIR)$(BINDIR)/jj-fzf $(DESTDIR)$(MANDIR)/man1/jj-fzf.1

# == apt-deps-install ==
apt-deps-install:
	$(QGEN)
	$Q command -v fzf >/dev/null 2>&1 && exit 0 ; \
	   V=$$(sed -n '/ fzf --version/{s/.*__preflightish_require "\([0-9.]*\)".*/\1/p}' preflight.sh) \
	   && curl -s -L https://github.com/junegunn/fzf/releases/download/v$$V/fzf-$$V-linux_amd64.tar.gz \
	   | sudo tar zxf - -C /usr/local/bin/ fzf
	fzf --version
	$Q command -v jj >/dev/null 2>&1 && exit 0 ; \
	   V=$$(sed -n '/ jj --version/{s/.*__preflightish_require "\([0-9.]*\)".*/\1/p}' preflight.sh) \
	   && curl -s -L https://github.com/jj-vcs/jj/releases/download/v$$V/jj-v$$V-x86_64-unknown-linux-musl.tar.gz \
	    | sudo tar zxf - -C /usr/local/bin/ ./jj
	jj --version
	$Q echo "Force newer pandoc" ; \
	   cd /tmp \
	   && wget -q -c https://github.com/jgm/pandoc/releases/download/3.7.0.2/pandoc-3.7.0.2-1-amd64.deb \
	   && sudo apt install ./pandoc-3.7.0.2-1-amd64.deb \
	   && rm -f ./pandoc-3.7.0.2-1-amd64.deb
	pandoc --version

# == dist ==
dist:
	$(eval distname := jj-fzf-$(version))
	$(QECHO) MAKE $(distname).tar.zst
	$Q git describe --dirty | grep -qve -dirty || echo -e "#\n# $@: WARNING: working tree is dirty\n#"
	$Q rm -r -f artifacts/ && mkdir -p artifacts/
	$Q # Generate ChangeLog with ^^-prefixed records. Tab-indent commit bodies.
	$Q # Kill trailing whitespaces. Compress multiple newlines.
	$Q git log --abbrev=13 --date=short --first-parent HEAD	\
		--pretty='^^%ad  %an 	# %h%n%n%B%n'		>  artifacts/ChangeLog \
	&& sed 's/^/	/; s/^	^^// ; s/[[:space:]]\+$$// '	-i artifacts/ChangeLog \
	&& sed '/^\s*$$/{ N; /^\s*\n\s*$$/D }'			-i artifacts/ChangeLog
	$Q # Generate and compress artifacts/jj-fzf-*.tar.zst
	$Q git archive --prefix=$(distname)/ --add-file artifacts/ChangeLog -o artifacts/$(distname).tar HEAD
	$Q rm -f artifacts/$(distname).tar.zst && zstd --ultra -22 --rm artifacts/$(distname).tar && ls -lh artifacts/$(distname).tar.zst
	$Q echo "Archive ready: artifacts/$(distname).tar.zst" | sed '1h; 1s/./=/g; 1p; 1x; $$p; $$x'
CLEANDIRS += artifacts/
.PHONY: dist

# == distcheck ==
# Build all release artifacts from a fresh tarball copy and verify build, install and uninstall.
distcheck: dist
	@$(eval distname := jj-fzf-$(version))
	$(QECHO) CHECK $(distname).tar.zst
	$Q T=$$(mktemp --tmpdir -d jj-fzf-distcheck-XXXXXXXX) \
	&& trap "rm -rf $$T" EXIT \
	&& tar xf artifacts/$(distname).tar.zst -C $$T \
	&& cd $$T/$(distname) \
	&& $(MAKE) all -j$$(nproc) \
	&& $(MAKE) PREFIX=$$T/inst install \
	&& $(MAKE) PREFIX=$$T/inst installcheck \
	&& $(MAKE) PREFIX=$$T/inst uninstall \
	&& test ! -e $$T/inst/bin/jj-fzf \
	&& $(MAKE) artifacts/jj-fzf.sfx artifacts/jj-fzf.1.gz \
	&& test "$$(artifacts/jj-fzf.sfx --version)" = "jj-fzf $(patsubst v%,%,$(version_info))" \
	&& cp -p artifacts/jj-fzf.sfx artifacts/jj-fzf.1.gz $(CURDIR)/artifacts/
	$Q cd artifacts/ \
	&& sha256sum $(distname).tar.zst ChangeLog jj-fzf.sfx jj-fzf.1.gz > $(distname).SHA256SUMS \
	&& sha256sum -c $(distname).SHA256SUMS
	$Q echo "Distcheck ready: artifacts/$(distname).tar.zst" | sed '1h; 1s/./=/g; 1p; 1x; $$p; $$x'
.PHONY: distcheck

# == wiki ==
wiki-jj-fzf-help.md:
	$(MAKE) doc/jj-fzf.1.gfm.md
	git -C wiki/.git/.. switch master
	$Q # git -C wiki/.git/.. reset --hard origin/master
	git -C wiki/.git/.. pull
	mv doc/jj-fzf.1.gfm.md wiki/.git/../jj-fzf-help.md
	git -C wiki/.git/.. add jj-fzf-help.md
	git -C wiki/.git/.. commit -m 'jj-fzf-help.md: Update jj-fzf man page'
	git -C wiki/.git/.. log -1 -p
	$Q echo \# git -C $$PWD/wiki/.git/.. push
.PHONY: wiki-jj-fzf-help.md

# == artifacts/jj-fzf.sfx ==
artifacts/jj-fzf.sfx: all
	$(QGEN)
	$Q mkdir -p $(@D)
	$Q rm -rf xinst/
	$Q $(MAKE) install DESTDIR=xinst/
	$Q cd xinst/ && $(abspath sfx.sh) --sfxsh-pack /usr/local/bin/jj-fzf $(abspath $@) *
	$Q rm -rf xinst/
	$Q echo "SFX archive ready: $@" | sed '1h; 1s/./=/g; 1p; 1x; $$p; $$x'

# == artifacts/jj-fzf.1.gz ==
artifacts/jj-fzf.1.gz: doc/jj-fzf.1
	$(QGEN)
	$Q mkdir -p $(@D)
	$Q cp doc/jj-fzf.1 artifacts/jj-fzf.1
	$Q gzip -9 artifacts/jj-fzf.1
	$Q echo "Man page ready: $@" | sed '1h; 1s/./=/g; 1p; 1x; $$p; $$x'

# == clean ==
clean:
	rm -f $(CLEANFILES)
	rm -f -r $(CLEANDIRS)
.PHONY: clean

