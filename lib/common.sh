#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

# == Install Path ==
[[ "${BASH_SOURCE[0]}" = "${BASH_SOURCE[0]#/}" ]] &&
  ABSPATHLIB="$PWD/${BASH_SOURCE[0]}" || ABSPATHLIB="${BASH_SOURCE[0]}"
ABSPATHLIB="${ABSPATHLIB%/*}"

# == JJFZF_PRIVATE ==
# Read git.private-commits to find a "private" revset name that alters preview rendering
JJFZF_PRIVATE="$(jj config get --ignore-working-copy --no-pager git.private-commits 2>/dev/null)" &&
  [[ "$JJFZF_PRIVATE" =~ ^[.a-z_()-]+$ ]] ||
    JJFZF_PRIVATE=''	# only supports unquoted revset names

# == JJ_FZF_SHOWDETAILS ==
# extended version of builtin_log_detailed; https://github.com/martinvonz/jj/blob/main/cli/src/config/templates.toml
JJ_FZF_SHOWDETAILS='
concat(
  builtin_log_oneline,
  "Change ID: " ++ self.change_id() ++ "\n",
  "Commit ID: " ++ commit_id ++ "\n",
  "Flags:     ", separate(" ",
    if(immutable, label("node immutable", "immutable")),
    if(hidden, label("hidden", "hidden")),
    if(divergent, label("divergent", "divergent")),
    if(conflict, label("conflict", "conflict")),
    '"${JJFZF_PRIVATE:+ if(self.contained_in('$JJFZF_PRIVATE') && !immutable, label('committer', 'private')), }"'
  ) ++ "\n",
  surround("Refs:      ", "\n", separate(" ", local_bookmarks, remote_bookmarks, tags)),
  "Parents:  " ++ self.parents().map(|c| " " ++ c.change_id()) ++ "\n",
  "Author:    " ++ format_detailed_signature(author) ++ "\n",
  "Committer: " ++ format_detailed_signature(committer)  ++ "\n\n",
  indent("    ",
    coalesce(description, label(if(empty, "empty"), description_placeholder) ++ "\n")),
  "\n",
)'

# == Hex number patterns ==
BIGHEXPAT='\b([0-9a-f]{18,})\b'			# long hexadecimal pattern
# Find any hex pattern, 7 digits or longer
HEX7PAT='\ ([0-9a-f]{7,})\ '			# space enclosed hexadecimal pattern

# == Oneline ==
# TODO: have a JJ command that allows to query for the builtin_log_oneline template
# Copied from jj/cli/src/config/templates.toml in jj-0.33, changes:
# - print commit.commit_id before tags, etc
# - print long form commit id (24 characters)
ONELINE_COMMIT_BIGHEX='concat(
if(commit.root(),
  format_root_commit(commit),
  label(
    separate(" ",
      if(commit.current_working_copy(), "working_copy"),
      if(commit.immutable(), "immutable", "mutable"),
      if(commit.conflict(), "conflicted"),
    ),
    concat(
      separate(" ",
        format_short_change_id_with_hidden_and_divergent_info(commit),
        format_short_signature_oneline(commit.author()),
        format_timestamp(commit_timestamp(commit)),
        commit.commit_id().short(20),
        commit.bookmarks(),
        commit.tags(),
        commit.working_copies(),
        if(commit.git_head(), label("git_head", "git_head()")),
        if(commit.conflict(), label("conflict", "conflict")),
        if(config("ui.show-cryptographic-signatures").as_boolean(),
          format_short_cryptographic_signature(commit.signature())),
        if(commit.empty(), label("empty", "(empty)")),
        if(commit.description(),
          commit.description().first_line(),
          label(if(commit.empty(), "empty"), description_placeholder),
        ),
      ) ++ "\n",
    ),
  )
) )'

# == Diff rendering ==
# Show commit diff according to jj-fzf.diff-mode
jj_show_diff()
{
  local COLOR && [[ " $* " =~ --color=always ]] && COLOR=--color=always || COLOR=--color=never
  # Use git-diff (for --git and --word-diff) which has better heuristics for informative hunk headers than jj-0.33
  case "$(jj --no-pager --ignore-working-copy config get jj-fzf.diff-mode 2>/dev/null || true)" in
    diff-b)
      export EXECTOOL_CMD='git -P diff --no-index --diff-algorithm=histogram -b '"$COLOR"
      jj show --no-pager --ignore-working-copy "$@" --tool "$ABSPATHLIB/exectool.sh"
      ;;
    word-b)
      export EXECTOOL_CMD='git -P diff --no-index --diff-algorithm=histogram -b --word-diff '"$COLOR"
      jj show --no-pager --ignore-working-copy "$@" --tool "$ABSPATHLIB/exectool.sh"
      ;;
    *)
      jj show --no-pager --ignore-working-copy "$@"
      ;;
  esac
}
