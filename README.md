# dotfiles

Shared Bash and application settings for macOS and Linux (Bash 3.2+).

| Directory | Contents |
| --- | --- |
| `rc/` | Files linked into the home directory with leading dots |
| `config/` | Application settings, linked individually under `~/.config/` |
| `scripts/` | Shared commands |
| `private/` | Independent `dotfiles-private` repository; Git-ignored here |
| `conda-env/`, `iterm2plist/` | Environment definitions and iTerm2 preferences |
| `tests/` | Setup and shell initialization tests |

## Setup

From this checkout, run:

```bash
bash init.sh --check
bash init.sh
```

Use `bash init.sh`, not `source init.sh` or `. init.sh`.

`--check` makes no changes. Setup installs links for the files in `rc/` and the
managed applications in `config/`. Existing custom settings cause a conflict;
review and back them up before retrying. Unrelated applications are left alone.

Configure `host.sh` below before opening a new shell. Setup does not edit login
profiles. After moving host-specific settings into your private file, a minimal
`~/.bash_profile` is:

```bash
if [ -r "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
```

Keep any required site initialization before this block.

## Host settings

Keep one Bash file per environment in `private/`, based on
[`config/bash/host.sh.example`](config/bash/host.sh.example). Clone the private
repository into that directory and update it independently of this public repo.
Do not store passwords, tokens, or private keys in either repository.

Select the host once by creating a local link (adjust the checkout and filename):

```bash
ln -s "$HOME/dotfiles/private/cluster-a.sh" "$HOME/.config/bash/host.sh"
```

Inspect an existing `host.sh` before replacing it. There is no hostname detection.
Login and compute nodes must see the same link and target; clusters with different
settings need separate links. Do not switch a shared link while jobs use it.

Set work paths, prompt color, and `CONDA_ROOTS` in the host file. `CONDA_ROOTS` is
an ordered Bash array: the first installed root is used, and `()` skips conda/mamba
initialization. `CONDDIR` and `MINIFORGEDIR` do not select installations.
An optional `config/bash/interactive.local.sh` holds interactive-only additions.
Both local files are Git-ignored. Only source trusted Bash files.

## Batch jobs

Non-interactive `.bashrc` loads host settings and the shared command path.
Initialize conda/mamba separately when needed, then activate the project's
chosen environment:

```bash
. "$HOME/.bashrc" || exit
. "$HOME/.config/bash/envman.sh" || exit
```

Jobs that never source these files do not load the settings automatically.
`envman.sh` supports modern and legacy mamba initialization. Its compatibility
addition of `CONDA_PREFIX/lib` to `LD_LIBRARY_PATH` is not an activation hook;
it does not remove old prefixes when environments change.

## Existing installations

Keep the current shell open, update the checkout, and run the same setup commands.
`init.sh` replaces `link.sh` and migrates recognized old links pointing to this
checkout. It preserves local settings, updates internal links, and retains the
old `.config/` tree as a backup. Conflicting contents stop migration for review.
Review copied local files before committing; test a new shell before closing
this one. Do not run setup or edit affected settings concurrently.

After an interrupted migration, rerun `--check`, then setup. Do not delete
`~/.config.init-pending/`: it enables recovery and is removed on success.
Settings created after interruption are protected from replacement.

If iTerm2 uses the former `.iterm2plist/` custom preference folder, update its
preference to `iterm2plist/`; setup does not change that application preference.

## Tests

```bash
bash tests/test-init.sh
bash tests/test-host-config.sh
```

Tests use temporary fixtures without changing your home settings or activating
real environments. They cover conflicts, link migration, interrupted recovery,
and conda/mamba startup. `Killed: 9` messages are expected in forced-interruption
tests. Actual server startup still needs a check in a new session.
