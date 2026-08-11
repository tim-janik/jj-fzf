## JJ-FZF 0.42.0 - 2026-08-11

### Added:
* Alt-L: start interactive conflict resolution with `jj resolve`
* Ctrl-R: rewrites the change ID via `jj metaedit --update-change-id`
* Added feature and regression tests
* Ctrl-O: Keep showing *all* oplog changes in jj-0.40 and later

### Changed:
* Support `jj describe --editor`, since jj-0.42 removed `jj describe --edit`
* The jj download URL was updated to: https://github.com/jj-vcs/jj/
* Error pause delays are now configurable via the $JJFZF_ERROR_DELAY
* Documentation links are updated to use jj-vcs.dev
* The commit message prompt now requests 'keep commit wording minimal'

### Fixed:
* Require GNU Make >= 4.0, inspired by Bryan O'Sullivan (@bos), fixes #21
* Bookmark startup position now matches bookmark names correctly with proper delimiters
* Filter multiple Gemma/Qwen thinking tag formats in commit message generation

### Breaking:
* This release requires jj-0.42.0
* This release requires fzf-0.67.0
* This release requires GNU Make-4.0
* This release requires bash-5.1

Thanks to everyone who gave feedback and
helped to make this release happen!


## JJ-FZF 0.38.0 - 2026-03-24

### Added:
* Experimental: automatic positioning on @ upon jj-fzf start

### Changed:
* Ctrl-U: preserve selection when clearing the line
* Update commit message generation prompt to work with a variety and smaller models
* Update man page documentation to include F11 preview toggle
* Introduce `jjfzf_strquote` helper function (for `jj split`)

### Fixed:
* Use `dd skip=1` instead of iseek to support SFX on ubuntu 22.04
* Fix quoting and order when commit splitting with `jj split`
* Refresh status after opening full history view

### Breaking:
* This release requires jj-0.38.0
* This release requires fzf-0.67.0

Thanks to everyone who gave feedback and
helped to make this release happen!


## JJ-FZF 0.37.0 - 2026-01-25

### Added:
* Ctrl-T now toggles multi-line file type display in the log view
* Commit message generation now uses the latest Gemini flash model
* The commit log now supports scrolling with Ctrl-↑↓
* The preview now supports scrolling with Alt-↑↓ and shows more lines
* Ctrl-W now allows to toggle word diff format
* Ctrl-B now support cycling through whitespace-ignore options for diffs
* Rebase now has support for word-level merging via Ctrl-W
* Rebase with duplicate now supports --ignore-immutable via Alt-I
* Alt-J now injects the diff of a revision (not the entire content tree)
* Ctrl-P will now use `jj push` when configured as an alias for `jj-pre-push`
  to support pre-commit hooks via jj-pre-push, see:
  https://github.com/acarapetis/jj-pre-push

### Changed:
* Generated commit messages are now wrapped after 100 columns
* The prompt and context for commit message generation was improved
* The `jj tag` sub commands are now used for tag creation and deletion
* The Bookmarks dialog can now show bookmarks in `Pending` state
  when not yet pushed to @origin
* Instead of forced pushing new bookmarks, we now rely on `jj bookmark track`
* The preview home/end shortcuts are now Alt-←→ instead of Alt-< Alt->
* The $EDITOR variable is now run without quoting to support arguments
* Bookmarks and tags now use the exact:name syntax from jj
* Bookmark (and tag) listing got faster by running jj list commands in parallel
* The handling of `jj status` (for snapshots) was improved to show errors
* A set of .pre-commit-config.yaml hooks now monitors code quality

### Fixed:
* Describe doesn't work with complex EDITOR command	- #25
* JJ is changing internal templates - #23

### Removed:
* Some obsolete templates and helper scripts got removed

### Breaking:
* This release requires jj-0.37.0 (for bookmark and tag handling)
* This release requires fzf-0.67.0 (improves key bindings)

