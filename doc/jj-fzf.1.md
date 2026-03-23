% JJ-FZF(1)	| jj-fzf Manual Page

# NAME
  jj-fzf - Terminal interface for the `jj` version control system based on fzf

# SYNOPSIS
  **jj-fzf** [*OPTIONS*] \
  **jj-fzf** *COMMAND* [*ARGUMENTS*...]

# OPTIONS

  **--version**
  : Print version information.

  **--help**
  : Print brief usage information.

  **--man**
  : Browse this man page.

  **--no-preview**
  : Hide the preview window.

  **-c**, **+c**
  : Start as a commit picker, **-c** picks a single commit, **+c** picks multiple commits.

  **-r**, **+r**
  : Start as a revision (change ID) picker, **-r** picks a single revision, **+r** picks multiple revisions.

  **-s**
  : Start as a revset picker, returns the edited / current revset expression.

# DESCRIPTION

  **jj-fzf** is a text-based user interface for the `jj` version control system,
  built on top of the fuzzy finder `fzf`. **jj-fzf** centers around the `jj log`
  graph view, providing previews of `jj diff` or `jj evolog` for each revision.
  Several key bindings are available for actions such as squashing, swapping,
  rebasing, splitting, branching, committing, or abandoning revisions. A
  separate view for the operations log, `jj op log`, allows fast previews of
  diffs and commit histories of past operations and enabling undo of previous
  actions. The available hotkeys are displayed on-screen for easy
  discoverability. The commands and key bindings can also be found in the man
  page (displayed with `jj-fzf --man`) and are documented in the **jj-fzf** wiki.

## JJ LOG VIEW

  The `jj log` view in **jj-fzf** displays a list of revisions with commit
  information on each line. Each entry contains the following elements:

  `@`
  : Marks the working copy

  `○`
  : Indicates a mutable commit, a commit that has not yet been pushed

  `◆`
  : Indicates an immutable commit, that has been pushed or tagged

  `Change ID`
  : The (mostly unique) identifier to track this change across commits

  `Username`
  : The abbreviated username of the author

  `Date`
  : The day when the commit was authored

  `Commit ID`
  : The unique hash for this commit and its meta data

  `Refs`
  : Any tags or bookmarks associated with the revisions

  `Message`
  : A brief description of the changes made in the revisions

  Note, in `jj`, the set of immutable commits can be configured via
  the `revset-aliases."immutable_heads()"` config setting.

## PREVIEW WINDOW

  The preview window on the right displays detailed information for the
  currently selected revisions. The meaning of the preview items are as follows:

  **First Line**
  : The `jj log -T builtin_log_oneline` output for the selected commit

  **Commit ID**
  : The unique identifier for the Git commit

  **Change ID**
  : The `jj` revision identifier for this revisions

  **Parents**
  : A list of parent revisions (more than one for merge commits)

  **Tags** / **Bookmarks**
  : Tags and bookmarks (similar to branch names) for this revisions

  **Author**
  : The author of the revision, including name and email, timestamp

  **Committer**
  : The committer, including name and email, timestamp

  **Message**
  : Detailed message describing the changes made in the revision

  **File List**
  : A list of files modified by this revision

  **Diff**
  : A `jj diff` view of changes introduced by the revision

# COMMAND EXECUTION

  For all repository-modifying commands, **jj-fzf** prints the actual `jj` commands
  executed to stderr. The output aids users in learning how to use `jj` directly
  to achieve the desired effects. This output can also be useful when debugging and
  helps users determine which actions they might wish to undo.

  Most commands can also be run directly from the command line. The supported
  commands are the same as the key bindings listed below (e.g., `abandon`,
  `squash`, etc.). The arguments are typically one or more commit or change IDs.

# KEY BINDINGS

  Most **jj-fzf** commands operate on the current revision under the fzf pointer
  and/or a set of previously selected revisions (use _Tab_ or _Shift-Tab_ to change
  selection). All dialogs can be closed at any point with _Escape_.
  The layout of the preview window can be adjusted with _F11_.

## KEY BINDINGS FOR JJ-FZF
   
!!!! ./jj-fzf --help-bindings

## KEY BINDINGS FOR BOOKMARKS & TAGS

  The "Bookmarks & Tags" dialog (_Alt-B_) displays bookmarks and their states.
  Since `jj` tracks bookmarks locally and on remotes (like `@origin`), a
  bookmark can exist in several states. The dialog simplifies this by showing a
  single, most significant state for each bookmark and only takes `@origin`
  as remote into consideration:

  `[Pending]`
  : The bookmark exists locally and is tracking a remote bookmark that has yet to be pushed.

  `[Deleted]`
  : The bookmark is deleted locally but is still tracked on a remote, the deletion still needs to be pushed to the remote.

  `[Conflicted]`
  : The local and remote bookmarks have diverged and need to be resolved by moving the bookmark.

  `[Tracked]`
  : The bookmark exists locally and is tracking the bookmark at the remote.

  `[Untracked]`
  : The bookmark exists locally and on a remote, but is not tracked.

  `[Local]`
  : The bookmark exists only locally, but not on a remote.

  `[Remote]`
  : The bookmark exists only on a remote.

  Consequently, only a subset of the key bindings will have an effect on bookmarks in certain states.
   
!!!! lib/bookmarks.sh --help-bindings

## KEY BINDINGS FOR THE EVOLOG
   
!!!! lib/evolog.sh --help-bindings

## KEY BINDINGS FOR THE OPERATION LOG
   
!!!! lib/oplog.sh --help-bindings

## KEY BINDINGS FOR CHANGE PARENTS
   
!!!! lib/reparent.sh --help-bindings

## KEY BINDINGS FOR REBASE
   
!!!! lib/rebase.sh --help-bindings

# CONFIGURATION

  The default set of revisions for the main **jj-fzf** log view is configured via
  `jj-fzf.log_revset`, with a fallback to `revsets.log` (the standard `jj log`
  revset). To use a different revset, type it into the **jj-fzf** query field which
  will live update the log view. To persist the revset in the repository's local
  `jj-fzf.log_revset` configuration, press _Alt-Enter_.

  The default commit display template for the log view is configured via
  `jj-fzf.log_template`, with a fallback to `templates.log` (the standard `jj log`
  template). For example, to configure one-line display as the default, use:
  `jj config set --user jj-fzf.log_template builtin_log_oneline`

  The `jj-fzf.log-mode` configuration setting stores whether each commit in the
  log view also includes a two letter file type diff.

  The configuration setting `jj-fzf.show-keys` determines if an **fzf** header
  is shown that displays active key bindings.
  Pre-generated commit messages for `jj describe` are provided as a temporary config
  value in `template-aliases.default_commit_description`.

  If an `aliases.push` command is configured to run `jj-pre-push` and the
  workspace contains a `.pre-commit-config.yaml` file, pushing will use
  `jj push` so any **pre-commit** hooks are executed first.


## LLM CONFIGURATION
!!!! lib/gen-message.py --llm-help

# SEE ALSO

  For screencasts, workflow suggestions or feature requests, visit the
  **jj-fzf** project page at: \
  https://github.com/tim-janik/jj-fzf

  For revset expressions, see: \
  https://martinvonz.github.io/jj/latest/revsets

  For using `default_commit_description` in `draft_commit_description` customization, see: \
  https://jj-vcs.github.io/jj/latest/config/#default-description

  For **pre-commit** hooks via `jj-pre-push`, see: \
  https://github.com/acarapetis/jj-pre-push
