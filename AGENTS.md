# jj-fzf

`make check` validates the literal paths and make targets below.

## Where code goes

- `./jj-fzf` owns the main key bindings and their help text. Keep KEY, RUN and DOC entries consistent.
- Shared shell code belongs in `lib/setup.sh`. Dialogs belong in `lib/`.
- Edit `doc/jj-fzf.1.md`, not the generated manual. Update `./README.md` when keys or behavior change.
- `./preflight.sh` defines minimum dependency versions. Check upstream changes before raising them.

## Repository state

- Use jj and git commands to change repository state. Keep preview and listing commands from snapshotting the working copy.
- Show user-requested changes through jjfzf_run. Preserve command failures when refreshing the display.
- Use commit IDs for hidden or divergent revisions. Preserve NUL-separated records and the existing field layout.

## Code

- Match nearby code. Use jjfzf_ function names and JJFZF_ environment names. Export functions needed by fzf child shells.
- Quote strings for the parser receiving them: Bash, revset, template or TOML. Keep command arguments in arrays where possible.
- Keep changes small, comments short, and the project's license header in new source files.
- Use path/file.ext: purpose for commit titles, with a body explaining why and how. Never add authorship trailers.

## Removing code

- Find why unusual code exists before removing or replacing it. Read its history and reproduce the problem where possible.
- Explain logic removals in an Evidence: paragraph with commit IDs or links. Put the reason on the same line as Evidence:.
- `make check-removals` requires evidence at 10 net deleted source lines per commit. Smaller logic removals still need evidence.
- Check exported functions, binding strings and namerefs before declaring code unused.
- Never delete behavior or tests merely to satisfy a check. Use a narrow, explained exception when the check is wrong.
- If evidence is missing, ask before removing the code.

## Checks

- `make all` builds the manual. `make check` runs `make lint`, guidance checks, and core, contrib and workflow tests.
- Every behavior change needs a focused regression test. Prefer the CLI and temporary repositories in `tests/`.
- Check content, parents, working-copy position and unaffected branches. Test failures and cancellation as well as success.
- Mock editors, network services and model responses. Keep tests independent of user configuration.
- `make test` runs the terminal demos in `screencasts/`. New asynchronous tests wait for expected state with a timeout.
- `make distcheck` checks the archive, manual, installation, uninstall and self-extracting executable.
- Keep ShellCheck warnings advisory until reviewed. A warning alone is no reason to remove working code.