Thanks to everyone who gave feedback regarding the rewrite and
helped to make this release happen!


## JJ-FZF 0.34.0 - 2025-10-02

### Added:

* In the last month, jj-fzf underwent a complete rewrite. The new version has
  out of the box support for running jj commands with multiple revisions and
  extends utilization of new jj and fzf features.

* All key binding commands now operate on a change_id or a list thereof.

* In case of divergent commits, an fzf list entry now expands to a commit_id,
  which also means pretty much all commands now handle divergent commits.

* Inject will now copy the author, timestamp and message into the new commit.

* The oplog now combines the operation show, diff and historic log views.

* The default set of revisions for the jj-fzf log list is now
  `jj-fzf.log_revset` with a fallback of `revsets.log` (the standard jj log
  revset). To use a different revset with jj-fzf, type the revset into the
  query field for live revset updates. To persist the revset in the repo
  config under `jj-fzf.log_revset`, hit Alt-Enter.

* The default commit display template for the jj-fzf log list is now
  `jj-fzf.log_template` with a fallback of `templates.log` (the standard jj
  log template). In order to configure jj-fzf for one line display, use:
  	`jj config set --user jj-fzf.log_template builtin_log_oneline`

* Alt-B now presents a dialog to create, move, delete or track bookmarks and
  delete tags. The former bookmark deletion under Alt-D has been merged into
  Alt-B.

* Alt-Q will now squash changes from selected revisions into the revision
  under the pointer, or into the parent if no revisions are selected.

* Alt-S now starts `jj restore --interactive` and restores files from a single
  selected revision into the revision under the pointer, or into the parent
  if no revisions are selected.

* Ctrl-D will pre-generate a commit message for merge commits only. For normal
  commit messages, use `templates.draft_commit_description` instead. If you
  depend on the messages of previous jj-fzf versions, consider the hint printed
  out by: `lib/draft.sh --hint`
  See also: https://www.jj-vcs.dev/latest/config/#default-description

* Ctrl-F now toggles between the fzf finder and live revset editing.
  There is no key binding replacement for the old 'file-editor', just run
  `jj edit` or `jj new` on an old commit and open the file of interest.

* Ctrl-L will now either show the history up to a single selected revision,
  or for the selected (multiple) revisions only.

* Ctrl-V is the new key binding for the evolution log browser.

* An LLM can be used to generate commit messages with the Ctrl-S key binding.
  The generated message is provided to `jj describe` as a config value in
  `template-aliases.default_commit_description`.
  See the manual page for LLM configurations via environment variables.

* Sub-dialogs like rebase, reparent or even bookmarks should now retain the
  commit (bookmark) pointer position.

* An optimal column-major text layout algorithm now presents the key bindings.

* The CI now runs and validates a selected set of screencasts.

* New -c +c -r +r -s options allow using jj-fzf as a picker for 1 or many
  commits, 1 or many revisions or a revset expression.

### Changed:

* Bookmarks are now display with a simplified state that indicates:
  Deleted / Conflicted / Tracked / Untracked / Local Remote

* On startup `jj-fzf` now offers revset editing in the query field.
  Use Ctrl-F for the fzf filter.

* When running `jj describe` a $EDITOR wrapper is used that prevents jj
  from accepting an auto-generated default description as message.

* Running a command from jj-fzf switches back from the alternative screen
  and will reload the entire `jj log` output before returning. This may
  take longer than the async log loading in previous versions, but it
  allows fzf to track and keep the current pointer position.

### Fixed:

* The man page now list key bindings for jj-fzf and all sub-commands.

* A new configuration section in the man page describes config keys that
  jj-fzf makes use of, as well as how to configure LLM usage.

* The `push` command now avoids querying if nothing changed.

### Breaking:

* The minimum supported fzf version is now 0.65.2.

* This release requires jj-0.34.0

