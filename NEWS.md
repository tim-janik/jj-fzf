## JJ-FZF 0.24.0

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


## JJ-FZF 0.23.0

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


## JJ-FZF 0.22.0

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
