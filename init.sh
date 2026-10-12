#!/bin/bash
set -eu

check_only=false
case "${1:-}" in
    --check) check_only=true ;;
    --help|-h)
        printf 'Usage: bash init.sh [--check]\nInstall links or migrate this checkout\047s legacy links; never overwrite custom settings.\n'
        exit 0 ;;
    '') ;;
    *) printf 'Usage: bash init.sh [--check]\n' >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then
    printf 'Usage: bash init.sh [--check]\n' >&2
    exit 2
fi
repo_dir=$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [ -z "${HOME:-}" ] || [ ! -d "$HOME" ]; then
    printf 'HOME must name an existing directory.\n' >&2
    exit 1
fi
exists() { [ -e "$1" ] || [ -L "$1" ]; }
# Recognize known old destinations even after git pull has removed the target.
# Resolve the parent physically so relative links and checkout aliases also work.
points_to() {
    local value parent
    [ -L "$1" ] || return 1
    value=$(readlink "$1")
    case "$value" in /*) ;; *) value="$(dirname -- "$1")/$value" ;; esac
    [ "$value" = "$2" ] && return 0
    parent=$(cd -P -- "$(dirname -- "$value")" 2>/dev/null && pwd) || return 1
    [ "$parent/$(basename -- "$value")" = "$2" ]
}
conflict=false
report_conflict() { printf 'CONFLICT: %s\n' "$*" >&2; conflict=true; }

sources=(rc/bashrc rc/latexmkrc rc/gitignore_global rc/inputrc)
targets=(.bashrc .latexmkrc .gitignore_global .inputrc)
legacy=(rc/.bashrc rc/.latexmkrc .gitignore_global rc/.inputrc)
apps=(alacritty bash git htop iterm2 matplotlib nvim)
for app in "${apps[@]}"; do
    sources+=("config/$app")
    targets+=(".config/$app")
    legacy+=(".config/$app")
done

# A published transaction contains a fully prepared directory. Its inode identifies
# a completed rename even if the process died before removing the transaction.
directory_id() {
    case "$OSTYPE" in
        darwin*) stat -f '%d:%i' "$1" ;;
        *) stat -c '%d:%i' "$1" ;;
    esac
}
transaction="$HOME/.config.init-pending"
pending=false
config_link="$HOME/.config"
if exists "$transaction"; then
    if [ -L "$transaction" ] || [ ! -d "$transaction" ] ||
        { ! points_to "$transaction/original" "$repo_dir/.config" &&
          ! points_to "$transaction/original" "$repo_dir/config"; } ||
        [ -L "$transaction/identity" ] || [ ! -f "$transaction/identity" ]; then
        report_conflict "$transaction is not a recognized migration record"
    else
        pending=true
        for entry in "$transaction/"* "$transaction/".[!.]* "$transaction/"..?*; do
            exists "$entry" || continue
            case "${entry##*/}" in
                original|identity) ;;
                new)
                    if [ -L "$entry" ] || [ ! -d "$entry" ]; then
                        report_conflict "$entry is not a real staging directory"
                    fi ;;
                *) report_conflict "unexpected entry in migration record: $entry" ;;
            esac
        done
        if ! exists "$HOME/.config"; then
            config_link="$transaction/original"
        elif points_to "$HOME/.config" "$(readlink "$transaction/original")"; then
            : # The old link was never detached, or the exit trap restored it.
        elif [ ! -L "$HOME/.config" ] && [ -d "$HOME/.config" ] &&
            ! exists "$transaction/new" &&
            [ "$(directory_id "$HOME/.config")" = "$(cat "$transaction/identity")" ]; then
            : # Rename completed; normal preflight still checks the installed links.
        else
            report_conflict '~/.config changed during an interrupted migration; review it before retrying'
        fi
        printf 'RECOVER: %s\n' "$transaction"
    fi