* Commands missing from the rewrite:
  - Alt-V: vivifydivergent - use `jj metaedit --update-change-id`
  - Ctrl-A: author-reset   - use `jj metaedit --update-author`
  - Ctrl-I: diff           - should be handled by Ctrl-L now
  - Ctrl-V: gitk           - not provided anymore
  - Ctrl-W: wb-diff        - toggle ±b ±w for diff

* A number of changes listed above could be considered breaking old
  workflows. Please provide feedback in Github discussions or IRC
  if you encounter regressions or miss important features.

Thanks to everyone who gave feedback regarding the rewrite and
helped to make this release happen!


## JJ-FZF 0.33.0 - 2025-09-11

### Added:
* New preflight.sh script dedicated to dependency handling
* Added version.sh to support Github "Source code" archives
* Added self extracting jj-fzf.sfx script to release artifacts
* Added manual page jj-fzf.1.gz to release artifacts
* Added contrib/jj-foreach.sh to run shell command for each commit in a revset
* Added option to contrib/jj-foreach.sh to not affecting descendants
* Alt-J: inject selected revision as historic commit before @
* Documented F5 and F11 keybindings

### Breaking:
* This release requires jj-0.33.0
* This release is the last one to support fzf 0.44.1, future release
  will depend on more recent fzf versions
* Upon start, fzf will now wait for `jj log` to finish before display; if this
  turns out too slow for some repos, please file an issue and request --async
* Instead of enforcing gsed use, preflight.sh now defines an `sed()` function
  that proxies `gsed` if needed. Please file an issue if sed problems remain

### Changed:
* Pushing to a remote will now also push deleted bookmarks
* Preserve history when deleting tags or bookmarks
  (enforces git.abandon-unreachable-commits=false during deletion)
* Added cursor down to swap-commits to follow swapped commit
* Moved preview and helper into library files (speeds up previews)
* Undo/redo operations in jj-fzf now use jj's built-in commands
* Use `jj-fzf oplog` to display the undo stack with ⋯ undo step markers
* Renamed oplog and oplog-browser commands

### Fixed:
* Fixed evolog preview and evolog paging (was broken since jj-0.30)
* Fixed outdated uses of `jj --config-toml`
* Fixed broken Github jj-fzf links
* Fixed lacking DESTDIR for make (un)install

### Removed:
* Removed unnecessary `all:` prefix in jj revset expressions
* Removed unused command / key binding for undo marker reset


## JJ-FZF 0.32.0 - 2025-08-14

### Added:
* Ctrl-W: Added way to toggle between various diff formats
* Alt+M: New multi-select mode, use TAB to select multiple commits
* Added multi-mode support for abandon, backout, duplicate, squash, rebase
* Added `make distcheck`, always check in CI
* Added check for jj-fzf --help
* Added installcheck rule
* Added separate manual page
* Added file summary to oplog history
* Added scripts to automate releases
* Added contirb/suspend-with-shell.el to run jj-fzf from emacs, see:
  https://testbit.eu/2025/jj-fzf-in-emacs

### Breaking:
* Depend on jj-0.32.0
* Changed Alt-N to run new-after with --no-edit
* Preserve PWD in subshells if possible (present)
* Remove unused 'merging' command

### Changed:
* To install, run `make all install`
* To run all checks, run `make all check install installcheck`
* Builds require GNU Make
* Moved version checks for all tool dependencies into Makefile
* Use /usr/bin/env to find bash
* Undeprecate Alt-S: restore-file from selected revision
* Build man page, use a man page browser for `jj-fzf --help`
* Fetch version information from Git
* Automatically run CI for PRs and tags
* Introduced pandoc dependency for man builds

### Fixed:
* Fixed installations not working in non-jj repos
* Fixed --version not working outside a jj repo


## JJ-FZF 0.25.0 - 2025-01-23

