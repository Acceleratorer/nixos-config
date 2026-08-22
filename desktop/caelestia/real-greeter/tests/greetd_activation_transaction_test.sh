#!/usr/bin/env bash

set -euo pipefail

current_unit=${1:?missing accepted greetd unit}
candidate_unit=${2:?missing candidate greetd unit}

test -r "$current_unit"
test -r "$candidate_unit"

unit_value() {
    local key=$1
    local unit=$2
    sed -n "s/^${key}=//p" "$unit" | tail -n 1
}

bool_value() {
    local key=$1
    local unit=$2
    local value
    value=$(unit_value "$key" "$unit")
    case "$value" in
    true|yes|on|1) printf '%s\n' true ;;
    false|no|off|0) printf '%s\n' false ;;
    "") printf '%s\n' "${3:-true}" ;;
    *)
        printf 'unexpected %s value %q in %s\n' "$key" "$value" "$unit" >&2
        return 1
        ;;
    esac
}

transaction_plan() {
    local old_unit=$1
    local new_unit=$2
    local restart stop

    test "$(unit_value ExecStart "$old_unit")" != "$(unit_value ExecStart "$new_unit")"
    restart=$(bool_value X-RestartIfChanged "$new_unit" true)
    stop=$(bool_value X-StopIfChanged "$new_unit" true)

    if [[ "$restart" != true ]]; then
        printf '%s\n' skip
    elif [[ "$stop" == true ]]; then
        printf '%s\n' stop-start
    else
        printf '%s\n' restart
    fi
}

simulate_interrupted_transaction() {
    local plan=$1
    local state=active
    local log=$2

    : > "$log"
    case "$plan" in
    stop-start)
        printf '%s\n' stop >> "$log"
        state=inactive
        # This is the exact observed interruption window: activation stops
        # greetd and the process exits before the later start operation.
        ;;
    restart)
        printf '%s\n' restart >> "$log"
        state=active
        ;;
    skip)
        printf '%s\n' skip >> "$log"
        ;;
    *)
        printf 'unexpected transaction plan %q\n' "$plan" >&2
        return 1
        ;;
    esac

    printf '%s\n' "$state"
}

test "$(unit_value X-RestartIfChanged "$candidate_unit")" != false
test "$(unit_value X-StopIfChanged "$candidate_unit")" = false
test "$(transaction_plan "$current_unit" "$candidate_unit")" = restart

# Prove that the old candidate policy reproduced the incident. Removing the
# repair marker restores the default stop-then-start plan, and the isolated
# interruption leaves the fake service inactive with only a stop recorded.
broken_unit=$(mktemp)
broken_log=$(mktemp)
trap 'rm -f "$broken_unit" "$broken_log"' EXIT
sed '/^X-StopIfChanged=false$/d' "$candidate_unit" > "$broken_unit"
test "$(transaction_plan "$current_unit" "$broken_unit")" = stop-start
test "$(simulate_interrupted_transaction stop-start "$broken_log")" = inactive
grep -Fqx stop "$broken_log"
! grep -Fqx start "$broken_log"

# The repaired policy has no stop-without-start window in this fixture.
test "$(simulate_interrupted_transaction restart "$broken_log")" = active
grep -Fqx restart "$broken_log"
! grep -Fqx stop "$broken_log"

printf '%s\n' 'phase13b greetd activation transaction tests: pass'
