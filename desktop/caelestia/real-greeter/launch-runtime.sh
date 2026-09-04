#!/bin/sh

set -eu

entrypoint=${1:?missing Quickshell entrypoint}
shift

runtime_root=${CAELESTIA_GREETER_RUNTIME_DIR:-"${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/caelestia-real-greeter"}

umask 077
for directory in \
    "$runtime_root" \
    "$runtime_root/cache" \
    "$runtime_root/config" \
    "$runtime_root/config/caelestia" \
    "$runtime_root/config/caelestia/monitors" \
    "$runtime_root/data" \
    "$runtime_root/home" \
    "$runtime_root/state" \
    "$runtime_root/state/caelestia" \
    "$runtime_root/state/caelestia/wallpaper"; do
    [ ! -L "$directory" ] || exit 1
done
mkdir -p \
    "$runtime_root/cache" \
    "$runtime_root/config/caelestia/monitors" \
    "$runtime_root/data" \
    "$runtime_root/home" \
    "$runtime_root/state/caelestia/wallpaper"
chmod 0700 \
    "$runtime_root" \
    "$runtime_root/cache" \
    "$runtime_root/config" \
    "$runtime_root/config/caelestia" \
    "$runtime_root/config/caelestia/monitors" \
    "$runtime_root/data" \
    "$runtime_root/home" \
    "$runtime_root/state" \
    "$runtime_root/state/caelestia" \
    "$runtime_root/state/caelestia/wallpaper"

for regular_target in \
    "$runtime_root/state/caelestia/scheme.json" \
    "$runtime_root/state/caelestia/wallpaper/path.txt" \
    "$runtime_root/config/caelestia/shell.json" \
    "$runtime_root/config/caelestia/shell-tokens.json" \
    "$runtime_root/home/.face"; do
    [ ! -L "$regular_target" ] || exit 1
    [ ! -e "$regular_target" ] || [ -f "$regular_target" ] || exit 1
done
wallpaper_current="$runtime_root/state/caelestia/wallpaper/current"
if [ -e "$wallpaper_current" ] && [ ! -L "$wallpaper_current" ]; then
    exit 1
fi

selected_scheme=@CHISA_SCHEME@
selected_wallpaper=@CHISA_WALLPAPER@
if resolution="$(@RESOLVER@ 2>/dev/null)"; then
    selected="$(
        printf '%s' "$resolution" |
            @PYTHON@ -c '
import json
import sys

value = json.load(sys.stdin)
if set(value) != {
    "schemaVersion", "packId", "wallpaperPackId", "generation",
    "source", "schemePath", "schemeSha256", "wallpaperPath",
    "wallpaperSha256", "thumbnailPath", "thumbnailSha256",
}:
    raise SystemExit(1)
print(value["schemePath"] + "\t" + value["wallpaperPath"])
'
    )" || selected=
    if [ -n "$selected" ]; then
        IFS='	' read -r \
            selected_scheme_candidate \
            selected_wallpaper_candidate <<EOF
$selected
EOF
        if [ -f "$selected_scheme_candidate" ] \
            && [ ! -L "$selected_scheme_candidate" ] \
            && [ -f "$selected_wallpaper_candidate" ] \
            && [ ! -L "$selected_wallpaper_candidate" ]; then
            selected_scheme=$selected_scheme_candidate
            selected_wallpaper=$selected_wallpaper_candidate
        fi
    fi
fi

install -m 0600 "$selected_scheme" "$runtime_root/state/caelestia/scheme.json"
printf '%s\n' "$selected_wallpaper" \
    > "$runtime_root/state/caelestia/wallpaper/path.txt"
chmod 0600 "$runtime_root/state/caelestia/wallpaper/path.txt"
wallpaper_temporary="$runtime_root/state/caelestia/wallpaper/.current.$$"
[ ! -e "$wallpaper_temporary" ] && [ ! -L "$wallpaper_temporary" ] || exit 1
ln -s "$selected_wallpaper" "$wallpaper_temporary"
mv -f "$wallpaper_temporary" "$wallpaper_current"
install -m 0600 @CONFIG@/caelestia/shell.json "$runtime_root/config/caelestia/shell.json"
install -m 0600 @CONFIG@/caelestia/shell-tokens.json "$runtime_root/config/caelestia/shell-tokens.json"
install -m 0600 @AVATAR@ "$runtime_root/home/.face"

export HOME="$runtime_root/home"
export USER="${CAELESTIA_GREETER_PROCESS_USER:-greeter}"
export LOGNAME="$USER"
export XDG_CACHE_HOME="$runtime_root/cache"
export XDG_CONFIG_HOME="$runtime_root/config"
export XDG_DATA_HOME="$runtime_root/data"
export XDG_STATE_HOME="$runtime_root/state"
export XDG_CURRENT_DESKTOP=Cage
export XDG_SESSION_DESKTOP=Cage
export XDG_SESSION_TYPE=wayland

exec @QUICKSHELL@ -p "$entrypoint" "$@"