### Added:
* Fzflog: use jjlog unless jj-fzf.fzflog-depth adds bookmark ancestry
* Use author.email().local(), required by jj-0.25
* Absorb: unconditionally support absorb
* Evolog: add Alt-J to inject a historic commit
* Evolog: add Enter to browse detailed evolution with patches
* Add Ctrl-T evolog dialog with detailed preview
* Add content-diff to jj describe
* Add ui.default-description to commit messages
* Display 'private' as a flag in preview
* Add jj-am.sh to apply several patches in email format
* Add jj-undirty.el, an elisp hook to auto-snapshot after saving emacs buffers

### Changed:
* Always cd to repo root, so $PWD doesn't vanish
* Adjust Makefile to work with macOS, #6
* Merging: prefer (master|main|trunk) as UPSTREAM
* Make sure to use gsed
* Check-gsed: show line numbers
* Echo_commit_msg: strip leading newline from ui.default-description
* Flags: display hidden, divergent, conflict
* Cut off the preview after a few thausand lines
* Split-files: try using `jj diff` instead of `git diff-tree`
* Use JJ_EDITOR to really override th JJ editor settings
* Honor the JJ_EDITOR precedence
* Show content diff when editing commit message
* Adjust Bookmark, Commit, Change ID descriptions
* Display 'immutable' as a flag in preview
* Fzflog: silence deprecation warnings on stderr
* Include fzflog error messages in fzf input if any
* Unset FZF_DEFAULT_COMMAND in subshells

### Fixed:
* Fix RESTORE-FILE title
* Properly parse options --help, --key-bindings, --color=always
* Echo_commit_msg: skip signoff if no files changed

### Deprecation:
* Deprecate Alt-S for restore-file
* Deprecate Ctrl-V for gitk

### Breaking:
* Depend on jj-0.25.0
* Op-log: use Alt-J to inject an old working copy as historic commit
* Alt-Z: subshells will always execute in the repository root dir

### Contributors

Thanks to everyone who made this release happen!

* Tim Janik (@tim-janik)
* Douglas Stephen (@dljsjr)


## JJ-FZF 0.24.0 - 2024-12-12

### Added:
* Added Alt-O: Absorb content diff into mutable ancestors
* Added `jj op show -p` as default op log preview (indicates absorbed changes)
* Added marker based multi-step undo which improved robustness
* Op-log: Added restore (Alt-R), undo memory reset (Alt-K) and op-diff (Ctrl-D)
* Added RFC-1459 based simple message IRC bot for CI notifications
* Added checks for shellcheck-errors to CI
* Creating a Merge commit can now automatically rebase (Alt-R) other work
* Added duplicate (Alt-D) support to rebase (including descendants)
* Added auto-completion support to bookmarks set/move (Alt-B)
* Reparenting: added Alt-P to simplify-parents after `jj rebase`
* Implemented faster op log preview handling
* New config `jj-fzf.fzflog-depth` to increase `fzflog` depth
* Ctrl-I: add diff browser between selected revision and working copy
* F5: trigger a reload (shows concurrent jj repo changes)
* Support rebase with --ignore-immutable via Alt-I
* Implement adaptive key binding display (Alt-H)
* Ctrl-H: show extended jj-fzf help via pager
* Broadened divergent commit support: squash-into-parent, describe, log
* Started adding unit tests and automated unit testing in CI
* Introduced Makefile with rules to check, install, uninstall

### Breaking:
* Depend on jj-0.24.0 and require fzf-0.43.0
* Removed Alt-U for `jj duplicate`, use rebase instead: Alt-R Alt-D
* Assert that bash supports interactive mode with readline editing
* Check-deps: check dependencies before installing
* Rebase: rename rebasing to `jj-fzf rebase`
* Rebase: apply simplify-parents to the rebased revision only
* Rename 'edit' (from 'edit-workspace')
* Rename revset-assign → revset-filter
* Op-log: Ctrl-S: Preview "@" at a specific operation via `jj show @`
  (formerly Ctrl-D)

