<!-- BADGES -->
[![License][mpl2-badge]][mpl2-url]
[![Issues][issues-badge]][issues-url]
[![Irc][irc-badge]][irc-url]

<!-- HEADING -->
JJ-FZF
======

![jj-fzf-demo1](https://github.com/tim-janik/tools/assets/281887/584952b6-a65c-430a-885c-720012ce4e2f)
JJ-FZF displays previews of the `jj log` history and can squash, branch, commit, rebase, undo and much more [asc](https://asciinema.org/a/667451)


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
