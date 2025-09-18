## FUTURE

* The minimum supported fzf version is now 0.65.2.

* Ctrl-L will now either show the history up to a single selected revision,
  or for the selected (multiple) revisions only.

* All key binding commands now operate on a change_id or a list thereof.

* In case of divergent commits, an fzf list entry expands to a commit_id.

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

* When describing a commit, jj-fzf no longer appends the diff to the draft.
  To inspect the diff during edits, use jj config to configure the
  `templates.draft_commit_description`, see:
  https://jj-vcs.github.io/jj/latest/config/#default-description

* Missing commands:
  - Alt-S: restore-file	- consider Ctrl-A to restore *all* files
  - Alt-T: tag
  - Alt-V: vivifydivergent
  - Ctrl-A: author-reset - consider deprecating for metaedit
  - Ctrl-I: diff	- can this be replaced by Ctrl-L ?
  - Ctrl-P: push-remote	- considering to make this
            --all --tracked --deleted but *not* --allow-new
	    support -r {+2}
  - Ctrl-T: evolog
  - Ctrl-V: gitk	- consider removing
  - Ctrl-W: wb-diff	- toggle ±b ±w for diff
  - Ctrl-F: file-editor	- considering to make this fzf-filter instead
  - oplog: Ctrl-D to toggle jj log diff ON/OFF


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
* Removed unsed command / key binding for undo marker reset


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
