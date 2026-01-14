#!/usr/bin/env bash
# This Source Code Form is licensed MPL-2.0: http://mozilla.org/MPL/2.0

# == Install Path ==
[[ "${BASH_SOURCE[0]}" = "${BASH_SOURCE[0]#/}" ]] &&
  ABSPATHLIB="$PWD/${BASH_SOURCE[0]}" || ABSPATHLIB="${BASH_SOURCE[0]}"
ABSPATHLIB="${ABSPATHLIB%/*}"

# == JJFZF_PRIVATE ==
JJFZF_PRIVATE_CONFIG=""
# Try to read a revset name from git.private-commits, then add a marker "🌟" to all "private" commits in logs
if JJFZF_PRIVATE="$(jj config get --ignore-working-copy --no-pager git.private-commits 2>/dev/null)" &&
    [[ "$JJFZF_PRIVATE" =~ ^[.a-z_()-]+$ ]] ; then
  JJFZF_PRIVATE_CONFIG="--config=template-aliases.'format_short_commit_id(id)'='format_short_id(id) ++ if(self.contained_in(\"$JJFZF_PRIVATE\") && ! immutable, label(\"committer\", \" 🌟\"))'"
else
  JJFZF_PRIVATE=''	# only supports unquoted revset names
fi
export JJFZF_PRIVATE_CONFIG JJFZF_PRIVATE

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
