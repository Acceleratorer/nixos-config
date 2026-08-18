#!/usr/bin/env bash

set -Eeuo pipefail

if (( EUID != 0 )); then
    printf '%s\n' 'This audition must be run with sudo from TTY2.' >&2
    exit 64
fi

emergency_exit() {
    local status=$?

    trap - EXIT
    if ! systemctl is-active --quiet greetd; then
        systemctl start greetd || status=70
    fi
    exit "$status"
}
trap emergency_exit EXIT

if (( $# != 0 )); then
    printf '%s\n' 'usage: sudo /nix/store/<candidate-system>/sw/bin/phase13b-real-greeter-audition' >&2
    exit 64
fi

case "$0" in
/nix/store/*/sw/bin/phase13b-real-greeter-audition)
    candidate=${0%/sw/bin/phase13b-real-greeter-audition}
    ;;
*)
    printf '%s\n' 'Invoke this wrapper by its absolute candidate-system path.' >&2
    exit 64
    ;;
esac
candidate=$(readlink -f -- "$candidate")
accepted=$(readlink -f /nix/var/nix/profiles/system)
accepted_link=$(readlink -- /nix/var/nix/profiles/system)
original_current=$(readlink -f /run/current-system)

test -x "$candidate/bin/switch-to-configuration"
test -x "$accepted/bin/switch-to-configuration"
test "$candidate" != "$accepted"
test "$original_current" = "$accepted"
systemctl is-active --quiet greetd

log_file="/var/log/phase13b-real-greeter-audition-$(date +%Y%m%d-%H%M%S).log"
install -m 0600 /dev/null "$log_file"
exec > >(tee -a "$log_file") 2>&1

printf '%s\n' \
    'Phase 13B-R2 real-greeter audition' \
    "candidate: $candidate" \
    "accepted:  $accepted" \
    "log:       $log_file"

accepted_unit=$(readlink -f "$accepted/etc/systemd/system/greetd.service")
accepted_greetd_config=$(
    sed -n 's/^ExecStart=.* --config \([^ ]*\)$/\1/p' "$accepted_unit"
)
test -n "$accepted_greetd_config"
audition_started_epoch=$(date +%s)
audition_started_journal=$(date --iso-8601=seconds)
rollback_required=true
rollback_running=false
audition_succeeded=false

check_profile_invariant() {
    test "$(readlink -f /nix/var/nix/profiles/system)" = "$accepted"
    test "$(readlink -- /nix/var/nix/profiles/system)" = "$accepted_link"
}

check_accepted_greetd() {
    systemctl is-active --quiet greetd
    test "$(readlink -f /etc/systemd/system/greetd.service)" = "$accepted_unit"
    systemctl show greetd -p ExecStart --value | grep -Fq "$accepted_greetd_config"
    test "$(readlink -f /run/current-system)" = "$accepted"
    check_profile_invariant
}

rollback() {
    local switch_status=0
    local restart_status=0

    if [[ "$rollback_running" == true ]]; then
        return 70
    fi
    rollback_running=true

    printf '%s\n' 'AUDITION FAILURE: rolling back to the accepted system.'
    set +e
    timeout --signal=TERM --kill-after=10s 180s \
        "$accepted/bin/switch-to-configuration" test
    switch_status=$?

    # The accepted CryoForge unit intentionally has restartIfChanged=false,
    # so explicitly replace a running candidate process with accepted ReGreet.
    systemctl restart greetd
    restart_status=$?
    if (( restart_status != 0 )); then
        systemctl start greetd
        restart_status=$?
    fi

    if (( switch_status != 0 )); then
        printf 'accepted activation failed with status %s\n' "$switch_status" >&2
    fi
    if (( restart_status != 0 )); then
        printf 'accepted greetd recovery failed with status %s\n' "$restart_status" >&2
    fi

    if ! check_accepted_greetd; then
        # Even if the accepted unit identity could not be proven, make one
        # final idempotent start request so this script never exits inactive.
        systemctl start greetd || true
        printf '%s\n' 'FATAL: rollback did not prove active accepted ReGreet.' >&2
        set -e
        return 70
    fi

    rollback_required=false
    printf '%s\n' 'ROLLBACK: PASS — accepted ReGreet is active and the boot profile is unchanged.'
    set -e
    return 0
}

on_exit() {
    local status=$?
    local rollback_status=0

    trap - EXIT
    if (( status == 0 )) && [[ "$audition_succeeded" == true ]]; then
        if ! systemctl is-active --quiet greetd \
            || ! check_profile_invariant \
            || [[ $(readlink -f /run/current-system) != "$candidate" ]]; then
            status=1
        fi
    fi

    if (( status != 0 )) && [[ "$rollback_required" == true ]]; then
        set +e
        rollback
        rollback_status=$?
        if (( rollback_status != 0 )); then
            status=70
        fi
        set -e
    elif (( status == 0 )); then
        rollback_required=false
    fi

    printf '%s\n' 'FINAL DIAGNOSTICS'
    systemctl show greetd \
        -p ActiveState -p SubState -p MainPID -p Result -p FragmentPath \
        --no-pager || true
    printf 'current system: %s\n' "$(readlink -f /run/current-system)"
    printf 'default system: %s\n' "$(readlink -f /nix/var/nix/profiles/system)"
    journalctl -u greetd.service --since "$audition_started_journal" \
        --no-pager -n 200 || true
    if ! systemctl is-active --quiet greetd; then
        systemctl start greetd || status=70
    fi
    printf 'exit status: %s\n' "$status"
    exit "$status"
}
trap on_exit EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

candidate_unit=$(readlink -f "$candidate/etc/systemd/system/greetd.service")
candidate_greetd_config=$(
    sed -n 's/^ExecStart=.* --config \([^ ]*\)$/\1/p' "$candidate_unit"
)
test -n "$candidate_greetd_config"
grep -Fqx 'X-StopIfChanged=false' "$candidate_unit"
if grep -Fqx 'X-RestartIfChanged=false' "$candidate_unit"; then
    printf '%s\n' 'Candidate greetd unit disables restartIfChanged.' >&2
    exit 65
fi

# Finish any operation lists retained by an older interrupted activation while
# the accepted generation is still active. This does not change the boot
# profile and makes the candidate transaction start from a clean switch state.
printf '%s\n' 'PREFLIGHT: reconciling the accepted test generation.'
timeout --signal=TERM --kill-after=10s 180s \
    "$accepted/bin/switch-to-configuration" test
check_accepted_greetd

printf '%s\n' 'ACTIVATION: applying candidate with switch-to-configuration test.'
timeout --signal=TERM --kill-after=10s 180s \
    "$candidate/bin/switch-to-configuration" test
check_profile_invariant
test "$(readlink -f /run/current-system)" = "$candidate"

printf '%s\n' 'START: verifying candidate greetd is active and references the real greeter.'
systemctl is-active --quiet greetd
test "$(readlink -f /etc/systemd/system/greetd.service)" = "$candidate_unit"
systemctl show greetd -p ExecStart --value | grep -Fq "$candidate_greetd_config"
grep -Fq 'caelestia-real-greeter' "$candidate_greetd_config"

printf '%s\n' 'READINESS: waiting for the candidate ready-v1 marker (30 seconds).'
candidate_ready=false
for _ in $(seq 1 120); do
    for marker in /run/user/*/caelestia-real-greeter/control/ready; do
        if [[ -f "$marker" ]] \
            && grep -Fqx ready-v1 "$marker" \
            && (( $(stat -c %Y "$marker") >= audition_started_epoch )); then
            candidate_ready=true
            candidate_ready_marker=$marker
            break 2
        fi
    done
    sleep 0.25
done

test "$candidate_ready" = true
printf 'READINESS: PASS — %s\n' "$candidate_ready_marker"

check_profile_invariant
test "$(readlink -f /run/current-system)" = "$candidate"
systemctl is-active --quiet greetd
printf '%s\n' 'AUDITION READY: candidate is active; accepted boot profile is unchanged.'
audition_succeeded=true