### Changed:
* Avoid JJ_CONFIG overrides in all places
* Support ui.editor, ui.diff-editor and other settings
* Squash-into-parent: use `jj new -A` to preserve change_id
* Jump to first when reparenting and after rebase
* Ctrl-P: jj git fetch default remote, not all
* Support deletion of conflicted bookmarks
* Line Blame: skip signoff and empty lines

### Fixed:
* Avoid slowdowns during startup
* Fixed some cases of undesired snapshotting
* Lots of fixes and improvements to allow automated testing
* Minor renames to make shellcheck happy
* Log: Ctrl-L: fix missing patch output
* Ensure `jj log` view change_id width matches jj log default width


## JJ-FZF 0.23.0 - 2024-11-11

Development version - may contain bugs or compatibility issues.

### Breaking:
* Depend on jj-0.23.0
* Remove experimental line-history command

### Added:
* Support 'gsed' as GNU sed binary name
* Support line blame via: jj-fzf +<line> <gitfile>
* Support '--version' to print version
* Define revset `jjlog` to match `jj log`
* Define revset `fzflog` as `jjlog` + tags + bookmarks
* Display `jj log -r fzflog` revset by default
* Store log revset in --repo `jj-fzf.revsets.log`
* Ctrl-R: reload log with new revset from query string

### Changed:
* Require 'gawk' as GNU awk binary
* Ctrl-Z: use user's $SHELL to execute a subshell
* Shorten preview diffs with --ignore-all-space
* Show error with delay after failing jj commands
* Restore-file: operate on root relative file names
* Split-files: operate on root relative file names
* Fallback to @ if commands are called without a revision
* Allow user's jj config to take effect in log display
* Unset JJ_CONFIG in Ctrl+Z subshell
* Rebase: Alt-P: toggle simplify-parents (off by default)
* Reduce uses of JJ_CONFIG (overrides user configs)

### Fixed:
* Split-files: use Git diff-tree for a robust file list
* Ensure that internal sub-shell is bash to call functions, #1
* Clear out tags in screencast test repo
* Various smaller bug fixes
* Add missing --ignore-working-copy in some places
* Fix git_head() expression for jj-0.23.0

### Removed:
* Remove unused color definitions
* Skip explicit jj git import/export statements
* Skip remove-parent in screencast, use simplify-parents

### Contributors

Thanks to everyone who made this release happen!

* Török Edwin (@edwintorok)
* Tim Janik (@tim-janik)


## JJ-FZF 0.22.0 - 2024-11-05

First project release, depending on jj-0.22.0, including the following commands:
- *Alt-A:* abandon
- *Alt-B:* bookmark
- *Alt-C:* commit
- *Alt-D:* delete-refs
- *Alt-E:* diffedit
- *Alt-F:* split-files
- *Alt-I:* split-interactive
- *Alt-K:* backout
- *Alt-L:* line-history
- *Alt-M:* merging
- *Alt-N:* new-before
- *Alt-P:* reparenting
- *Alt-Q:* squash-into-parent
- *Alt-R:* rebasing
- *Alt-S:* restore-file
- *Alt-T:* tag
- *Alt-U:* duplicate
- *Alt-V:* vivifydivergent
- *Alt-W:* squash-@-into
- *Alt-X:* swap-commits
- *Alt-Z:* undo
- *Ctrl-↑:* preview-up
- *Ctrl-↓:* preview-down
- *Ctrl-A:* author-reset
- *Ctrl-D:* describe
- *Ctrl-E:* edit-workspace
- *Ctrl-F:* file-editor
- *Ctrl-H:* help
- *Ctrl-L:* log
- *Ctrl-N:* new
- *Ctrl-O:* op-log
- *Ctrl-P:* push-remote
- *Ctrl-T:* toggle-evolog
- *Ctrl-U:* clear-filter
- *Ctrl-V:* gitk

See also `jj-fzf --help` or the wiki page
[jj-fzf-help](https://github.com/tim-janik/jj-fzf/wiki/jj-fzf-help) for detailed descriptions.
