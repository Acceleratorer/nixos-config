#!/bin/sh

set -eu

entrypoint=${1:?missing Quickshell entrypoint}
shift

runtime_root=${CAELESTIA_GREETER_RUNTIME_DIR:-"${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/caelestia-real-greeter"}

umask 077
mkdir -p \
    "$runtime_root/cache" \
    "$runtime_root/config/caelestia/monitors" \
    "$runtime_root/data" \
    "$runtime_root/home" \
    "$runtime_root/state/caelestia"

install -m 0600 @SCHEME@ "$runtime_root/state/caelestia/scheme.json"
install -m 0600 @CONFIG@/caelestia/shell.json "$runtime_root/config/caelestia/shell.json"
install -m 0600 @CONFIG@/caelestia/shell-tokens.json "$runtime_root/config/caelestia/shell-tokens.json"

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