fi
migrate_config=false
old_config=
if [ -L "$config_link" ]; then
    for candidate in "$repo_dir/.config" "$repo_dir/config"; do
        if points_to "$config_link" "$candidate"; then
            # Do not follow a checkout's old directory into an unrelated tree.
            if [ -L "$candidate" ] || { exists "$candidate" && [ ! -d "$candidate" ]; }; then
                report_conflict "$candidate must be a real directory or absent"
            else
                migrate_config=true
                old_config=$candidate
                printf 'MIGRATE: ~/.config -> real directory with application links\n'
            fi
            break
        fi
    done
    if ! "$migrate_config"; then report_conflict '~/.config is not a recognized link to this checkout'; fi
elif exists "$HOME/.config" && [ ! -d "$HOME/.config" ]; then
    report_conflict '~/.config is not a directory'
fi

# Resolve parent symlinks, but retain the final link target itself. In particular,
# '..' after a symlinked directory must follow filesystem semantics, not merely
# remove a textual component. Missing old tracked directories still normalize.
link_destination() {
    local value rest part path= hops=0 app suffix j
    value=$(readlink "$1")
    case "$value" in /*) ;; *) value="$(dirname -- "$1")/$value" ;; esac
    rest=${value#/}
    while [ -n "$rest" ]; do
        part=${rest%%/*}
        if [ "$rest" = "$part" ]; then rest=; else rest=${rest#*/}; fi
        case "$part" in
            ''|.) continue ;;
            ..) path=${path%/*}; continue ;;
        esac
        path="$path/$part"
        if [ -n "$rest" ] && [ -L "$path" ]; then
            hops=$((hops + 1))
            [ "$hops" -le 40 ] || { printf 'Symlink loop: %s\n' "$1" >&2; return 1; }
            value=$(readlink "$path")
            path=${path%/*}
            case "$value" in /*) path=; value=${value#/} ;; esac
            rest="$value/$rest"
        fi
    done
    if "$migrate_config" && [ "$path" = "$old_config" ]; then
        printf '%s/.config\n' "$HOME"; return
    fi
    case "$path" in
        "$repo_dir/.config/"*)
            suffix=${path#"$repo_dir/.config/"}; app=${suffix%%/*}
            for j in "${!apps[@]}"; do
                if [ "$app" = "${apps[$j]}" ]; then
                    printf '%s/config/%s\n' "$repo_dir" "$suffix"; return
                fi
            done
            if "$migrate_config" && [ "$old_config" = "$repo_dir/.config" ]; then
                printf '%s/.config/%s\n' "$HOME" "$suffix"; return
            fi ;;
        "$repo_dir/config/"*)
            if "$migrate_config" && [ "$old_config" = "$repo_dir/config" ]; then
                suffix=${path#"$repo_dir/config/"}; app=${suffix%%/*}
                for value in "${apps[@]}"; do
                    if [ "$app" = "$value" ]; then printf '%s\n' "$path"; return; fi
                done
                printf '%s/.config/%s\n' "$HOME" "$suffix"; return
            fi ;;
    esac
    printf '%s\n' "${path:-/}"
}

# Collect missing entries; inspect the whole tree before copying any local settings.
copy_from=()
copy_to=()
plan_copy() {
    local from=$1 to=$2 fresh=${3:-false} child expected existing=false
    if ! "$fresh" && exists "$to"; then existing=true; fi
    if [ -L "$from" ]; then
        if ! expected=$(link_destination "$from"); then
            report_conflict "cannot resolve legacy link $from"; return
        fi
        if "$existing"; then
            if points_to "$to" "$expected"; then return; fi
            report_conflict "$to differs from legacy symlink $from"
        else
            copy_from+=("$from"); copy_to+=("$to")
            printf 'PRESERVE LINK: %s -> %s\n' "$from" "$to"
        fi
    elif [ -d "$from" ]; then
        if [ ! -r "$from" ] || [ ! -x "$from" ]; then
            report_conflict "$from cannot be inspected completely"
            return
        fi
        if "$existing" && { [ -L "$to" ] || [ ! -d "$to" ]; }; then
            report_conflict "$to conflicts with legacy directory $from"
            return
        fi
        if ! "$existing"; then
            copy_from+=("$from"); copy_to+=("$to")
            printf 'PRESERVE DIRECTORY: %s -> %s\n' "$from" "$to"
        fi
        for child in "$from/"* "$from/".[!.]* "$from/"..?*; do
            exists "$child" || continue
            plan_copy "$child" "$to/${child##*/}" "$fresh"
        done
    elif [ -f "$from" ]; then
        if "$existing"; then
            if [ ! -L "$to" ] && [ -f "$to" ] && cmp -s "$from" "$to"; then return; fi
            report_conflict "$to differs from legacy file $from"
        else
            copy_from+=("$from"); copy_to+=("$to")
            printf 'PRESERVE FILE: %s -> %s\n' "$from" "$to"
        fi
    else
        report_conflict "$from is a special file; move or stop its owning application before retrying"
    fi
}

