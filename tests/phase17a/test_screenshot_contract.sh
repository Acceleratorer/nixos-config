#!/usr/bin/env bash

set -euo pipefail

area_picker=${1:?missing packaged area picker}
region_script=${2:?missing region screenshot script}
keybinds=${3:?missing CryoForge keybinds}
caelestia_cli=${4:?missing programmatic Caelestia CLI}

test -r "$area_picker"
test -r "$region_script"
test -r "$keybinds"
test -d "$caelestia_cli"

# Verify ownership structurally using brace depth. The screenshot helper must
# be a direct member of the outer LazyLoader identified as root, never a
# member of Variants, its delegate, or another nested object.
scope_count=0
root_loader_count=0
root_id_count=0
variants_count=0
open_region_count=0
direct_open_region_count=0
nested_open_region_count=0
root_body_depth=-1
depth=0

while IFS= read -r line || [[ -n "$line" ]]; do
    line_depth=$depth

    if [[ "$line" =~ ^[[:space:]]*Scope[[:space:]]*[\{][[:space:]]*$ ]] \
        && [[ "$line_depth" -eq 0 ]]; then
        scope_count=$((scope_count + 1))
    fi

    if [[ "$line" =~ ^[[:space:]]*LazyLoader[[:space:]]*[\{][[:space:]]*$ ]] \
        && [[ "$line_depth" -eq 1 ]]; then
        root_loader_count=$((root_loader_count + 1))
        root_body_depth=$((line_depth + 1))
    fi

    if [[ "$line" =~ ^[[:space:]]*id:[[:space:]]*root[[:space:]]*$ ]] \
        && [[ "$line_depth" -eq "$root_body_depth" ]]; then
        root_id_count=$((root_id_count + 1))
    fi

    if [[ "$line" =~ ^[[:space:]]*Variants[[:space:]]*[\{][[:space:]]*$ ]] \
        && [[ "$line_depth" -eq "$root_body_depth" ]]; then
        variants_count=$((variants_count + 1))
    fi

    if [[ "$line" =~ ^[[:space:]]*function[[:space:]]+openRegion[\(][\)][[:space:]]*:[[:space:]]*void[[:space:]]*[\{][[:space:]]*$ ]]; then
        open_region_count=$((open_region_count + 1))
        if [[ "$line_depth" -eq "$root_body_depth" ]]; then
            direct_open_region_count=$((direct_open_region_count + 1))
        else
            nested_open_region_count=$((nested_open_region_count + 1))
        fi
    fi

    for ((index = 0; index < ${#line}; index++)); do
        case "${line:index:1}" in
        "{")
            depth=$((depth + 1))
            ;;
        "}")
            depth=$((depth - 1))
            ;;
        esac
        test "$depth" -ge 0
    done
done < "$area_picker"

test "$depth" -eq 0
test "$scope_count" -eq 1
test "$root_loader_count" -eq 1
test "$root_id_count" -eq 1
test "$variants_count" -eq 1
test "$open_region_count" -eq 1
test "$direct_open_region_count" -eq 1
test "$nested_open_region_count" -eq 0

# Reject the exact zero-context regression shape as a supplemental assertion:
# no helper function may appear between the Variants opening and its model.
variants_prefix=$(sed -n '/^        Variants {$/,/^            model: Screens.screens$/p' "$area_picker")
! printf '%s\n' "$variants_prefix" | grep -Fq 'function openRegion'

test "$(grep -Fxc 'create_bind(vars.kbScreenshot, hl.dsp.global("caelestia:screenshot"), locked)' "$keybinds")" -eq 1
test "$(grep -Fxc 'create_bind(vars.kbScreenshotRegion, hl.dsp.global("caelestia:screenshot"))' "$keybinds")" -eq 1
! grep -Fq 'create_bind(vars.kbScreenshot, hl.dsp.exec_cmd("caelestia screenshot"), locked)' "$keybinds"

region_helper=$(grep -oE \
    '/nix/store/[^"[:space:]]+-caelestia-screenshot-region/bin/caelestia-screenshot-region' \
    "$area_picker")
test "$(printf '%s\n' "$region_helper" | grep -c .)" -eq 1
test -x "$region_helper"

open_region_block=$(sed -n '/^        function openRegion(): void {$/,/^        }$/p' "$area_picker")
test "$(printf '%s\n' "$open_region_block" | wc -l)" -eq 3
printf '%s\n' "$open_region_block" \
    | grep -Fqx "            Quickshell.execDetached([\"$region_helper\"]);"

open_block=$(sed -n '/function open(): void {/,/^        }/p' "$area_picker")
test "$open_block" = $'        function open(): void {\n            root.openRegion();\n        }'

freeze_block=$(sed -n '/function openFreeze(): void {/,/^        }/p' "$area_picker")
printf '%s\n' "$freeze_block" | grep -Fq 'root.freeze = true;'
printf '%s\n' "$freeze_block" | grep -Fq 'root.activeAsync = true;'

screenshot_block=$(sed -n '/name: "screenshot"/,/^    }/p' "$area_picker")
printf '%s\n' "$screenshot_block" | grep -Fq 'root.openRegion();'
test "$(grep -Fxc '            root.openRegion();' "$area_picker")" -eq 2

cli_screenshot=$(find "$caelestia_cli/lib" \
    -path '*/site-packages/caelestia/subcommands/screenshot.py' \
    -type f \
    -print \
    -quit)
test -n "$cli_screenshot"
grep -Fq '            self.fullscreen()' "$cli_screenshot"
grep -Fq '        cmd = ["grim"]' "$cli_screenshot"
grep -Fq '            cmd += ["-o", focused_monitor["name"]]' "$cli_screenshot"

freeze_shortcut_block=$(sed -n '/name: "screenshotFreeze"/,/^    }/p' "$area_picker")
printf '%s\n' "$freeze_shortcut_block" | grep -Fq 'root.freeze = true;'
printf '%s\n' "$freeze_shortcut_block" | grep -Fq 'root.activeAsync = true;'

! grep -E -q '(echo|printf|logger|systemd-cat|tee).*(\$geometry|\$\{geometry\})|(\$geometry|\$\{geometry\}).*(echo|printf|logger|systemd-cat|tee)' \
    "$region_script"
! grep -E -q '(echo|printf|logger|systemd-cat|tee).*clipboard' "$region_script"

test_root=$(mktemp -d -t phase17a-screenshot-contract.XXXXXXXX)
trap 'rm -rf "$test_root"' EXIT
base_path=$PATH

make_mock_commands() {
    local mock_bin=$1

    mkdir -p "$mock_bin"

    cat > "$mock_bin/slurp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
touch "$PHASE17A_STATE/selector-ran"
case "$PHASE17A_SELECTOR_RESULT" in
success) printf '%s\n' '120,80 640x360' ;;
cancel) exit 1 ;;
empty) printf '\n' ;;
invalid) printf '%s\n' 'not-a-geometry' ;;
*) exit 64 ;;
esac
EOF

    cat > "$mock_bin/grim" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
test "$1" = -l
test "$2" = 0
test "$3" = -g
test "$4" = '120,80 640x360'
test "$#" -eq 5
printf '%s' "$4" > "$PHASE17A_STATE/capture-geometry"
printf 'mock-png' > "$5"
touch "$PHASE17A_STATE/capture-ran"
EOF

    cat > "$mock_bin/wl-copy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
test "$(cat)" = mock-png
touch "$PHASE17A_STATE/clipboard-ran"
EOF

    cat > "$mock_bin/notify-send" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
*"Screenshot taken"*"copied to clipboard"*)
    touch "$PHASE17A_STATE/screenshot-notification-ran"
    printf '%s\n' "$PHASE17A_NOTIFICATION_ACTION"
    ;;
