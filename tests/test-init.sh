#!/bin/bash
set -eu
repo_dir=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-init-test.XXXXXX")
test_root=$(cd -P -- "$test_root" && pwd)
trap 'rm -rf -- "$test_root"' EXIT
fixture_repo="$test_root/repo with spaces"
test_home="$test_root/home with spaces"
apps=(alacritty bash git htop iterm2 matplotlib nvim)
mkdir -p "$fixture_repo/rc" "$fixture_repo/bin" "$test_home"
for app in "${apps[@]}"; do mkdir -p "$fixture_repo/config/$app"; done
# Substitute only HOME references; the real home is never an installation target.
sed -e 's/\${HOME/\${TEST_HOME/g' -e 's/\$HOME/\$TEST_HOME/g' \
    "$repo_dir/init.sh" > "$fixture_repo/init.sh"
for file in bashrc latexmkrc gitignore_global inputrc; do
    printf 'fixture\n' > "$fixture_repo/rc/$file"
done
run_init() {
    /usr/bin/env TEST_HOME="$test_home" /bin/bash "$fixture_repo/init.sh" "$@" > "$test_root/output" 2>&1
}
assert_absent() { [ ! -e "$1" ] && [ ! -L "$1" ]; }
assert_no_links() {
    local target app
    for target in .bashrc .latexmkrc .gitignore_global .inputrc; do
        assert_absent "$test_home/$target"
    done
    for app in alacritty bash git htop iterm2 matplotlib; do
        assert_absent "$test_home/.config/$app"
    done
}

# Sourcing must neither exit the calling shell nor alter its options or traps.
# Use a separate Bash so a regression cannot terminate this test driver.
for source_mode in source dot; do
    for caller_options in relaxed strict; do
        /usr/bin/env TEST_HOME="$test_home" FIXTURE_INIT="$fixture_repo/init.sh" \
            SOURCE_MODE="$source_mode" CALLER_OPTIONS="$caller_options" \
            /bin/bash --noprofile --norc -c '
                set +e +u
                if [ "$CALLER_OPTIONS" = strict ]; then set -eu; fi
                trap ":" EXIT
                trap ":" HUP INT TERM
                before_options=$(set +o)
                before_flags=$-
                before_traps=$(trap -p)
                if [ "$SOURCE_MODE" = source ]; then
                    source "$FIXTURE_INIT"
                else
                    . "$FIXTURE_INIT"
                fi
                [ "$-" = "$before_flags" ] || exit 1
                [ "$(set +o)" = "$before_options" ] || exit 1
                [ "$(trap -p)" = "$before_traps" ] || exit 1
                if [ "$CALLER_OPTIONS" = relaxed ]; then
                    false
                    unset dotfiles_unset_fixture
                    : "$dotfiles_unset_fixture"
                fi
                printf "caller survived\n"
            ' > "$test_root/source-output" 2>&1
        grep -q 'caller survived' "$test_root/source-output"
        grep -q 'nothing changed' "$test_root/source-output"
        assert_absent "$test_home/.config"
        assert_no_links
    done
done
printf 'PASS: source and dot leave caller options, traps, and subsequent commands intact\n'

run_init --check
assert_no_links
assert_absent "$test_home/.config"
run_init
for file in bashrc latexmkrc gitignore_global inputrc; do
    [ -L "$test_home/.$file" ]
    [ "$test_home/.$file" -ef "$fixture_repo/rc/$file" ]
    rm "$test_home/.$file"
done
[ -d "$test_home/.config" ]
[ ! -L "$test_home/.config" ]
for app in "${apps[@]}"; do
    [ -L "$test_home/.config/$app" ]
    [ "$test_home/.config/$app" -ef "$fixture_repo/config/$app" ]
    rm "$test_home/.config/$app"
done
printf 'PASS: check-only and fresh installation with a real .config directory\n'