# For a whole-directory migration, ~/.config currently exposes the OLD contents.
# Inspect the intended new destinations instead of mistaking those contents for conflicts.
replace=()
for i in "${!sources[@]}"; do
    source_path="$repo_dir/${sources[$i]}"
    target_path="$HOME/${targets[$i]}"
    replace[$i]=false
    if [ ! -e "$source_path" ]; then
        report_conflict "missing source $source_path"
    elif "$migrate_config" && [ "$i" -ge 4 ]; then
        printf 'CREATE: %s -> %s\n' "$target_path" "$source_path"
    elif [ -L "$target_path" ] && [ "$target_path" -ef "$source_path" ]; then
        printf 'OK: %s -> %s\n' "$target_path" "$source_path"
    elif points_to "$target_path" "$repo_dir/${legacy[$i]}" ||
        { [ "$i" -eq 2 ] && points_to "$target_path" "$repo_dir/rc/.gitignore_global"; }; then
        replace[$i]=true
        printf 'RELINK: %s -> %s\n' "$target_path" "$source_path"
        if [ "$i" -lt 4 ] && [ -e "$target_path" ] &&
            { [ ! -f "$target_path" ] || ! cmp -s "$target_path" "$source_path"; }; then
            report_conflict "$target_path still exposes different legacy content; review it before migration"
        fi
    elif exists "$target_path"; then
        report_conflict "$target_path (expected link to $source_path)"
    else
        printf 'CREATE: %s -> %s\n' "$target_path" "$source_path"
    fi
done

if "$migrate_config" && [ "$old_config" != "$repo_dir/config" ] && [ -d "$old_config" ]; then
    for entry in "$old_config/"* "$old_config/".[!.]* "$old_config/"..?*; do
        exists "$entry" || continue
        app=${entry##*/}
        managed=false
        for name in "${apps[@]}"; do [ "$app" != "$name" ] || managed=true; done
        if "$managed"; then
            plan_copy "$entry" "$repo_dir/config/$app"
        else
            # The future real ~/.config will initially have no unmanaged entries.
            plan_copy "$entry" "$HOME/.config/$app" true
        fi
    done
elif "$migrate_config" && [ "$old_config" = "$repo_dir/config" ]; then
    # Preserve unmanaged entries when the whole link already uses the new source name.
    for entry in "$old_config/"* "$old_config/".[!.]* "$old_config/"..?*; do
        exists "$entry" || continue
        app=${entry##*/}
        managed=false
        for name in "${apps[@]}"; do [ "$app" != "$name" ] || managed=true; done
        "$managed" || plan_copy "$entry" "$HOME/.config/$app" true
    done
fi
if ! "$migrate_config"; then
    for i in "${!sources[@]}"; do
        if [ "$i" -ge 4 ] && "${replace[$i]}" && exists "$repo_dir/${legacy[$i]}"; then
            if [ -L "$repo_dir/.config" ]; then
                report_conflict "$repo_dir/.config is a symlink; cannot migrate its contents safely"
            else
                plan_copy "$repo_dir/${legacy[$i]}" "$repo_dir/${sources[$i]}"
            fi
        fi
    done
fi
if "$conflict"; then
    printf 'Nothing changed. Review the conflicts before retrying.\n' >&2
    exit 1
fi
if "$check_only"; then printf 'Check passed; nothing changed.\n'; exit 0; fi

# Catchable interruptions restore the old link. SIGKILL leaves the published
# transaction for the next run. Never replace a path created by another process.
config_stage=
restore_config() {
    local status=$?
    trap - EXIT
    if [ -L "$transaction/original" ] && ! exists "$HOME/.config"; then
        ln -s -- "$(readlink "$transaction/original")" "$HOME/.config" || :
    fi
    if [ -n "$config_stage" ]; then rm -rf -- "$config_stage"; fi
    exit "$status"
}
trap restore_config EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
if "$pending"; then
    if ! exists "$HOME/.config"; then
        ln -s -- "$(readlink "$transaction/original")" "$HOME/.config"
    fi
    # Retire the record atomically. A kill during cleanup leaves only an unused
    # temporary directory, never a half-deleted record needed for recovery.
    config_stage=$(mktemp -d "$HOME/.config.init.XXXXXX")
    mv -- "$transaction" "$config_stage/retired"
    rm -rf -- "$config_stage"
    config_stage=
fi
if "$migrate_config"; then
    config_stage=$(mktemp -d "$HOME/.config.init.XXXXXX")
    mkdir -m 700 "$config_stage/new"
fi
created_dirs=()
dir_modes=()
for i in "${!copy_from[@]}"; do
    from=${copy_from[$i]}
    to=${copy_to[$i]}
    if "$migrate_config"; then
        case "$to" in "$HOME/.config/"*) to="$config_stage/new/${to#"$HOME/.config/"}" ;; esac
    fi
    if exists "$to"; then printf 'Destination changed: %s; stopped.\n' "$to" >&2; exit 1; fi
    if [ -L "$from" ]; then
        value=$(link_destination "$from")
        ln -s -- "$value" "$to"
    elif [ -d "$from" ]; then
        mkdir -m 700 -- "$to"
        created_dirs+=("$to")
        case "$OSTYPE" in
            darwin*) dir_modes+=("$(stat -f '%Lp' "$from")") ;;
            *) dir_modes+=("$(stat -c '%a' "$from")") ;;
        esac
    else
        cp -pn -- "$from" "$to"
    fi
