#!/usr/bin/env bash

set -Eeuo pipefail

show_error() {
    local message=${1//$'\n'/ }

    rofi -e "Quick Settings: ${message}" >/dev/null 2>&1 || true
}

fail() {
    show_error "$1"
    exit 1
}

if ! audio_output=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>&1); then
    fail "Could not query audio: ${audio_output}"
fi

if [[ $audio_output =~ ^Volume:[[:space:]]+([0-9]+([.][0-9]+)?)([[:space:]]+\[MUTED\])?$ ]]; then
    audio_volume=${BASH_REMATCH[1]}
    audio_muted=${BASH_REMATCH[3]:-}
else
    fail "Could not parse audio state."
fi

if [[ -n $audio_muted ]]; then
    audio_row="<span foreground='#dcebff'>󰖁  Audio: Muted</span>"
else
    audio_percent=$(awk -v volume="$audio_volume" 'BEGIN { printf "%.0f", volume * 100 }')
    audio_row="<span foreground='#00e5ff'>  Audio: ${audio_percent}%</span>"
fi

if ! wifi_state=$(nmcli -g WIFI general 2>&1); then
    fail "Could not query Wi-Fi: ${wifi_state}"
fi

case "$wifi_state" in
    enabled)
        wifi_row="<span foreground='#00e5ff'>  Wi-Fi: On</span>"
        ;;
    disabled)
        wifi_row="<span foreground='#dcebff'>󰖪  Wi-Fi: Off</span>"
        ;;
    *)
        fail "Could not parse Wi-Fi state."
        ;;
esac

if ! bluetooth_output=$(bluetoothctl show 2>&1); then
    fail "Could not query Bluetooth: ${bluetooth_output}"
fi

mapfile -t bluetooth_powered < <(
    printf '%s\n' "$bluetooth_output" |
        sed -n 's/^[[:space:]]*Powered: \(yes\|no\)[[:space:]]*$/\1/p'
)

if (( ${#bluetooth_powered[@]} != 1 )); then
    fail "Could not parse Bluetooth state."
fi

case "${bluetooth_powered[0]}" in
    yes)
        bluetooth_row="<span foreground='#00e5ff'>  Bluetooth: On</span>"
        ;;
    no)
        bluetooth_row="<span foreground='#dcebff'>󰂲  Bluetooth: Off</span>"
        ;;
    *)
        fail "Could not parse Bluetooth state."
        ;;
esac

if ! mako_modes=$(makoctl mode 2>&1); then
    fail "Could not query Do Not Disturb: ${mako_modes}"
fi

if [[ -z $mako_modes ]]; then
    fail "Could not parse Do Not Disturb state."
fi

dnd_enabled=0
while IFS= read -r mako_mode; do
    if [[ $mako_mode == do-not-disturb ]]; then
        dnd_enabled=1
    fi
done <<< "$mako_modes"

if (( dnd_enabled )); then
    dnd_row="<span foreground='#00e5ff'>󰂛  Do Not Disturb: On</span>"
else
    dnd_row="<span foreground='#dcebff'>󰂚  Do Not Disturb: Off</span>"
fi

selection_status=0
selection=$(
    printf '%s\n%s\n%s\n%s\n' \
        "$audio_row" "$wifi_row" "$bluetooth_row" "$dnd_row" |
        rofi -dmenu \
            -markup-rows \
            -format i \
            -theme "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/quick-settings.rasi" \
            -p "Quick Settings"
) || selection_status=$?

case "$selection_status" in
    0)
        ;;
    1)
        exit 0
        ;;
    *)
        fail "Could not open the panel."
        ;;
esac

case "$selection" in
    0)
        if ! action_output=$(swayosd-client --output-volume mute-toggle 2>&1); then
            fail "Could not toggle audio: ${action_output}"
        fi
        ;;
    1)
        case "$wifi_state" in
            enabled)
                if ! action_output=$(nmcli radio wifi off 2>&1); then
                    fail "Could not turn Wi-Fi off: ${action_output}"
                fi
                ;;
            disabled)
                if ! action_output=$(nmcli radio wifi on 2>&1); then
                    fail "Could not turn Wi-Fi on: ${action_output}"
                fi
                ;;
        esac
        ;;
    2)
        case "${bluetooth_powered[0]}" in
            yes)
                if ! action_output=$(bluetoothctl power off 2>&1); then
                    fail "Could not turn Bluetooth off: ${action_output}"
                fi
                ;;
            no)
                if ! action_output=$(bluetoothctl power on 2>&1); then
                    fail "Could not turn Bluetooth on: ${action_output}"
                fi
                ;;
        esac
        ;;
    3)
        if ! action_output=$(makoctl mode -t do-not-disturb 2>&1); then
            fail "Could not toggle Do Not Disturb: ${action_output}"
        fi
        ;;
    *)
        fail "Unexpected panel selection."
        ;;
esac
