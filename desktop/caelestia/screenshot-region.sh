set -euo pipefail

if ! command -v slurp >/dev/null 2>&1; then
    printf '%s\n' 'Screenshot selection is unavailable: slurp is not installed.' >&2
    exit 1
fi

if ! geometry=$(slurp); then
    exit 0
fi

if [[ -z "$geometry" ]]; then
    exit 0
fi

if [[ ! "$geometry" =~ ^-?[0-9]+,-?[0-9]+\ [1-9][0-9]*x[1-9][0-9]*$ ]]; then
    printf '%s\n' 'Invalid screenshot selection.' >&2
    exit 1
fi

cache_dir="${XDG_CACHE_HOME:-"$HOME/.cache"}/caelestia/screenshots"
destination="$cache_dir/$(date +%Y%m%d%H%M%S)"

mkdir -p "$cache_dir"
if ! grim -l 0 -g "$geometry" "$destination"; then
    rm -f "$destination"
    printf '%s\n' 'Unable to capture the selected screenshot region.' >&2
    exit 1
fi

wl-copy < "$destination"

action=$(notify-send \
    -a caelestia-cli \
    -i image-x-generic-symbolic \
    -h "STRING:image-path:$destination" \
    --action=open=Open \
    --action=save=Save \
    "Screenshot taken" \
    "Screenshot stored in $destination and copied to clipboard")

case "$action" in
open)
    swappy -f "$destination" >/dev/null 2>&1 &
    ;;
save)
    screenshots_dir="${CAELESTIA_SCREENSHOTS_DIR:-"${XDG_PICTURES_DIR:-"$HOME/Pictures"}/Screenshots"}"
    saved_destination="$screenshots_dir/$(basename "$destination").png"
    mkdir -p "$screenshots_dir"
    mv "$destination" "$saved_destination"
    notify-send "Screenshot saved" "Saved to $saved_destination"
    ;;
esac