done
# Apply directory permissions last so read-only source directories can be copied.
for ((i=${#created_dirs[@]}-1; i>=0; i--)); do
    chmod "${dir_modes[$i]}" "${created_dirs[$i]}"
done
if "$migrate_config"; then
    for app in "${apps[@]}"; do ln -s "$repo_dir/config/$app" "$config_stage/new/$app"; done
    points_to "$HOME/.config" "$old_config" || { printf 'Configuration link changed; stopped.\n' >&2; exit 1; }
    ln -s -- "$old_config" "$config_stage/original"
    directory_id "$config_stage/new" > "$config_stage/identity"
    if exists "$transaction"; then printf 'Migration record appeared; stopped.\n' >&2; exit 1; fi
    mv -- "$config_stage" "$transaction"
    config_stage=
    unlink "$HOME/.config"
    if exists "$HOME/.config"; then printf 'Configuration path appeared; stopped.\n' >&2; exit 1; fi
    mv -- "$transaction/new" "$HOME/.config"
    config_stage=$(mktemp -d "$HOME/.config.init.XXXXXX")
    mv -- "$transaction" "$config_stage/retired"
    rm -rf -- "$config_stage"
    config_stage=
else
    mkdir -p -- "$HOME/.config"
fi
for i in "${!sources[@]}"; do
    source_path="$repo_dir/${sources[$i]}"
    target_path="$HOME/${targets[$i]}"
    if [ -L "$target_path" ] && [ "$target_path" -ef "$source_path" ]; then continue; fi
    if "${replace[$i]}"; then
        if points_to "$target_path" "$repo_dir/${legacy[$i]}" ||
            { [ "$i" -eq 2 ] && points_to "$target_path" "$repo_dir/rc/.gitignore_global"; }; then
            unlink "$target_path"
        else
            printf 'Link changed: %s; stopped.\n' "$target_path" >&2; exit 1
        fi
    fi
    if exists "$target_path" || ! ln -sn -- "$source_path" "$target_path"; then
        printf 'Stopped at %s; earlier migration steps may already have completed.\n' "$target_path" >&2
        exit 1
    fi
done
printf 'Links ready. Host settings were preserved if present; configure host.sh if this is a new installation.\n'
