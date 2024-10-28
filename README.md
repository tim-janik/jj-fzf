<!-- BADGES -->
[![License][mpl2-badge]][mpl2-url]
[![Issues][issues-badge]][issues-url]
[![Irc][irc-badge]][irc-url]

<!-- HEADING -->
JJ-FZF
======

![JJ-FZF Intro](https://github.com/user-attachments/assets/a4e248d1-15ef-4967-bc8a-35783da45eaa)
**JJ-FZF Introduction:** [Asciicast](https://asciinema.org/a/684019) [MP4](https://github.com/user-attachments/assets/1dcaceb0-d7f0-437e-9d84-25d5b799fa53)

<!-- ABOUT -->
## About jj-fzf

`JJ-FZF` is a text UI for [jj](https://martinvonz.github.io/jj/latest/) based on [fzf](https://junegunn.github.io/fzf/), implemented as a bash shell script.
The main view centers around `jj log`, providing previews for the `jj diff` or `jj obslog` of every revision.
Several key bindings are available to quickly perform actions such as squashing, swapping, rebasing, splitting, branching, committing, or abandoning revisions.
A separate view for the operations log `jj op log` enables fast previews of old commit histories or diffs between operations, making it easy to `jj undo` any previous operation.
The available hotkeys are always displayed onscreen for simple discoverability.

The `jj-fzf` script is implemented in bash-5.1, using fzf-0.29 and jj-0.21.0.
Command line tools like sed, grep are assumed to provide GNU tool semantics.

<!-- USAGE -->
## Usage

Start `jj-fzf` in any `jj` repository and study the keybindings.
Various `jj` commands are accesible through `Alt` and `Ctrl` key bindings.
The query prompt can be used to filter the *oneline* revision display from the `jj log` output and
the preview windows shows commit and diff information.
When a key binding is pressed to modify the history, the corresponding `jj` command with its
arguments is displayed on stderr.

<!-- FEATURES -->
## Features

### Splitting Commits

This screencast demonstrates how to handle large changes in the working copy using `jj-fzf`.
It begins by splitting individual files into separate commits (`Alt+F`), then interactively splits (`Alt+I`) a longer diff into smaller commits.
Diffs can also be edited using the diffedit command (`Alt+E`) to select specific hunks.
Throughout, commit messages are updated with the describe command (`Ctrl+D`),
and all changes can be undone step by step using `Alt+Z`.

![Splitting Commits](https://github.com/user-attachments/assets/d4af7859-180e-4ecf-872c-285fbf72c81f)
**Splitting Commits:** [Asciicast](https://asciinema.org/a/684020) [MP4](https://github.com/user-attachments/assets/6e1a837d-4a36-4afd-ad7e-d1ce45925011)

### Merging Commits

This screencast demonstrates how to merge commits using the `jj-fzf` command-line tool.
It begins by selecting a revision to base the merge commit on, then starts the merge dialog with `Alt+M`.
For merging exactly 2 commits, `jj-fzf` suggests a merge commit message and opens the text editor before creating the commit.
More commits can also be merged, and in such cases, `Ctrl+D` can be used to describe the merge commit afterward.

![Mergin Commits](https://github.com/user-attachments/assets/47be543f-4a20-42a2-929b-e9c53ad1f896)
**Mergin Commits:** [Asciicast](https://asciinema.org/a/685133) [MP4](https://github.com/user-attachments/assets/7d97f37f-c623-4fdb-a2de-8860bab346a9)

### Rebasing Commits

This screencast demonstrates varies ways of rebasing commits (`Alt+R`) with `jj-fzf`.
It begins by rebasing a single revision (`Alt+R`) before (`Ctrl+B`) and then after (`Ctrl+A`) another commit.
After that, it moves on to rebasing an entire branch (`Alt+B`), including its descendants and ancestry up to the merge base, using `jj rebase --branch <b> --destination <c>`.
Finally, it demonstrates rebasing a subtree (`Alt+S`), which rebases a commit and all its descendants onto a new commit.

![Rebasing Commits](https://github.com/user-attachments/assets/d2ced4c2-79ec-4e7c-b1e0-4d0f37d24d70)
**Rebasing Commits:** [Asciicast](https://asciinema.org/a/684022) [MP4](https://github.com/user-attachments/assets/32469cab-bdbf-4ecf-917d-e0e1e4939a9c)

### "Mega-Merge" Workflow

This screencast demonstrates the [Mega-Merge](https://ofcr.se/jujutsu-merge-workflow) workflow, which allows to combine selected feature branches into a single "Mega-Merge" commit that the working copy is based on.
It begins by creating a new commit (`Ctrl+N`) based on a feature branch and then adds other feature branches as parents to the commit with the parent editor (`Alt+P`).
As part of the workflow, new commits can be squashed (`Alt+W`) or rebased (`Alt+R`) into the existing feature branches.
To end up with a linear history, the demo then shows how to merge a single branch into `master` and rebases everything else to complete a work phase.

![Mega-Merge Workflow](https://github.com/user-attachments/assets/f944afa2-b6ea-438d-802b-8af83650a65f)
**Rebasing Commits:** [Asciicast](https://asciinema.org/a/685256) [MP4](https://github.com/user-attachments/assets/eb1a29e6-b1a9-47e0-871e-b2db5892dbf1)

<!-- LICENSE -->
## License

This application is licensed under
[MPL-2.0](https://github.com/tim-janik/anklang/blob/master/LICENSE).


<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[irc-badge]: https://img.shields.io/badge/Live%20Chat-Libera%20IRC-blueviolet?style=for-the-badge
[irc-url]: https://web.libera.chat/#Anklang
[issues-badge]: https://img.shields.io/github/issues-raw/tim-janik/tools.svg?style=for-the-badge
[issues-url]: https://github.com/tim-janik/tools/issues
[mpl2-badge]: https://img.shields.io/static/v1?label=License&message=MPL-2&color=9c0&style=for-the-badge
[mpl2-url]: https://github.com/tim-janik/tools/blob/master/LICENSE
<!-- https://github.com/othneildrew/Best-README-Template -->