# A conflict in the last application must prevent every earlier creation.
for kind in file directory link dangling; do
    target="$test_home/.config/nvim"
    case "$kind" in
        file) printf 'original\n' > "$target" ;;
        directory) mkdir "$target"; printf 'original\n' > "$target/keep" ;;
        link) ln -s "$fixture_repo/rc" "$target" ;;
        dangling) ln -s missing "$target" ;;
    esac
    if run_init; then printf 'FAIL: accepted %s conflict\n' "$kind" >&2; exit 1; fi
    assert_no_links
    case "$kind" in
        file) [ "$(cat "$target")" = original ] ;;
        directory) [ "$(cat "$target/keep")" = original ]; assert_absent "$target/nvim" ;;
        link) [ "$(readlink "$target")" = "$fixture_repo/rc" ]; assert_absent "$fixture_repo/rc/nvim" ;;
        dangling) [ "$(readlink "$target")" = missing ] ;;
    esac
    rm -rf -- "$target"
done
printf 'PASS: application conflicts block all changes and preserve existing content\n'

rmdir "$test_home/.config"
for target in "$test_root/another checkout/config" "$test_root/missing"; do
    ln -s "$target" "$test_home/.config"
    if run_init; then printf 'FAIL: accepted a symlinked .config\n' >&2; exit 1; fi
    [ "$(readlink "$test_home/.config")" = "$target" ]
    assert_absent "$test_home/.bashrc"
    rm "$test_home/.config"
done
printf 'original\n' > "$test_home/.config"
if run_init; then exit 1; fi
[ "$(cat "$test_home/.config")" = original ]
rm "$test_home/.config"
printf 'PASS: foreign, dangling, and regular-file .config parents are protected\n'

rmdir "$fixture_repo/config/nvim"
if run_init; then printf 'FAIL: accepted missing source\n' >&2; exit 1; fi
assert_no_links
assert_absent "$test_home/.config"
mkdir "$fixture_repo/config/nvim"
cp "$fixture_repo/rc/bashrc" "$test_home/.bashrc"
if run_init; then printf 'FAIL: replaced a regular bashrc\n' >&2; exit 1; fi
[ ! -L "$test_home/.bashrc" ]
cmp "$fixture_repo/rc/bashrc" "$test_home/.bashrc"
assert_absent "$test_home/.config"
rm "$test_home/.bashrc"
printf 'PASS: missing sources and existing bashrc prevent even parent-directory creation\n'

mkdir -p "$test_home/.config/unrelated" "$fixture_repo/config/local-only"
printf 'keep\n' > "$test_home/.config/unrelated/settings"
ln -s '../repo with spaces/rc/bashrc' "$test_home/.bashrc"
ln -s '../../repo with spaces/config/bash' "$test_home/.config/bash"
for profile in .bash_profile .bash_login .profile; do
    printf 'site initialization\n' > "$test_home/$profile"
done
run_init
run_init
run_init --check
[ "$(readlink "$test_home/.bashrc")" = '../repo with spaces/rc/bashrc' ]
[ "$(readlink "$test_home/.config/bash")" = '../../repo with spaces/config/bash' ]
[ "$(cat "$test_home/.config/unrelated/settings")" = keep ]
assert_absent "$test_home/.config/local-only"
for profile in .bash_profile .bash_login .profile; do
    [ "$(cat "$test_home/$profile")" = 'site initialization' ]
done
printf 'PASS: repeated runs, relative links, spaces, unrelated apps, and login profiles\n'

# Exercise real startup through the per-app symlink, without real conda or HOME changes.
sed 's|\$HOME|$TEST_HOME|g' "$repo_dir/rc/bashrc" > "$fixture_repo/rc/bashrc"
printf 'export WORK_HOST=fixture\nCONDA_ROOTS=()\n' > "$fixture_repo/config/bash/host.sh"
mkdir -p "$fixture_repo/scripts/example"
printf '#!/bin/bash\nprintf "linked command\\n"\n' > "$fixture_repo/scripts/example/check-link"
chmod +x "$fixture_repo/scripts/example/check-link"
ln -s ../scripts/example/check-link "$fixture_repo/bin/check-link"
/usr/bin/env -i PATH=/usr/bin:/bin TEST_HOME="$test_home" FIXTURE_REPO="$fixture_repo" \
    /bin/bash --noprofile --norc -ec '
        . "$TEST_HOME/.bashrc"
        [ "$WORK_HOST" = fixture ]
        expected=$(cd -P "$FIXTURE_REPO/bin" && pwd)
        [ "$PATH" = "$expected:/usr/bin:/bin" ]
        . "$TEST_HOME/.bashrc"
        [ "$PATH" = "$expected:/usr/bin:/bin" ]
        [ "$(check-link)" = "linked command" ]
    '
