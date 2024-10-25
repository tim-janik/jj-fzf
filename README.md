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

### Merging Commits

This screencast demonstrates how to merge commits using the `jj-fzf` command-line tool. It begins by selecting a revision to base the merge commit on, then starts the merge dialog with `Alt+M`. For merging exactly 2 commits, `jj-fzf` suggests a merge commit message and opens the text editor before creating the commit. More commits can also be merged, and in such cases, `Ctrl+D` can be used to describe the merge commit afterward.

![merge-commit](https://github.com/user-attachments/assets/ffa3c957-5ef8-4a31-8472-a974d7b1e710)
**Mergin Commits:** [Asciicast](https://asciinema.org/a/684021) [MP4](https://github.com/user-attachments/assets/5eb8b7ea-667c-489f-b1fe-e4292d0a1009)

### Splitting Commits

This screencast demonstrates how to handle large changes in the working copy using `jj-fzf`.
It begins by splitting individual files into separate commits (`Alt+F`), then interactively splits (`Alt+I`) a longer diff into smaller commits.
Diffs can also be edited using the diffedit command (`Alt+E`) to select specific hunks.
Throughout, commit messages are updated with the describe command (`Ctrl+D`),
and all changes can be undone step by step using `Alt+Z`.

![Splitting Commits](https://github.com/user-attachments/assets/d4af7859-180e-4ecf-872c-285fbf72c81f)
**Splitting Commits:** [Asciicast](https://asciinema.org/a/684020) [MP4](https://github.com/user-attachments/assets/6e1a837d-4a36-4afd-ad7e-d1ce45925011)


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
