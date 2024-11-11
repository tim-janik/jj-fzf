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
