#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0
set -Eeuo pipefail #-x
SCRIPTNAME="${0##*/}" && SCRIPTDIR="$(readlink -f "$0")" && SCRIPTDIR="${SCRIPTDIR%/*}"

[[ " $* " =~ -x ]] && set -x

source $SCRIPTDIR/utils.sh

# == lib_source ==
# Source a line-1 range of lib/$1 into the test shell to reach internal
# functions without triggering the script's top-level fzf UI. Runs from a
# sandbox so relative `source`s resolve, with positional args cleared for
# the scripts' option parsing loops.
lib_source()
{ # LIBFILE SEDEXPR
  local LIBFILE="$1" SEDEXPR="$2"
  # Must stay: only line-1 ranges, mid-file ranges would couple tests to script internals
  [[ "$SEDEXPR" == 1,* ]] ||
    die "lib_source: only ranges starting at line 1 are supported: $SEDEXPR"
  mkdir -p $TEMPD/libtest
  cp $SCRIPTDIR/../preflight.sh $TEMPD/preflight.sh
  cp $SCRIPTDIR/../lib/setup.sh $TEMPD/libtest/setup.sh
  sed -n "$SEDEXPR" "$SCRIPTDIR/../lib/$LIBFILE" > $TEMPD/libtest/part.sh
  local -a OLDARGS=("$@") # source without positional args, so option loops
  set --			# in the sourced script see no arguments
  source $TEMPD/libtest/part.sh
  set -- "${OLDARGS[@]}"
  rm -fr $TEMPD/libtest
}

# == TESTS ==
# Regression: `jj op show -p` only shows "interesting" revisions since jj-0.40.0,
# jj-fzf must pass `--show-changes-in=all()` to keep the oplog undo indicators complete.
test-oplog-info-all-changes()
(
  cd_new_repo
  # Restrict interesting revisions to @, so the describe op below is elided
  # unless `--show-changes-in=all()` is in effect.
  jj config set --repo revsets.op-diff-changes-in '@' >$DEVERR 2>&1
  mkcommits A B
  jj --no-pager describe -m 'A updated' A >$DEVERR 2>&1 # modify @-
  OPID=$(jj op log --no-graph -T 'id ++ " " ++ description.first_line()' |
	   grep -m1 ' describe ' | awk '{print $1}' | cut -c1-20)
  test -n "$OPID" || die "failed to locate describe operation"
  lib_source oplog.sh '1,/^export -f jjfzf_op_info$/p'
  OUT="$(JJFZF_COLOR= jjfzf_op_info "$OPID")"
  # The `Modified commit description:` hunk is only emitted by `jj op show -p`
  # when `--show-changes-in=all()` is passed; without it, @- changes are ignored.
  grep -q 'Modified commit description' <<<"$OUT" ||
    die "oplog info omitted changes of a non-@ commit"
)
TESTS+=( test-oplog-info-all-changes )

# Regression: jj-0.42 removed `jj describe --edit`, jj-fzf must use --editor
# and apply the user editor (JJ_EDITOR) through the editor.sh wrapper.
test-describe-editor()
(
  cd_new_repo
  mkcommits A
  cat > $TEMPD/edit-msg.sh <<\EOF
#!/usr/bin/env bash
printf 'edited by test editor\n' > "$1"
EOF
  chmod +x $TEMPD/edit-msg.sh
  JJ_EDITOR=$TEMPD/edit-msg.sh jj-fzf describe A >$DEVERR 2>&1
  test "$(jj --ignore-working-copy log --no-graph -T description -r A)" == 'edited by test editor' ||
    die "jj-fzf describe did not apply editor changes (jj-0.42 --editor compat)"
  # an editor leaving the message unchanged must not modify it
  JJ_EDITOR=true jj-fzf describe A >$DEVERR 2>&1
  test "$(jj --ignore-working-copy log --no-graph -T description -r A)" == 'edited by test editor' ||
    die "jj-fzf describe modified the description on unchanged editor input"
)
TESTS+=( test-describe-editor )

# Regression: jjfzf_config_quote with given prefix/postfix must surround the
# quoted string, not place the prefix/postfix inside the double quotes.
test-config-quote()
(
  cd_new_repo
  lib_source setup.sh '1,$p' # whole file: setup.sh is a pure library
  OUT="$(printf 'a"b\\c'\''d' | jjfzf_config_quote pre post)"
  test "$OUT" == "''' pre\"a\\\"b\\\\c\\x27d\"post '''" ||
    die "jjfzf_config_quote: unexpected quoting: $OUT"
  # jj must accept the produced TOML (round trip through jj config parsing)
  printf 'msg with "quotes" \\ and apostrophe '\'' char' > $TEMPD/msg.txt
  {
    echo '[template-aliases]'
    echo -n 'default_commit_description='
    jjfzf_config_quote '' '' < $TEMPD/msg.txt
  } > $TEMPD/desc.toml
  jj --config-file $TEMPD/desc.toml config get template-aliases.default_commit_description |
    grep -qF '"msg with \"quotes\" \\ and apostrophe \x27 char"' ||
    die "jjfzf_config_quote produced invalid TOML"
  # Round trip must reproduce the original message: `config get` returns the raw
  # TOML value (escapes intact inside the ''' literal string), so evaluate the
  # alias as a template, which decodes the \" / \\ / \x27 escapes.
  jj --config-file $TEMPD/desc.toml --no-pager log -r @ -T 'default_commit_description' |
    grep -qF "$(cat $TEMPD/msg.txt)" ||
    die "jjfzf_config_quote: TOML round trip altered the message")
TESTS+=( test-config-quote )

# Regression: bookmark startup position must match the ¸-delimited bookmark
# name field, not plain word matches in commit descriptions.
test-bookmarks-start-position()
(
  cd_new_repo
  mkcommits A
  # bookmark 'beta' pointing at a commit whose description contains 'main'
  jj --no-pager new -m 'update main branch' >$DEVERR 2>&1 && jj bookmark set beta -r @ >$DEVERR 2>&1
  jj --no-pager new -m 'main work' >$DEVERR 2>&1 && jj bookmark set main -r @ >$DEVERR 2>&1
  lib_source bookmarks.sh '1,/^export -f jjfzf_bookmark_list0$/p'
  jjfzf_bookmark_list0
  # emulate the start position lookup (lib/bookmarks.sh "Start Position")
  POS=$(sed -r 's/\x1b\[[0-9;]*[mK]//g' $JJFZF_TEMPD/bm_refs.lst |
	  grep -m 1 -n '¸main¸' | cut -d: -f1)
  test -n "$POS" || die "bookmark 'main' not found in bookmark list"
  LINE=$(sed -n "${POS}p" $JJFZF_TEMPD/bm_refs.lst)
  grep -Eq '^[^¸]+¸main¸' <<<"$LINE" ||
    die "start position did not land on the 'main' bookmark entry"
  # ensure the regression scenario is live: plain word matching would land
  # on the earlier 'beta' line with its 'update main branch' description
  BADPOS=$(sed -r 's/\x1b\[[0-9;]*[mK]//g' $JJFZF_TEMPD/bm_refs.lst |
	    grep -m 1 -n '\bmain\b' | cut -d: -f1)
  test "$BADPOS" != "$POS" ||
    die "no regression scenario: word match == delimiter match"
)
TESTS+=( test-bookmarks-start-position )

# == RUN ==
temp_dir
for TEST in "${TESTS[@]}" ; do
  $TEST
  printf '  %-7s %s\n' OK "$TEST"
done
tear_down
