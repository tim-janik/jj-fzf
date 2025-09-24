% JJ-FZF(1)	| jj-fzf Manual Page

# NAME
  jj-fzf - Terminal interface for the `jj` version control system based on fzf

# SYNOPSIS
  **jj-fzf** [*COMMAND*] [*ARGUMENTS*...]

# DESCRIPTION

  **jj-fzf** is a text-based user interface for the `jj` version control system,
  built on top of the fuzzy finder `fzf`. **jj-fzf** centers around the `jj log`
  graph view, providing previews of `jj diff` or `jj evolog` for each revision.
  Several key bindings are available for actions such as squashing, swapping,
  rebasing, splitting, branching, committing, or abandoning revisions. A
  separate view for the operations log, `jj op log`, allows fast previews of
  diffs and commit histories of past operations and enabling undo of previous
  actions. The available hotkeys are displayed on-screen for easy
  discoverability. The commands and key bindings can also be displayed with
  `jj-fzf --help` and are documented in the **jj-fzf** wiki.

## JJ LOG VIEW

  The `jj log` view in **jj-fzf** displays a list of revisions with commit
  information on each line. Each line contains the following elements:

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

  **Change ID**
  : The `jj` revision identifier for this revisions

  **Commit ID**
  : The unique identifier for the Git commit

  **Refs**
  : Tags and bookmarks (similar to branch names) for this revisions

  **Immutable**
  : A boolean indication for immutable revisions

  **Parents**
  : A list of parent revisions (more than one for merge commits)

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
  to achieve the desired effects. It can also be useful when debugging and helps
  users determine which actions they might wish to undo. Most commands can also
  be run via the command line, using: \
  `jj-fzf <command> <revision>`

# KEY BINDINGS

  Most **jj-fzf** commands operate on the current revision under the fzf pointer
  and/or a set of previously selected revisions (use _Tab_ or _Shift-Tab_ to change
  selection). All dialogs can be closed at any point with _Escape_.

## KEY BINDINGS FOR JJ-FZF
   
!!!! ./jj-fzf --help-bindings

## KEY BINDINGS FOR BOOKMARKS & TAGS
   
!!!! lib/bookmarks.sh --help-bindings

## KEY BINDINGS FOR THE OPERATION LOG
   
!!!! lib/oplog.sh --help-bindings

## KEY BINDINGS FOR REBASE
   
!!!! lib/rebase.sh --help-bindings

## KEY BINDINGS FOR CHANGE PARENTS
   
!!!! lib/reparent.sh --help-bindings

# CONFIGURATION

  The default revset for the main **jj-fzf** log view is configured via `jj-fzf.log_revset`.
  When a new value is stored, it is set as a configuration setting local to the repository.
  The configuration setting `jj-fzf.show-keys` determines if an **fzf** header is shown that displays active key bindings.
  Pre-generated commit messages for `jj describe` are provided as a temporary config value in
  `template-aliases.default_commit_description`.

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