printf 'PASS: host settings and repository commands resolve through application links\n'

# Simulate a server after git pull: old tracked names are gone, local files remain.
test_home="$test_root/legacy home"
mkdir -p "$test_home" "$fixture_repo/.config/bash" "$fixture_repo/.config/nvim" \
    "$fixture_repo/.config/custom/empty" "$fixture_repo/private"
printf 'export WORK_HOST=cluster\n' > "$fixture_repo/private/cluster.sh"
rm "$fixture_repo/config/bash/host.sh"
ln -s ../../private/cluster.sh "$fixture_repo/.config/bash/host.sh"
printf 'local interactive setup\n' > "$fixture_repo/.config/bash/interactive.local.sh"
printf 'private application settings\n' > "$fixture_repo/.config/custom/settings"
chmod 600 "$fixture_repo/.config/custom/settings"
chmod 500 "$fixture_repo/.config/custom/empty"
ln -s ../bash/host.sh "$fixture_repo/.config/custom/relative"
ln -s absent "$fixture_repo/.config/custom/broken"
# Internal references must follow the migrated copies, including tracked targets
# that git pull has already removed from the old tree.
ln -s settings "$fixture_repo/.config/custom/current"
ln -s current "$fixture_repo/.config/custom/chain"
ln -s "$fixture_repo/.config/custom/settings" "$fixture_repo/.config/custom/absolute"
ln -s .. "$fixture_repo/.config/custom/config-root"
mkdir -p "$fixture_repo/config/matplotlib/stylelib" "$test_root/external/nested"
printf 'new tracked style\n' > "$fixture_repo/config/matplotlib/stylelib/style.mplstyle"
ln -s ../matplotlib/stylelib/style.mplstyle "$fixture_repo/.config/custom/style"
ln -s ../matplotlib/stylelib/style.mplstyle "$fixture_repo/.config/bash/style"
ln -s interactive.local.sh "$fixture_repo/.config/bash/local-link"
printf 'external setting\n' > "$test_root/external/settings"
ln -s "$test_root/external/nested" "$fixture_repo/.config/custom/external-dir"
ln -s external-dir/../settings "$fixture_repo/.config/custom/external-parent"
ln -s "$test_root/external/missing" "$fixture_repo/.config/custom/external-broken"
ln -s '../repo with spaces/.config' "$test_home/.config"
for name in bashrc latexmkrc inputrc; do
    ln -s "../repo with spaces/rc/.$name" "$test_home/.$name"
done
ln -s "$fixture_repo/rc/.gitignore_global" "$test_home/.gitignore_global"

# A late content conflict must block both link updates and host-file copying.
printf 'local\n' > "$fixture_repo/.config/nvim/init.lua"
printf 'repo\n' > "$fixture_repo/config/nvim/init.lua"
if run_init; then printf 'FAIL: accepted conflicting old settings\n' >&2; exit 1; fi
[ "$(readlink "$test_home/.config")" = '../repo with spaces/.config' ]
[ "$(readlink "$test_home/.bashrc")" = '../repo with spaces/rc/.bashrc' ]
assert_absent "$fixture_repo/config/bash/host.sh"
[ "$(cat "$fixture_repo/config/nvim/init.lua")" = repo ]
cp "$fixture_repo/config/nvim/init.lua" "$fixture_repo/.config/nvim/init.lua"

# Existing unique content behind an owned old root link is protected as well.
printf 'unique bashrc\n' > "$fixture_repo/rc/.bashrc"
if run_init; then printf 'FAIL: ignored custom legacy bashrc\n' >&2; exit 1; fi
[ "$(cat "$fixture_repo/rc/.bashrc")" = 'unique bashrc' ]
assert_absent "$fixture_repo/config/bash/host.sh"
rm "$fixture_repo/rc/.bashrc"

mkfifo "$fixture_repo/.config/custom/pipe"
if run_init; then printf 'FAIL: copied a special file\n' >&2; exit 1; fi
[ -p "$fixture_repo/.config/custom/pipe" ]
assert_absent "$fixture_repo/config/bash/host.sh"
rm "$fixture_repo/.config/custom/pipe"
printf 'PASS: differing legacy contents and special files stop the entire migration\n'