*"Screenshot saved"*)
    touch "$PHASE17A_STATE/save-notification-ran"
    ;;
*)
    exit 64
    ;;
esac
EOF

    cat > "$mock_bin/swappy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
test "$1" = -f
test -f "$2"
touch "$PHASE17A_STATE/swappy-ran"
EOF

    sed -i "1c#!$BASH" "$mock_bin"/*
    chmod 0700 "$mock_bin"/*
}

assert_no_capture_side_effects() {
    local state=$1

    test ! -e "$state/capture-ran"
    test ! -e "$state/capture-geometry"
    test ! -e "$state/clipboard-ran"
    test ! -e "$state/screenshot-notification-ran"
    test ! -e "$state/save-notification-ran"
    test ! -e "$state/swappy-ran"
    test ! -e "$state/home/.cache/caelestia/screenshots"
}

wait_for_file() {
    local file=$1

    for _ in $(seq 1 100); do
        if [[ -e "$file" ]]; then
            return 0
        fi
        sleep 0.01
    done

    return 1
}

run_case() {
    local selector_result=$1
    local notification_action=$2
    local state="$test_root/$selector_result-$notification_action"
    local mock_bin="$state/bin"
    local status=0

    mkdir -p "$state"
    make_mock_commands "$mock_bin"

    env \
        HOME="$state/home" \
        XDG_CACHE_HOME="$state/home/.cache" \
        XDG_PICTURES_DIR="$state/home/Pictures" \
        PATH="$mock_bin:$base_path" \
        PHASE17A_STATE="$state" \
        PHASE17A_SELECTOR_RESULT="$selector_result" \
        PHASE17A_NOTIFICATION_ACTION="$notification_action" \
        "$BASH" "$region_script" > "$state/stdout" 2> "$state/stderr" || status=$?

    printf '%s\n' "$status"
}

test "$(run_case success open)" -eq 0
test -f "$test_root/success-open/selector-ran"
test -f "$test_root/success-open/capture-ran"
test "$(cat "$test_root/success-open/capture-geometry")" = '120,80 640x360'
test -f "$test_root/success-open/clipboard-ran"
test -f "$test_root/success-open/screenshot-notification-ran"
wait_for_file "$test_root/success-open/swappy-ran"
test ! -e "$test_root/success-open/save-notification-ran"

test "$(run_case success save)" -eq 0
test -f "$test_root/success-save/clipboard-ran"
test -f "$test_root/success-save/screenshot-notification-ran"
test -f "$test_root/success-save/save-notification-ran"
test ! -e "$test_root/success-save/swappy-ran"
test "$(find "$test_root/success-save/home/Pictures/Screenshots" -type f | wc -l)" -eq 1

for selector_result in cancel empty invalid; do
    status=$(run_case "$selector_result" none)
    if [[ "$selector_result" == invalid ]]; then
        test "$status" -ne 0
    else
        test "$status" -eq 0
    fi
    assert_no_capture_side_effects "$test_root/$selector_result-none"
done

missing_selector_state="$test_root/missing-selector"
mkdir -p "$missing_selector_state/bin"
status=0
env \
    HOME="$missing_selector_state/home" \
    PATH="$missing_selector_state/bin" \
    "$BASH" "$region_script" > "$missing_selector_state/stdout" 2> "$missing_selector_state/stderr" || status=$?
test "$status" -ne 0
grep -Fq 'slurp is not installed' "$missing_selector_state/stderr"
assert_no_capture_side_effects "$missing_selector_state"

printf '%s\n' 'phase17a screenshot contract tests: pass'
