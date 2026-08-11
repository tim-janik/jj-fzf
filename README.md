<!-- BADGES -->
[![License][mpl2-badge]][mpl2-url]
[![Issues][issues-badge]][issues-url]
[![Irc][irc-badge]][irc-url]

<!-- HEADING -->
JJ-FZF
======

<!-- ABOUT -->
## About jj-fzf

`JJ-FZF` is a text UI for the [Jujutsu VCS](https://www.jj-vcs.dev/latest/) `jj` based on [fzf](https://junegunn.github.io/fzf/).
All modification commands are printed on stderr to help users in learning the [jj CLI](https://www.jj-vcs.dev/latest/cli-reference/).

### Feature Set

* Edit the current [revset](https://www.jj-vcs.dev/latest/revsets/) (list of commits) in the fzf input field with live reload of the `jj log`.
* Complex [rebase](https://github.com/tim-janik/jj-fzf?tab=readme-ov-file#rebasing-commits) commands just need `Alt-R` and cursor keys.
* Use `Alt-P` for a dialog to edit or simplify the parents in a [merge](https://github.com/tim-janik/jj-fzf?tab=readme-ov-file#merging-commits) commit.
* [Splitting](https://github.com/tim-janik/jj-fzf?tab=readme-ov-file#splitting-commits) commits needs a single key press. `Alt-F` splits commits by file, `Alt-I` uses the [`jj split`](https://www.jj-vcs.dev/latest/cli-reference/#jj-split) command in interactive mode.
* First class [Mega-Merge](https://github.com/tim-janik/jj-fzf?tab=readme-ov-file#mega-merge-workflow) support: `Ctrl-N` starts a new branch, `Alt-N` inserts a new empty commit, `Alt-P` edits merged branches, `Alt-O` absorbs fixes into related commits of merged branches.
* Commits can be [squashed](https://www.jj-vcs.dev/latest/cli-reference/#jj-squash) (combined into a single commit) from arbitrary points in the ancestry with `Alt-Q`.
* A dedicated browser (`Ctrl-T`) shows the evolution of each revision ([change_id](https://www.jj-vcs.dev/latest/glossary/#change-id)) and allows to inject (`Alt-J`) historic versions of a revision as a new commit without affecting the working copy.
* Key bindings are easily discoverable in an onscreen area and via `Ctrl-H` or the `jj-fzf.1` manual page.
* At any point the [oplog](https://www.jj-vcs.dev/latest/operation-log/) can be opened with `Ctrl-O` to understand recent modifications, browse the working copy of a previous operation and restore the repository to an arbitrary earlier snapshot.
* Use `Alt-J` in the oplog to "inject" past snapshots of a repository as newly created historic commits after the fact without affecting the working copy.
* Snapshots are usually created with commands like `jj status`, [Watchman](https://www.jj-vcs.dev/latest/config/#watchman) or upon `Save` in Emacs by using the [contrib/jj-undirty.el](https://github.com/tim-janik/jj-fzf/blob/trunk/contrib/jj-undirty.el) script.
* The shortcuts for repository wide undo/redo are `Alt-Z` and `Alt-Y`. The operation log view (`Ctrl-O`) reflects the current state of the undo stack by marking past undo operations with `⋯`.

The main view centers around `jj log` and allows editing of the revset that is currently being displayed.
Next to it is a preview window that shows details, message and diff for the current revision.
Cursor keys change the current revision and (`Shift-`)`Tab` selects commits.
Enter can be used to browse the commit history, or to confirm if `jj-fzf` was started as a selector.
Various `Ctrl` and `Alt` key bindings are provided to quickly perform actions such as abandon, squash, merge, rebase, split, branch, undo or redo of a commit and more.
The commands and key bindings can also be displayed with `jj-fzf --help` and are documented in the wiki: [jj-fzf-help](https://github.com/tim-janik/jj-fzf/wiki/jj-fzf-help)

## Installation

There are several ways to install and use `jj-fzf`:

* Download the [latest](https://github.com/tim-janik/jj-fzf/releases/latest/) release tarball.
  Extract, then run `make all` and `make install PREFIX=~/.local` under a suitable prefix to run `jj-fzf` from `$PATH` and have `jj-fzf.1` in `$MANPATH`.
* Download [jj-fzf.sfx](https://github.com/tim-janik/jj-fzf/releases/latest/download/jj-fzf.sfx), rename to `jj-fzf` and mark it executable to run it directly.
* Download [jj-fzf.1.gz](https://github.com/tim-janik/jj-fzf/releases/latest/download/jj-fzf.1.gz), install it under e.g. `~/.local/share/man/man1/jj-fzf.1.gz`.

Internally, `jj-fzf` uses tools like python3, awk, sed and grep with GNU tool semantics.

<!-- USAGE -->
## Usage

Start `jj-fzf` in any `jj` repository and study the keybindings.
Various `jj` commands are accessible through `Alt` and `Ctrl` key bindings.
The query prompt can be used to type a new revset to be displayed by `jj log`.
The preview window shows commit details and diff information.
When a key binding is pressed to modify the history, the actual `jj` command is displayed on stderr with its arguments.
Quit `jj-fzf` with `Escape` or suspend it with `Ctrl-Z` to look at the execution trail.

<!-- FEATURES -->
## Demo Screencasts

### UI Introduction

The intro screen cast shows the `jj log` view, the commit diff preview window and a brief glimpse of the oplog (`Ctrl-O`).

![JJ-FZF Intro](https://github.com/user-attachments/assets/a4e248d1-15ef-4967-bc8a-35783da45eaa)
**JJ-FZF Introduction:** [Asciicast](https://asciinema.org/a/684019) [MP4](https://github.com/user-attachments/assets/1dcaceb0-d7f0-437e-9d84-25d5b799fa53)


### Splitting Commits

This screencast demonstrates how to handle large changes in the working copy using `jj-fzf`.
It begins by splitting individual files into separate commits (`Alt-F`), then interactively splits (`Alt-I`) a longer diff into smaller commits.
Diffs can also be edited using the diffedit command (`Alt-E`) to select specific hunks.
Throughout, commit messages are updated with the describe command (`Ctrl-D`),
and all changes can be undone step by step using `Alt-Z`.

![Splitting Commits](https://github.com/user-attachments/assets/d4af7859-180e-4ecf-872c-285fbf72c81f)
**Splitting Commits:** [Asciicast](https://asciinema.org/a/684020) [MP4](https://github.com/user-attachments/assets/6e1a837d-4a36-4afd-ad7e-d1ce45925011)

### Merging Commits

This screencast demonstrates how to merge commits using the `jj-fzf` command-line tool.
It begins by selecting a revision to base the merge commit on, then starts the merge dialog with `Alt-M`.
For merging exactly 2 commits, `jj-fzf` suggests a merge commit message and opens the text editor before creating the commit.
More commits can also be merged, and in such cases, `Ctrl-D` can be used to describe the merge commit afterward.

![Merging Commits](https://github.com/user-attachments/assets/47be543f-4a20-42a2-929b-e9c53ad1f896)
**Merging Commits:** [Asciicast](https://asciinema.org/a/685133) [MP4](https://github.com/user-attachments/assets/7d97f37f-c623-4fdb-a2de-8860bab346a9)

### Rebasing Commits

This screencast demonstrates varies ways of rebasing commits (`Alt-R`) with `jj-fzf`.
It begins by rebasing a single revision (`Alt-R`) before (`Ctrl-B`) and then after (`Ctrl-A`) another commit.
After that, it moves on to rebasing an entire branch (`Alt-B`), including its descendants and ancestry up to the merge base, using `jj rebase --branch <b> --destination <c>`.
Finally, it demonstrates rebasing a subtree (`Alt-S`), which rebases a commit and all its descendants onto a new commit.

![Rebasing Commits](https://github.com/user-attachments/assets/d2ced4c2-79ec-4e7c-b1e0-4d0f37d24d70)
**Rebasing Commits:** [Asciicast](https://asciinema.org/a/684022) [MP4](https://github.com/user-attachments/assets/32469cab-bdbf-4ecf-917d-e0e1e4939a9c)

### "Mega-Merge" Workflow

This screencast demonstrates the [Mega-Merge](https://ofcr.se/jujutsu-merge-workflow) workflow, which allows to combine selected feature branches into a single "Mega-Merge" commit that the working copy is based on.
It begins by creating a new commit (`Ctrl-N`) based on a feature branch and then adds other feature branches as parents to the commit with the parent editor (`Alt-P`).
As part of the workflow, new commits can be squashed (`Alt-W`) or rebased (`Alt-R`) into the existing feature branches.
To end up with a linear history, the demo then shows how to merge a single branch into `master` and rebases everything else to complete a work phase.

![Mega-Merge Workflow](https://github.com/user-attachments/assets/f944afa2-b6ea-438d-802b-8af83650a65f)
**Mega-Merge:** [Asciicast](https://asciinema.org/a/685256) [MP4](https://github.com/user-attachments/assets/eb1a29e6-b1a9-47e0-871e-b2db5892dbf1)

<!-- CONTRIB -->
## Contrib Directory

The `contrib/` directory contains additional tools or scripts that complement the main jj-fzf functionality.
These scripts are aimed at developers and provide useful utilities for working with jj.

* **jj-am.sh:** A very simple script that allows to apply patches to a jj repository.
  `Usage: ~/jj-fzf/contrib/jj-am.sh [format-patch-file...]`

* **jj-undirty.el:** A simple Emacs lisp script that automatically runs `jj status` every time a buffer is saved to snapshot file modifications.
  `Usage: (load (expand-file-name "~/jj-fzf/contrib/jj-undirty.el"))`
  This will install an after-save-hook that calls `jj-undirty` to snapshot the changes in a saved buffer in a jj repository.

* **suspend-with-shell.el:** A simple Emacs lisp script that allows to suspend Emacs with a custom command.
  ```
  Usage:
    ;; Suspend emacs with a custom command, without using `ioctl(TIOCSTI)`
    (load (expand-file-name "~/jj-fzf/contrib/suspend-with-shell.el"))
    ;; Suspend emacs and start jj-fzf on Ctrl-T
    (global-set-key (kbd "C-t") (lambda () (interactive) (suspend-with-shell "jj-fzf")))
  ```

<!-- LICENSE -->
## License

This application is licensed under
[MPL-2.0](https://github.com/tim-janik/jj-fzf/blob/master/LICENSE).


## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=tim-janik/jj-fzf&type=Timeline)](https://star-history.com/#tim-janik/jj-fzf)

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[irc-badge]: https://img.shields.io/badge/Live%20Chat-Libera%20IRC-blueviolet?style=for-the-badge
[irc-url]: https://web.libera.chat/#Anklang
[issues-badge]: https://img.shields.io/github/issues-raw/tim-janik/jj-fzf.svg?style=for-the-badge
[issues-url]: https://github.com/tim-janik/jj-fzf/issues
[mpl2-badge]: https://img.shields.io/static/v1?label=License&message=MPL-2&color=9c0&style=for-the-badge
[mpl2-url]: https://github.com/tim-janik/jj-fzf/blob/master/LICENSE
<!-- https://github.com/othneildrew/Best-README-Template -->
