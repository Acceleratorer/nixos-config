#!/usr/bin/env bash

set -euo pipefail

case "$(basename "$0")" in
phase13b-candidate)
    : "${GREETD_SOCK:?candidate did not inherit GREETD_SOCK}"
    : "${XDG_RUNTIME_DIR:?candidate did not inherit XDG_RUNTIME_DIR}"
    : "${CAELESTIA_GREETER_CONTROL_DIR:?missing candidate control directory}"
    : "${CAELESTIA_GREETER_RUNTIME_DIR:?missing candidate runtime directory}"
    : "${CAELESTIA_GREETER_PROCESS_USER:?missing candidate process user}"
    : "${CAELESTIA_GREETER_USER:?missing authentication username}"

    test "$GREETD_SOCK" = "$PHASE13B_EXPECTED_SOCK"
    test "$WAYLAND_DISPLAY" = "$PHASE13B_EXPECTED_WAYLAND"
    test "$XDG_RUNTIME_DIR" = "$CAELESTIA_GREETER_RUNTIME_ROOT/runtime"
    test "$HOME" = "$CAELESTIA_GREETER_STATE_ROOT/home"
    test "$XDG_CACHE_HOME" = "$CAELESTIA_GREETER_RUNTIME_ROOT/cache"
    test "$XDG_CONFIG_HOME" = "$CAELESTIA_GREETER_RUNTIME_ROOT/config"
    test "$XDG_DATA_HOME" = "$CAELESTIA_GREETER_RUNTIME_ROOT/data"
    test "$XDG_STATE_HOME" = "$CAELESTIA_GREETER_STATE_ROOT/state"
    test "$CAELESTIA_GREETER_RUNTIME_DIR" = "$CAELESTIA_GREETER_RUNTIME_ROOT/candidate"
    test "$CAELESTIA_GREETER_PROCESS_USER" = "$(id -un)"
    test "$CAELESTIA_GREETER_USER" = "accelra"

    for private_dir in \
        "$CAELESTIA_GREETER_RUNTIME_ROOT" \
        "$CAELESTIA_GREETER_RUNTIME_ROOT/cache" \
        "$CAELESTIA_GREETER_RUNTIME_ROOT/candidate" \
        "$CAELESTIA_GREETER_RUNTIME_ROOT/config" \
        "$CAELESTIA_GREETER_RUNTIME_ROOT/control" \
        "$CAELESTIA_GREETER_RUNTIME_ROOT/data" \
        "$CAELESTIA_GREETER_RUNTIME_ROOT/runtime" \
        "$CAELESTIA_GREETER_STATE_ROOT" \
        "$CAELESTIA_GREETER_STATE_ROOT/home" \
        "$CAELESTIA_GREETER_STATE_ROOT/state"; do
        test "$(stat -c %a "$private_dir")" = 700
    done

    case "$PHASE13B_SCENARIO" in
    success)
        printf '%s' session-started-v1 > "$CAELESTIA_GREETER_CONTROL_DIR/session-started"
        exit 0
        ;;
    explicit-recovery)
        printf '%s' auth-began-v1 > "$CAELESTIA_GREETER_CONTROL_DIR/auth-began"
        printf '%s' cancel-ack-v1 > "$CAELESTIA_GREETER_CONTROL_DIR/cancel-ack"
        exit 42
        ;;
    startup-failure)
        exit 74
        ;;
    preauth-crash)
        printf '%s' ready-v1 > "$CAELESTIA_GREETER_CONTROL_DIR/ready"
        exit 75
        ;;
    postauth-crash)
        printf '%s' auth-began-v1 > "$CAELESTIA_GREETER_CONTROL_DIR/auth-began"
        exit 76
        ;;
    ambiguous-clean-exit)
        printf '%s' auth-began-v1 > "$CAELESTIA_GREETER_CONTROL_DIR/auth-began"
        exit 0
        ;;
    unacknowledged-recovery)
        printf '%s' auth-began-v1 > "$CAELESTIA_GREETER_CONTROL_DIR/auth-began"
        printf '%s' recovery-requested-v1 > "$CAELESTIA_GREETER_CONTROL_DIR/recovery-requested"
        exit 42
        ;;
    unacknowledged-initial-recovery)
        printf '%s' recovery-requested-v1 > "$CAELESTIA_GREETER_CONTROL_DIR/recovery-requested"
        exit 72
        ;;
    *)
        exit 77
        ;;
    esac
    ;;
