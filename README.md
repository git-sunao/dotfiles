# dotfiles

## Initial setup

Run the setup script from this checkout (the checkout need not be at `~/dotfiles`):

```bash
bash init.sh --check
bash init.sh
```

`init.sh` replaces the old `link.sh`. It links `~/.bashrc`, `~/.latexmkrc`,
`~/.gitignore_global`, and `~/.inputrc` to the corresponding files in `rc/`,
whose source names have no leading dot. It creates `~/.config` as a real directory
if absent, and links only the explicitly managed applications: `alacritty`,
`bash`, `git`, `htop`, `iterm2`, `matplotlib`, and `nvim`, each to `config/<app>`.
Other applications and local directories are not automatically installed.
It checks all sources and destinations before
making changes. Existing symlinks that resolve to the intended target are left
alone, including relative symlinks. Recognized legacy links to this same checkout
are migrated as described below, even if their old targets disappeared during
`git pull`. Other files, directories, links elsewhere, and unknown dangling links
are conflicts: the script lists them and exits unsuccessfully without changing
anything. Missing source files also stop setup. `--check`
performs only this inspection and is safe to run against an existing installation.

Review conflicting settings and migrate host-specific values into your private
host file before manually moving the originals to a backup outside the public
repository. Then rerun setup. There is no force option or automatic replacement
of custom settings. An existing real `~/.config` directory is kept, and unrelated
applications inside it are left alone. Existing managed application directories
are conflicts; their contents are not automatically merged. A whole-directory
link at `~/.config` is migrated only if it points to this checkout's `.config`
or `config`; all other links and regular files there are conflicts.
An error during application stops the script; completed copies or links may
remain. Original legacy settings are retained for recovery. Do not run multiple
setup processes or edit the affected files concurrently during migration.

Older `link.sh` versions pointed `~/.gitignore_global` at the nonexistent
`rc/.gitignore_global`. The current source is `rc/gitignore_global`.
Links to that old path or the former checkout-root `.gitignore_global` are
recognized and updated, including dangling links.

`init.sh` does not modify `.bash_profile`, `.bash_login`, or `.profile`, or choose
a host configuration. Inspect existing login profiles for site initialization
and settings that need migration. After setting up `host.sh` as described below,
a Bash login profile with no remaining site-specific initialization can contain:

```bash
if [ -r "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
```

Keep any required site initialization before this block. Configure the host file
and login profile before testing a new terminal or SSH session.

### Migrating an existing installation

Keep the current shell open while updating the repository, then run:

```bash
bash init.sh --check
bash init.sh
```

The check lists `RELINK`, `MIGRATE`, and `PRESERVE` operations without executing
them. Only known old paths inside this exact checkout qualify: the four
home-level settings and the old whole-config or per-application links. Absolute
and relative links are recognized when their target parent can be resolved;
known absolute old paths also work when their parent has disappeared. Links to
another checkout are not adopted. If a surviving old home-level target contains
different content from the new source, migration stops for review.

For a whole-config migration, a new real `~/.config` is prepared before the old
link is detached. Leftovers in the old tree for managed applications are copied
into missing locations in `config/<app>`; this includes `host.sh` and
`interactive.local.sh`. Unmanaged application settings are copied into the new
`~/.config`. Existing identical regular files or equivalent symlinks can be kept;
different content or incompatible entry types stop the entire preflight. File
and directory permissions are preserved. Symlinks into the migrated tree are
updated to refer to the new locations, including tracked targets already removed
from the old tree by `git pull`. Links outside that tree retain their targets;
relative references become absolute so moving the link does not change their
meaning. Sockets, FIFOs, other
special files, and uninspectable directories require manual handling and block
migration rather than being silently omitted.

The old checkout `.config/` contents are never deleted and remain Git-ignored.
They serve as a recovery copy. References outside the migrated settings are not
rewritten, so review any other uses before removing the old tree. Host selection is
preserved, not inferred from the machine name. No login profile is rewritten.
Check a new shell before closing the existing session. Review any additional
local files copied into managed application directories before committing;
the installer does not stage or commit anything.

During the whole-directory switch, `~/.config.init-pending/` temporarily records
the original link, the prepared directory, and its filesystem identity. An error
or catchable interruption after detaching the old link restores it if `~/.config`
is still absent. After an uncatchable interruption such as `SIGKILL`, rerun
`bash init.sh --check` and `bash init.sh`: the record identifies the unfinished
migration even when `~/.config` is absent, or recognizes that the new directory
was already installed. The check does not restore links or modify the record.
If a different configuration has appeared in the meantime, setup stops for
review instead of replacing it. A successful retry removes the recovery record.
Do not delete that record while recovering, or run multiple installers at once.
An abrupt kill may leave an unused `.config.init.*` temporary directory; these
are not active configuration and can be removed after recovery.

The former `.iterm2plist/` directory is now `iterm2plist/`. If iTerm2 is configured
to load preferences from that custom folder, update its custom preference folder
to the new path. This is separate from the `~/.config/iterm2` application link;
`init.sh` does not change iTerm2 preferences on other machines.
Until that preference can be changed, a local `.iterm2plist -> iterm2plist`
compatibility symlink preserves the old path. This link is Git-ignored;
the actual preference file is stored only in `iterm2plist/`.

### Repository layout

`rc/` contains files installed directly in the home directory; `config/` holds
application settings; `scripts/` holds shared commands; `private/` holds the
independent private host repository; `tests/` holds checks; `conda-env/` holds
environment definitions; `iterm2plist/` holds the custom iTerm2 preferences.
The repository's own `.gitignore` retains its required name.

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
`config/bash/host.sh.example` as a starting point. For example, after saving
settings as `~/dotfiles/private/cluster-a.sh`, install the local link:

```bash
ln -s "$HOME/dotfiles/private/cluster-a.sh" "$HOME/.config/bash/host.sh"
```

The command fails if `host.sh` already exists; inspect it before replacing it.
The installation must already make this repository's `config/bash` available
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
`rc/bashrc` and `~/.config/bash` linked to this repository's `config/bash`, edits affect
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
If tool initialization fails, `.bashrc` reports it and continues loading aliases
and the prompt. Sourcing `envman.sh` directly still returns failure for jobs that
need to stop when activation setup is unavailable.

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
fallback does not itself provide `conda activate`. Mamba first tries `shell hook`,
then falls back to the installation's `etc/profile.d/mamba.sh` for older versions.
If neither initialization method succeeds, it returns an error.
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
