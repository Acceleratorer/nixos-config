set -euo pipefail

candidate=${1:?missing candidate greeter executable}
recovery=${2:?missing recovery greeter executable}
recovery_log=${3:?missing recovery greeter log path}

: "${GREETD_SOCK:?GREETD_SOCK is required}"
: "${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
: "${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is required}"

if (( EUID == 0 )); then
    echo "Refusing to run the greeter launcher as root." >&2
    exit 70
fi

runtime_root=${CAELESTIA_GREETER_RUNTIME_ROOT:-"$XDG_RUNTIME_DIR/caelestia-real-greeter"}
state_root=${CAELESTIA_GREETER_STATE_ROOT:-"/var/lib/caelestia-real-greeter"}
control_dir="$runtime_root/control"
candidate_runtime="$runtime_root/runtime"
recovery_runtime_root="$runtime_root/recovery"
recovery_state_root="$state_root/recovery"
case "$WAYLAND_DISPLAY" in
    /*) candidate_wayland_display=$WAYLAND_DISPLAY ;;
    *) candidate_wayland_display="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ;;
esac

umask 077
install -d -m 0700 \
    "$runtime_root" \
    "$runtime_root/cache" \
    "$runtime_root/candidate" \
    "$runtime_root/config" \
    "$runtime_root/control" \
    "$runtime_root/data" \
    "$runtime_root/recovery" \
    "$runtime_root/recovery/cache" \
    "$runtime_root/recovery/config" \
    "$runtime_root/recovery/data" \
    "$runtime_root/runtime" \
    "$state_root" \
    "$state_root/home" \
    "$state_root/recovery" \
    "$state_root/recovery/home" \
    "$state_root/recovery/state" \
    "$state_root/state"

rm -f \
    "$control_dir/auth-began" \
    "$control_dir/cancel-ack" \
    "$control_dir/ready" \
    "$control_dir/recovery-requested" \
    "$control_dir/session-started"

candidate_status=0
env \
    HOME="$state_root/home" \
    WAYLAND_DISPLAY="$candidate_wayland_display" \
    XDG_RUNTIME_DIR="$candidate_runtime" \
    XDG_CACHE_HOME="$runtime_root/cache" \
    XDG_CONFIG_HOME="$runtime_root/config" \
    XDG_DATA_HOME="$runtime_root/data" \
    XDG_STATE_HOME="$state_root/state" \
    CAELESTIA_GREETER_CONTROL_DIR="$control_dir" \
    CAELESTIA_GREETER_RUNTIME_DIR="$runtime_root/candidate" \
    CAELESTIA_GREETER_PROCESS_USER="$(id -un)" \
    CAELESTIA_GREETER_USER=accelra \
    "$candidate" || candidate_status=$?

start_recovery() {
    exec env \
        HOME="$recovery_state_root/home" \
        XDG_CACHE_HOME="$recovery_runtime_root/cache" \
        XDG_CONFIG_HOME="$recovery_runtime_root/config" \
        XDG_DATA_HOME="$recovery_runtime_root/data" \
        XDG_STATE_HOME="$recovery_state_root/state" \
        "$recovery" --logs "$recovery_log" --log-level warn
}

if (( candidate_status == 0 )); then
    if [[ -f "$control_dir/session-started" ]] && [[ $(<"$control_dir/session-started") == "session-started-v1" ]]; then
        exit 0
    fi

    if [[ ! -e "$control_dir/auth-began" ]] && [[ ! -e "$control_dir/recovery-requested" ]]; then
        start_recovery
    fi

    echo "Candidate exited without a proven session handoff." >&2
    exit 73
fi

if (( candidate_status == 42 )); then
    if [[ -f "$control_dir/cancel-ack" ]] && [[ $(<"$control_dir/cancel-ack") == "cancel-ack-v1" ]]; then
        start_recovery
    fi

    echo "Candidate returned the recovery exit code without an acknowledged cancellation." >&2
    exit 71
fi

if [[ ! -e "$control_dir/auth-began" ]] && [[ ! -e "$control_dir/recovery-requested" ]]; then
    start_recovery
fi

exit "$candidate_status"