run_init --check
[ -L "$test_home/.config" ]
assert_absent "$fixture_repo/config/bash/host.sh"
run_init
[ -d "$test_home/.config" ]
[ ! -L "$test_home/.config" ]
for name in bashrc latexmkrc inputrc gitignore_global; do
    [ "$test_home/.$name" -ef "$fixture_repo/rc/$name" ]
done
for app in "${apps[@]}"; do
    [ -L "$test_home/.config/$app" ]
    [ "$test_home/.config/$app" -ef "$fixture_repo/config/$app" ]
done
[ "$test_home/.config/bash/host.sh" -ef "$fixture_repo/private/cluster.sh" ]
[ "$(readlink "$test_home/.config/bash/host.sh")" = "$fixture_repo/private/cluster.sh" ]
cmp "$fixture_repo/.config/bash/interactive.local.sh" "$fixture_repo/config/bash/interactive.local.sh"
[ "$(cat "$test_home/.config/custom/settings")" = 'private application settings' ]
[ -d "$test_home/.config/custom/empty" ]
[ "$test_home/.config/custom/relative" -ef "$fixture_repo/private/cluster.sh" ]
[ -L "$test_home/.config/custom/broken" ]
[ ! -e "$test_home/.config/custom/broken" ]
[ -L "$fixture_repo/.config/bash/host.sh" ]
[ -f "$fixture_repo/.config/custom/settings" ]
case "$OSTYPE" in
    darwin*) [ "$(stat -f '%Lp' "$test_home/.config/custom/settings")" = 600 ]; [ "$(stat -f '%Lp' "$test_home/.config/custom/empty")" = 500 ] ;;
    *) [ "$(stat -c '%a' "$test_home/.config/custom/settings")" = 600 ]; [ "$(stat -c '%a' "$test_home/.config/custom/empty")" = 500 ] ;;
esac
run_init
run_init --check
printf 'PASS: server migration preserves host selection, local files, permissions, relative/broken links, and backups\n'
printf 'updated migrated settings\n' > "$test_home/.config/custom/settings"
for name in current chain absolute; do
    [ "$(cat "$test_home/.config/custom/$name")" = 'updated migrated settings' ]
done
[ "$(cat "$fixture_repo/.config/custom/settings")" = 'private application settings' ]
[ "$test_home/.config/custom/config-root" -ef "$test_home/.config" ]
[ "$test_home/.config/custom/style" -ef "$fixture_repo/config/matplotlib/stylelib/style.mplstyle" ]
[ "$test_home/.config/bash/style" -ef "$fixture_repo/config/matplotlib/stylelib/style.mplstyle" ]
[ "$test_home/.config/bash/local-link" -ef "$fixture_repo/config/bash/interactive.local.sh" ]
[ "$(cat "$test_home/.config/custom/external-parent")" = 'external setting' ]
[ "$(readlink "$test_home/.config/custom/external-broken")" = "$test_root/external/missing" ]
[ ! -e "$test_home/.config/custom/external-broken" ]
printf 'PASS: internal links follow migrated settings and renamed tracked files; external targets stay unchanged\n'

# Both generations of whole-config links, including a fully dangling old tree.
test_home="$test_root/new-name whole link"
mkdir "$test_home"
printf 'new-name local setting\n' > "$fixture_repo/config/local-only/settings"
ln -s settings "$fixture_repo/config/local-only/current"
ln -s "$fixture_repo/config" "$test_home/.config"
run_init
[ ! -L "$test_home/.config" ]
[ -d "$test_home/.config/local-only" ]
[ "$test_home/.config/bash" -ef "$fixture_repo/config/bash" ]
printf 'updated new-name setting\n' > "$test_home/.config/local-only/settings"
[ "$(cat "$test_home/.config/local-only/current")" = 'updated new-name setting' ]
[ "$(cat "$fixture_repo/config/local-only/settings")" = 'new-name local setting' ]
test_home="$test_root/dangling old tree"
mkdir "$test_home"
mv "$fixture_repo/.config" "$fixture_repo/old-config-backup"
ln -s "$fixture_repo/.config" "$test_home/.config"
ln -s "$fixture_repo/.gitignore_global" "$test_home/.gitignore_global"
run_init
[ ! -L "$test_home/.config" ]
[ "$test_home/.gitignore_global" -ef "$fixture_repo/rc/gitignore_global" ]
printf 'PASS: whole links using config and fully removed old trees migrate safely\n'