phase13b-recovery)
    : "${GREETD_SOCK:?recovery greeter did not inherit GREETD_SOCK}"
    test "$GREETD_SOCK" = "$PHASE13B_EXPECTED_SOCK"
    test "$WAYLAND_DISPLAY" = phase13b-wayland
    test "$XDG_RUNTIME_DIR" = "$PHASE13B_ORIGINAL_RUNTIME"
    test "${CAELESTIA_GREETER_CONTROL_DIR+x}" != x
    test "${CAELESTIA_GREETER_RUNTIME_DIR+x}" != x
    test "${CAELESTIA_GREETER_PROCESS_USER+x}" != x
    test "$#" -eq 4
    test "$1" = --logs
    test "$2" = "$PHASE13B_RECOVERY_LOG"
    test "$3" = --log-level
    test "$4" = warn
    printf '%s\n' "$PHASE13B_SCENARIO" >> "$PHASE13B_RECOVERY_RESULT"
    exit 0
    ;;
esac

launcher=${1:?missing recovery launcher}
self=$(readlink -f "$0")
test_root=$(mktemp -d -t phase13b-launcher-test.XXXXXXXX)
trap 'rm -rf "$test_root"' EXIT

candidate="$test_root/phase13b-candidate"
recovery="$test_root/phase13b-recovery"
install -m 0700 "$self" "$candidate"
install -m 0700 "$self" "$recovery"
sed -i "1c#!$BASH" "$candidate" "$recovery"

password_sentinel=phase13b-password-literal-must-not-appear
run_number=0

run_scenario() {
    local scenario=$1
    local expected_status=$2
    local expect_recovery=$3
    local runtime_base state_root recovery_log recovery_result output status

    run_number=$((run_number + 1))
    runtime_base="$test_root/session-$run_number"
    state_root="$test_root/state-$run_number"
    recovery_log="$test_root/recovery-$run_number.log"
    recovery_result="$test_root/recovery-$run_number.result"
    output="$test_root/output-$run_number.log"
    mkdir -m 0700 "$runtime_base"

    status=0
    env \
        GREETD_SOCK="$runtime_base/greetd.sock" \
        WAYLAND_DISPLAY=phase13b-wayland \
        XDG_RUNTIME_DIR="$runtime_base" \
        CAELESTIA_GREETER_RUNTIME_ROOT="$runtime_base/private" \
        CAELESTIA_GREETER_STATE_ROOT="$state_root" \
        PHASE13B_EXPECTED_SOCK="$runtime_base/greetd.sock" \
        PHASE13B_EXPECTED_WAYLAND="$runtime_base/phase13b-wayland" \
        PHASE13B_ORIGINAL_RUNTIME="$runtime_base" \
        PHASE13B_RECOVERY_LOG="$recovery_log" \
        PHASE13B_RECOVERY_RESULT="$recovery_result" \
        PHASE13B_SCENARIO="$scenario" \
        bash "$launcher" "$candidate" "$recovery" "$recovery_log" > "$output" 2>&1 || status=$?

    if [[ "$status" -ne "$expected_status" ]]; then
        printf 'scenario %s returned %s, expected %s\n' "$scenario" "$status" "$expected_status" >&2
        sed -n '1,80p' "$output" >&2
        return 1
    fi
    if [[ "$expect_recovery" == yes ]]; then
        if [[ ! -f "$recovery_result" ]] || [[ $(cat "$recovery_result") != "$scenario" ]]; then
            printf 'scenario %s did not launch recovery\n' "$scenario" >&2
            sed -n '1,80p' "$output" >&2
            return 1
        fi
    else
        if [[ -e "$recovery_result" ]]; then
            printf 'scenario %s launched recovery unexpectedly\n' "$scenario" >&2
            return 1
        fi
    fi
    if grep -Fq "$password_sentinel" "$output"; then
        printf 'scenario %s exposed the password sentinel\n' "$scenario" >&2
        return 1
    fi
}

run_scenario success 0 no
run_scenario explicit-recovery 0 yes
run_scenario startup-failure 0 yes
run_scenario preauth-crash 0 yes
run_scenario postauth-crash 76 no
run_scenario ambiguous-clean-exit 73 no
run_scenario unacknowledged-recovery 71 no
run_scenario unacknowledged-initial-recovery 72 no

# A fresh greetd greeter session can select recovery again without a
# candidate -> recovery -> candidate loop inside either launcher instance.
run_scenario explicit-recovery 0 yes

printf '%s\n' "phase13b recovery launcher tests: pass"
