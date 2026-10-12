# dotfiles

## Host settings

Keep common startup scripts and `host.sh.example` in this public repository.
Actual host settings belong in `private/` inside this checkout.
The public repository ignores that entire directory. It can be an independent
private Git repository named `dotfiles-private` on GitHub; it is not a submodule:

```text
~/dotfiles/
    private/
```

Create one ordinary Bash file per environment in the private directory, using
`.config/bash/host.sh.example` as a starting point. For example, after saving
settings as `~/dotfiles/private/cluster-a.sh`, install the local link:

```bash
ln -s "$HOME/dotfiles/private/cluster-a.sh" "$HOME/.config/bash/host.sh"
```

The command fails if `host.sh` already exists; inspect it before replacing it.
The installation must already make this repository's `.config/bash` available
at `~/.config/bash`. `host.sh` is Git-ignored, including when it is a symlink.
Do not add actual host files or their private paths to the public repository.
An independent local `host.sh` also works if Git synchronization is unnecessary.

The link selects the environment once at setup. There is no hostname detection,
selection variable, custom configuration syntax, or parser. `WORK_HOST`, if
set by the file, is only an informational label; inherited values and source
arguments do not choose a different file. Missing or broken links and errors
returned by the host file stop `.bashrc` before tool initialization.

`host.sh` is executable Bash code, not a data format: only source trusted files.
Ordinary quoting, variable expansion, and arrays work directly. Settings are
applied as the file runs, without transactional validation or rollback.

| Variable | Purpose |
| --- | --- |
| `WORKDIR` | Work directory used by navigation aliases |
| `PACKDIR` | Package directory used by navigation aliases |
| `LOCAL_WORKDIR`, `LOCAL_BIGDATA` | Optional local directories; use empty strings when unused |
| `PROMPT_COLOR` | Literal ANSI escape notation, such as `'\e[0;32m'` |
| `CONDA_ROOTS` | Ordered Bash array of installation paths; use `()` to skip initialization |
| `WORK_HOST` | Optional informational label |

Export scalar variables needed by child processes. `CONDA_ROOTS` is a Bash array
and cannot be exported; a child Bash must source `host.sh` again to get the list.
Set each relevant variable explicitly to avoid retaining values inherited from
another environment. Initialization does not choose a project's Python environment.

Login and compute nodes must see the same link and target, typically through a
shared home directory. Different clusters requiring different settings must not
share a single `host.sh` link. Do not switch a shared link while jobs use it.
Each clone of the private repository contains the settings for all environments;
keep passwords, tokens, and private keys out of that repository too.

Update the public and private repositories independently, from their respective
directories. Until the private directory has its own `.git`, Git commands there
operate on the enclosing public repository. Once the private
repository exists, a pull updates the linked files without recreating the links.
Shell startup reads local files and does not contact GitHub. Running shells do
not automatically reload settings after a pull.

## Bash startup

These scripts support macOS system Bash 3.2. With `~/.bashrc` linked to
`rc/.bashrc` and `~/.config` linked to this repository's `.config`, edits affect
new shells before a commit is made.

`.bashrc` sources `host.sh`, then adds this repository's `scripts` directory to
`PATH` if absent. Directory symlinks and spaces are supported. Repeated reads
do not add another identical PATH entry; existing duplicates and ordering are
not otherwise normalized. This common startup does not initialize conda/mamba,
NVM, completion, prompts, or aliases in non-interactive shells. Keep the host
files limited to settings so that they also remain suitable for batch jobs.

For interactive shells, `.bashrc` sources `envman.sh`, `package.sh`, `alias.sh`,
`display.sh`, and `typing.sh`, in that order. An optional Git-ignored
`interactive.local.sh` runs last. Arbitrary `*.sh` files are not auto-loaded.
`envman.sh` expects `CONDA_ROOTS` to have been set; it does not load host settings.

For non-interactive jobs, source `.bashrc` to load both host settings and the
common command PATH:

```bash
. "$HOME/.bashrc" || exit
```

If only host settings are needed, source `~/.config/bash/host.sh` directly.
For conda/mamba activation, next source `~/.config/bash/envman.sh`, then activate
the environment explicitly chosen for the project. Stop the job if loading or
activation fails. Sourcing `.bashrc` in a non-interactive shell does not initialize
activation functions. Existing jobs that never read these files do not load the
new configuration automatically.

`envman.sh` selects the first `CONDA_ROOTS` entry containing executable
`bin/conda` or `bin/mamba`. It initializes the available tools from that single
root. Matching shell functions are not reinitialized on repeated reads. Once a
root is selected, initialization failure does not select another installation.
Conda retains its profile-script and executable-PATH fallback; the PATH-only
fallback does not itself provide `conda activate`. Mamba hook failure is reported.
An empty array skips initialization; a nonempty array without an available
executable is an error. Each tool's configuration controls base auto-activation.

NVM, fzf, and rbenv remain interactive-only. NVM supports a direct installation
or Homebrew when available. Navigation aliases expand variables at use time
and quote paths containing spaces.

## Migration and remaining work

The earlier `env.sh`, `host.env`, and `host.local` scheme has been removed.
Jobs that explicitly sourced that `env.sh` must instead source `.bashrc` or
`host.sh` as described above. The old host settings filenames remain ignored
in case they are restored from a backup. The public example contains generic
settings only; actual settings and environment-specific notes belong privately.

Move host variables out of each `.bash_profile` when deploying the new startup
so there is one authoritative definition. Keep any additional profile PATH
entries or compiler/library flags unless deliberately migrating them too.
`MINIFORGEDIR` and `CONDDIR` do not select installations in this startup;
use the `CONDA_ROOTS` array. Inspect the result in a new shell.

For compatibility, `envman.sh` still adds an existing active `CONDA_PREFIX/lib`
to `LD_LIBRARY_PATH` without a duplicate or empty entry. This is not an
activation/deactivation hook and does not remove old prefixes after switching
environments. Its project requirements still need to be identified.

Some external completion scripts use `complete -o nosort`, which Bash 3.2 does
not support. Updating those external scripts is outside this startup change.
Moving current settings out of the public checkout does not remove anything
already present elsewhere in the repository or its Git history.

## Verification

Run `bash tests/test-host-config.sh`. The tests use temporary host files, links,
and fake conda/mamba executables without changing HOME, activating real
installations, or running Python. They cover linked settings, installation
selection, repeated initialization, and initialization fallbacks. Actual server
startup and project environment activation require separate validation.