# Failed copying must leave the whole-directory link usable and originals intact.
mv "$fixture_repo/old-config-backup" "$fixture_repo/.config"
printf 'additional local setting\n' > "$fixture_repo/.config/bash/failure.local"
test_home="$test_root/interrupted migration"
mkdir "$test_home" "$test_root/failing-tools"
ln -s "$fixture_repo/.config" "$test_home/.config"
printf '#!/bin/bash\nexit 75\n' > "$test_root/failing-tools/cp"
chmod +x "$test_root/failing-tools/cp"
if /usr/bin/env PATH="$test_root/failing-tools:/usr/bin:/bin" TEST_HOME="$test_home" \
    /bin/bash "$fixture_repo/init.sh" > "$test_root/output" 2>&1; then
    printf 'FAIL: ignored copy failure\n' >&2; exit 1
fi
[ "$(readlink "$test_home/.config")" = "$fixture_repo/.config" ]
[ "$(cat "$fixture_repo/.config/bash/failure.local")" = 'additional local setting' ]
assert_absent "$fixture_repo/config/bash/failure.local"
assert_absent "$test_home/.bashrc"
run_init
[ ! -L "$test_home/.config" ]
printf 'PASS: copy failures leave the old configuration attached, and retry completes migration\n'

# A partly migrated server can still have individual old application links.
test_home="$test_root/old application link"
mkdir -p "$test_home/.config"
printf 'per-app local setting\n' > "$fixture_repo/.config/bash/per-app.local"
ln -s ../matplotlib/stylelib/style.mplstyle "$fixture_repo/.config/bash/per-app-style"
ln -s "$fixture_repo/.config/bash" "$test_home/.config/bash"
run_init
[ "$test_home/.config/bash" -ef "$fixture_repo/config/bash" ]
[ "$(cat "$fixture_repo/config/bash/per-app.local")" = 'per-app local setting' ]
[ "$test_home/.config/bash/per-app-style" -ef "$fixture_repo/config/matplotlib/stylelib/style.mplstyle" ]
printf 'PASS: individual legacy application links preserve local settings before replacement\n'

# Interrupt at the actual system-command boundaries, with no test hooks in init.sh.
mkdir "$test_root/interrupt-tools"
cat > "$test_root/interrupt-tools/unlink" <<'SH'
#!/bin/bash
/bin/unlink "$@" || exit
case "${INTERRUPT_AT:-}" in
    unlink) kill -"$INTERRUPT_SIGNAL" "$PPID" ;;
esac
SH
cat > "$test_root/interrupt-tools/mv" <<'SH'
#!/bin/bash
for destination; do :; done
if [ "$destination" = "$TEST_HOME/.config" ] && [ "${INTERRUPT_AT:-}" = mv-fail ]; then
    exit 75
fi
/bin/mv "$@" || exit
if [ "$destination" = "$TEST_HOME/.config" ] && [ "${INTERRUPT_AT:-}" = mv ]; then
    kill -"$INTERRUPT_SIGNAL" "$PPID"
fi
if [ "${destination##*/}" = retired ] && [ "${INTERRUPT_AT:-}" = retire ]; then
    kill -"$INTERRUPT_SIGNAL" "$PPID"
