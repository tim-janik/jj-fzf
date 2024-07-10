<!-- BADGES -->
[![License][mpl2-badge]][mpl2-url]
[![Issues][issues-badge]][issues-url]
[![Irc][irc-badge]][irc-url]

<!-- HEADING -->
JJ-FZF
======

![jj-fzf-demo1](https://github.com/tim-janik/tools/assets/281887/584952b6-a65c-430a-885c-720012ce4e2f)
jj-fzf can browse the JJ log, rebase commits, browse jj help, assign branches and much more [jj-fzf-demo1](https://asciinema.org/a/667451)


<!-- ABOUT -->
## About jj-fzf

This is an [fzf](https://github.com/junegunn/fzf) based TUI to aid workflows with [jj](https://github.com/martinvonz/jj/).

The exact usage may change as my understanding of JJ grows and as jj-fzf is adapted to new feature releases of jj.

The jj-fzf script is implemented in bash-5.1, using fzf-0.29 and jj-0.19.0.
Command line tools like sed, grep are assumed to provide GNU tool semantics.

<!-- USAGE -->
## Usage

Start jj-fzf in any jj repository and study the keybindings.
The query prompt supports either [jj revset](https://martinvonz.github.io/jj/latest/revsets/) syntax,
or [PCRE2](https://www.pcre.org/current/doc/html/pcre2syntax.html) regular expression search on the jj log output.

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