fi
SH
chmod +x "$test_root/interrupt-tools/unlink" "$test_root/interrupt-tools/mv"
for scenario in term-after-unlink kill-after-unlink term-after-mv kill-after-mv failed-mv custom-after-kill repeated-kill; do
    test_home="$test_root/$scenario"
    mkdir "$test_home"
    ln -s "$fixture_repo/.config" "$test_home/.config"
    interrupt_at=unlink
    interrupt_signal=TERM
    case "$scenario" in
        *kill*) interrupt_signal=KILL ;;
    esac
    case "$scenario" in
        *after-mv) interrupt_at=mv ;;
        failed-mv) interrupt_at=mv-fail ;;
    esac
    status=0
    /usr/bin/env PATH="$test_root/interrupt-tools:/usr/bin:/bin" TEST_HOME="$test_home" \
        INTERRUPT_AT="$interrupt_at" INTERRUPT_SIGNAL="$interrupt_signal" \
        /bin/bash "$fixture_repo/init.sh" > "$test_root/output" 2>&1 || status=$?
    case "$scenario" in
        *kill*) [ "$status" -eq 137 ] ;;
        failed-mv) [ "$status" -eq 75 ] ;;
        *) [ "$status" -eq 143 ] ;;
    esac
    [ -L "$test_home/.config.init-pending/original" ]
    case "$scenario" in
        *after-mv)
            [ ! -L "$test_home/.config" ]
            [ "$(cat "$test_home/.config/custom/settings")" = 'private application settings' ] ;;
        *kill*) assert_absent "$test_home/.config" ;;
        *)
            [ -L "$test_home/.config" ]
            [ "$test_home/.config" -ef "$fixture_repo/.config" ] ;;
    esac
    if [ "$scenario" = custom-after-kill ]; then
        # A newly created config must not be mistaken for the renamed staging dir.
        mkdir "$test_home/.config"
        printf 'user replacement\n' > "$test_home/.config/keep"
        if run_init --check; then printf 'FAIL: check accepted replacement config\n' >&2; exit 1; fi
        if run_init; then printf 'FAIL: overwrote replacement config\n' >&2; exit 1; fi
        [ "$(cat "$test_home/.config/keep")" = 'user replacement' ]
        [ -d "$test_home/.config.init-pending/new/custom" ]
        assert_absent "$test_home/.bashrc"
        mv "$test_home/.config" "$test_home/custom-saved"
    fi
    run_init --check
    [ -L "$test_home/.config.init-pending/original" ]
    case "$scenario" in
        kill-after-unlink|custom-after-kill) assert_absent "$test_home/.config" ;;
        term-after-unlink|failed-mv) [ -L "$test_home/.config" ] ;;
    esac
    if [ "$scenario" = repeated-kill ]; then
        # Kill recovery itself after retiring its record. The original link must
        # already be restored, so another retry can safely start over.
        status=0
        /usr/bin/env PATH="$test_root/interrupt-tools:/usr/bin:/bin" TEST_HOME="$test_home" \
            INTERRUPT_AT=retire INTERRUPT_SIGNAL=KILL \
            /bin/bash "$fixture_repo/init.sh" > "$test_root/output" 2>&1 || status=$?
        [ "$status" -eq 137 ]
        [ -L "$test_home/.config" ]
        [ "$test_home/.config" -ef "$fixture_repo/.config" ]
        assert_absent "$test_home/.config.init-pending"
    fi
    run_init
    run_init
    run_init --check
    assert_absent "$test_home/.config.init-pending"
    [ ! -L "$test_home/.config" ]
    [ "$test_home/.bashrc" -ef "$fixture_repo/rc/bashrc" ]
    [ "$test_home/.config/bash/host.sh" -ef "$fixture_repo/private/cluster.sh" ]
    [ "$(cat "$test_home/.config/custom/settings")" = 'private application settings' ]
    printf 'after recovery\n' > "$test_home/.config/custom/settings"
    [ "$(cat "$test_home/.config/custom/current")" = 'after recovery' ]
    [ "$test_home/.config/custom/style" -ef "$fixture_repo/config/matplotlib/stylelib/style.mplstyle" ]
    [ "$(cat "$fixture_repo/.config/custom/settings")" = 'private application settings' ]
    printf 'PASS: %s preserves settings and safely resumes; --check is read-only\n' "$scenario"
done

# A colliding recovery-record name is not permission to delete user files.
test_home="$test_root/foreign recovery record"
mkdir "$test_home" "$test_root/foreign-record"
printf 'keep\n' > "$test_root/foreign-record/settings"
ln -s "$test_root/foreign-record" "$test_home/.config.init-pending"
if run_init; then printf 'FAIL: accepted a foreign recovery record\n' >&2; exit 1; fi
assert_absent "$test_home/.config"
assert_absent "$test_home/.bashrc"
[ "$(cat "$test_home/.config.init-pending/settings")" = keep ]
printf 'PASS: an unrelated recovery-record path is protected\n'
