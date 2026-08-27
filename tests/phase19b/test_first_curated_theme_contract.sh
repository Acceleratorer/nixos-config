#!/usr/bin/env bash

set -euo pipefail

repo_root=${1:?missing repository source root}
approved_source=${2:?missing approved source asset}
package_output=${3:?missing current theme-pack package output}
expected_registry_json=${4:?missing expected current registry JSON}
phase19a_source_root=${5:?missing Phase 19A source projection}
phase19a_package_output=${6:?missing Phase 19A package output}
phase19a_registry_json=${7:?missing Phase 19A registry JSON}
expected_palette_json=${8:?missing expected neutral palette JSON}
phase19a_validator_evidence=${9:?missing Phase 19A validator evidence}

registry_nix="$repo_root/desktop/themes/registry.nix"
pack_nix="$repo_root/desktop/themes/cryoforge-denia/pack.nix"
package_nix="$repo_root/packages/cryoforge-theme-packs.nix"
source_md="$repo_root/desktop/themes/cryoforge-denia/SOURCE.md"
repo_wallpaper="$repo_root/desktop/themes/cryoforge-denia/wallpaper.jpg"
repo_preview="$repo_root/desktop/themes/cryoforge-denia/preview.jpg"
flake_nix="$repo_root/flake.nix"
flake_lock="$repo_root/flake.lock"
phase19a_test="$repo_root/tests/phase19a/test_theme_pack_foundation_contract.sh"
installed_root="$package_output/share/cryoforge/theme-packs"
installed_registry="$installed_root/registry.json"
installed_assets="$installed_root/assets/cryoforge-denia"
installed_wallpaper="$installed_assets/wallpaper.jpg"
installed_preview="$installed_assets/preview.jpg"
installed_source="$installed_assets/SOURCE.md"
phase19a_registry="$phase19a_package_output/share/cryoforge/theme-packs/registry.json"

original_sha256=34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb
preview_sha256=f67c58a530a4e44c491937e13e33b36aedf9e6ac8b0fca8a25ba6c6696824045

for file in \
  "$approved_source" \
  "$registry_nix" \
  "$pack_nix" \
  "$package_nix" \
  "$source_md" \
  "$repo_wallpaper" \
  "$repo_preview" \
  "$flake_nix" \
  "$flake_lock" \
  "$phase19a_test" \
  "$installed_registry" \
  "$installed_wallpaper" \
  "$installed_preview" \
  "$installed_source" \
  "$expected_registry_json" \
  "$phase19a_registry" \
  "$phase19a_registry_json" \
  "$expected_palette_json" \
  "$phase19a_validator_evidence"; do
  test -r "$file"
done

allowed_paths=(
  "desktop/themes/cryoforge-denia/SOURCE.md"
  "desktop/themes/cryoforge-denia/pack.nix"
  "desktop/themes/cryoforge-denia/preview.jpg"
  "desktop/themes/cryoforge-denia/wallpaper.jpg"
  "desktop/themes/registry.nix"
  "flake.nix"
  "packages/cryoforge-theme-packs.nix"
  "tests/phase19b/test_first_curated_theme_contract.sh"
)

if command -v git >/dev/null \
  && git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
  actual_paths=$(
    {
      git -C "$repo_root" diff --name-only origin/main --
      git -C "$repo_root" ls-files --others --exclude-standard
    } | sort -u
  )
  expected_paths=$(printf '%s\n' "${allowed_paths[@]}" | sort -u)
  test "$actual_paths" = "$expected_paths"
  test -z "$(git -C "$repo_root" diff --cached --name-status)"
  git -C "$repo_root" diff --check
  git -C "$repo_root" diff --cached --check
fi

sha256() {
  local value
  value=$(sha256sum "$1")
  printf '%s\n' "${value%% *}"
}

tree_sha256_without() {
  local root=$1
  shift

  (
    cd "$root"
    find . -type f "$@" -print0 \
      | sort -z \
      | xargs -0 sha256sum \
      | sha256sum \
      | cut -d ' ' -f 1
  )
}

validate_jpeg() {
  python3 - "$@" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected_width = int(sys.argv[2])
expected_height = int(sys.argv[3])
expected_sampling = sys.argv[4]
expect_stripped = sys.argv[5] == "stripped"
data = path.read_bytes()

assert data[:11] == bytes.fromhex("ffd8ffe000104a46494600")

sof_markers = {
    0xC0,
    0xC1,
    0xC2,
    0xC3,
    0xC5,
    0xC6,
    0xC7,
    0xC9,
    0xCA,
    0xCB,
    0xCD,
    0xCE,
    0xCF,
}
metadata_markers = {0xE1, 0xE2, 0xED, 0xFE}
seen_markers = []
width = height = None
sampling = None
offset = 2

while offset < len(data):
    assert data[offset] == 0xFF
    while offset < len(data) and data[offset] == 0xFF:
        offset += 1
    marker = data[offset]
    offset += 1
    seen_markers.append(marker)

    if marker in {0x01, 0xD8, 0xD9} or 0xD0 <= marker <= 0xD7:
        if marker == 0xD9:
            break
        continue

    length = int.from_bytes(data[offset : offset + 2], "big")
    assert length >= 2
    segment = data[offset + 2 : offset + length]

    if marker in sof_markers:
        assert len(segment) >= 6
        height = int.from_bytes(segment[1:3], "big")
        width = int.from_bytes(segment[3:5], "big")
        component_count = segment[5]
        assert len(segment) == 6 + component_count * 3
        sampling = ",".join(
            f"{segment[7 + index * 3] >> 4}x"
            f"{segment[7 + index * 3] & 0x0f}"
            for index in range(component_count)
        )

    offset += length
    if marker == 0xDA:
        break

assert (width, height) == (expected_width, expected_height)
if expected_sampling != "-":
    assert sampling == expected_sampling
if expect_stripped:
    assert not metadata_markers.intersection(seen_markers)
PY
}

# Only the eight approved Phase 19B paths may differ from the accepted
# Phase 19A baseline. Historical contracts, runtime sources, and the lock
# remain byte-identical.
test "$(tree_sha256_without "$repo_root/desktop" ! -path './themes/*')" = \
  ceef33f0d985940ca78cfb3376b5ea4d61e01b44c4c7e5006d7bbd9fd402a193
test "$(tree_sha256_without "$repo_root/packages" ! -path './cryoforge-theme-packs.nix')" = \
  e5cb9f6f5275ec77a6a05a3653b38beaebe061c967f0eaf69c24d3c69193d86b
test "$(
  tree_sha256_without "$repo_root/tests" \
    ! -path './phase19a/*' \
    ! -path './phase19b/*'
)" = eb4a2deb7dc6a0a264257f16e9158aee216206c3af5aeb116fbb9f3757e21ac9
test "$(sha256 "$phase19a_test")" = \
  483b0e3bbd2aedef4622f05009b55ceb8aae74a862672d81e1231f334fc75e0f
test "$(sha256 "$flake_lock")" = \
  bbca26850cfa467fc5afc177802ae1f3bbca20827f8577e5af9285711f30ade3
test "$(sha256 "$repo_root/desktop/profiles.nix")" = \
  9de59b0dca05eb17df9b8452472b353f12ec8cdc48de1bcd93c1f1c86d1c433e
test "$(sha256 "$repo_root/packages/caelestia-cryoforge.nix")" = \
  fa1e2df3757d80d5a4093c03201141a302a46cd064cf7a1f69df0dc8c317ab56

# Removing the one Phase 19B import must reconstruct the accepted registry
# source byte-for-byte, proving the neutral definition itself did not move or
# change.
registry_without_denia=$(mktemp)
trap 'rm -f "$registry_without_denia"' EXIT
sed '\|^      (import ./cryoforge-denia/pack.nix)$|d' \
  "$registry_nix" > "$registry_without_denia"
test "$(sha256 "$registry_without_denia")" = \
  5cae58665564915b987b2582d6173c616c661b548df81d291af9aebcaf7b92cf
test "$(grep -Fxc '      (import ./cryoforge-denia/pack.nix)' "$registry_nix")" -eq 1
! grep -E -q '"#[0-9a-fA-F]{6}"' "$registry_nix"
! grep -E -i -q 'chisa|img[1-9]' "$registry_nix"

# The approved source, repository wallpaper, and packaged wallpaper are exact
# byte copies with the approved JPEG/JFIF identity.
for file in "$approved_source" "$repo_wallpaper" "$installed_wallpaper"; do
  test -f "$file"
  test ! -L "$file"
  test -r "$file"
  test "$(stat -c '%s' "$file")" = 7625165
  test "$(sha256 "$file")" = "$original_sha256"
  test "$(od -An -tx1 -N11 "$file" | tr -d ' \n')" = \
    ffd8ffe000104a46494600
  validate_jpeg "$file" 9000 4301 - allow-metadata
done
cmp -s "$approved_source" "$repo_wallpaper"
cmp -s "$repo_wallpaper" "$installed_wallpaper"

for file in "$repo_preview" "$installed_preview"; do
  test -f "$file"
  test ! -L "$file"
  test "$(sha256 "$file")" = "$preview_sha256"
  test "$(od -An -tx1 -N11 "$file" | tr -d ' \n')" = \
    ffd8ffe000104a46494600
  validate_jpeg "$file" 1600 765 2x2,1x1,1x1 stripped
done
cmp -s "$repo_preview" "$installed_preview"
cmp -s "$source_md" "$installed_source"

# Static provenance is complete and makes no redistribution claim.
grep -Fqx -- '- Pack ID: `cryoforge-denia`' "$source_md"
grep -Fqx -- '- Display name: `CryoForge Denia`' "$source_md"
grep -Fqx -- '- Artwork ID: `145492517`' "$source_md"
grep -Fqx -- '- Title: `До свидания`' "$source_md"
grep -Fqx -- '- Artist metadata: `1O`' "$source_md"
grep -Fqx -- \
  '- Source page: `https://www.pixiv.net/artworks/145492517`' \
  "$source_md"
grep -Fqx -- '- Original dimensions: `9000x4301`' "$source_md"
grep -Fqx -- '- Original byte size: `7625165`' "$source_md"
grep -Fqx -- \
  "- Approved original SHA-256: \`$original_sha256\`" \
  "$source_md"
grep -Fqx -- \
  '- Repository wallpaper path: `desktop/themes/cryoforge-denia/wallpaper.jpg`' \
  "$source_md"
grep -Fqx -- \
  '- Generated preview path: `desktop/themes/cryoforge-denia/preview.jpg`' \
  "$source_md"
grep -Fqx -- \
  "- Generated preview SHA-256: \`$preview_sha256\`" \
  "$source_md"
grep -Fqx 'Copyright remains with the original artist.' "$source_md"
grep -Fqx \
  'The repository does not claim or grant a redistribution license.' \
  "$source_md"
test "$(grep -E -o 'https?://' "$source_md" | wc -l)" -eq 1
! grep -E -i -q \
  'curl|wget|fetchurl|fetchFrom|builtins\.fetch|download command|runtime download|SPDX|Creative Commons|licensed under|redistribution is (allowed|permitted)' \
  "$source_md"

# The pack source contains each fixed semantic key once, the exact shell role
# map, and no generated or runtime palette route.
for entry in \
  'id = "cryoforge-denia";' \
  'displayName = "CryoForge Denia";' \
  'kind = "curated";' \
  'wallpaper = "assets/cryoforge-denia/wallpaper.jpg";' \
  'thumbnail = "assets/cryoforge-denia/preview.jpg";' \
  'description = "Dark abstract Denia composition by 1O with manually curated cyan and magenta accents.";'; do
  test "$(grep -Fxc "  $entry" "$pack_nix")" -eq 1 \
    || test "$(grep -Fxc "    $entry" "$pack_nix")" -eq 1
done

for key in \
  background \
  surface \
  surfaceElevated \
  foreground \
  muted \
  accent \
  accentForeground \
  border \
  focus \
  success \
  warning \
  error; do
  test "$(grep -Ec "^    $key = \"#[0-9a-f]{6}\";$" "$pack_nix")" -eq 1
done

for mapping in \
  'panel = "surface";' \
  'card = "surfaceElevated";' \
  'text = "foreground";' \
  'subduedText = "muted";' \
  'accent = "accent";' \
  'outline = "border";' \
  'focus = "focus";'; do
  test "$(grep -Fxc "    $mapping" "$pack_nix")" -eq 1
done

! grep -E -i -q \
  'matugen|pywal|wallust|extract|generated palette|runtime palette|curl|wget|fetchurl|fetchFrom|builtins\.fetch|https?://' \
  "$pack_nix" "$registry_nix" "$package_nix"

# The current package is deterministic, read-only, build-only, and complete.
grep -Fq 'version ? "1.1.0",' "$package_nix"
grep -Fq 'includeCuratedAssets ? true,' "$package_nix"
grep -Fq 'builtins.toJSON registry + "\n"' "$package_nix"
grep -Fq "$original_sha256" "$package_nix"
grep -Fq "$preview_sha256" "$package_nix"
grep -Fq '"$out/share/cryoforge/theme-packs/registry.json"' "$package_nix"
grep -Fq \
  '"$out/share/cryoforge/theme-packs/assets/cryoforge-denia/wallpaper.jpg"' \
  "$package_nix"
grep -Fq \
  '"$out/share/cryoforge/theme-packs/assets/cryoforge-denia/preview.jpg"' \
  "$package_nix"
grep -Fq \
  '"$out/share/cryoforge/theme-packs/assets/cryoforge-denia/SOURCE.md"' \
  "$package_nix"
! grep -E -i -q \
  'runtimeInputs|buildInputs|propagatedBuildInputs|fetchurl|fetchFrom|builtins\.fetch|curl|wget|https?://' \
  "$package_nix"

test "$package_output" = "$(readlink -f "$package_output")"
case "$package_output" in
  /nix/store/*-cryoforge-theme-packs-1.1.0) ;;
  *) exit 1 ;;
esac
test -z "$(find "$package_output" -type l -print)"
test "$(
  find "$package_output" -type f -printf '%P\n' | sort
)" = "$(
  printf '%s\n' \
    share/cryoforge/theme-packs/assets/cryoforge-denia/SOURCE.md \
    share/cryoforge/theme-packs/assets/cryoforge-denia/preview.jpg \
    share/cryoforge/theme-packs/assets/cryoforge-denia/wallpaper.jpg \
    share/cryoforge/theme-packs/registry.json \
    | sort
)"
test -z "$(find "$package_output" -type f ! -perm 0444 -print)"
test "$(sha256 "$installed_registry")" = "$(sha256 "$expected_registry_json")"

# The historical projection remains version 1.0.0, neutral-only, and one-file.
test "$phase19a_package_output" = "$(readlink -f "$phase19a_package_output")"
case "$phase19a_package_output" in
  /nix/store/*-cryoforge-theme-packs-1.0.0) ;;
  *) exit 1 ;;
esac
test -z "$(find "$phase19a_package_output" -type l -print)"
test "$(find "$phase19a_package_output" -type f -printf '%P\n')" = \
  "share/cryoforge/theme-packs/registry.json"
test "$(stat -c '%a' "$phase19a_registry")" = 444
test "$(sha256 "$phase19a_registry")" = "$(sha256 "$phase19a_registry_json")"

python3 - \
  "$installed_registry" \
  "$phase19a_registry" \
  "$expected_palette_json" <<'PY'
import json
import re
import sys
from pathlib import Path

current_path = Path(sys.argv[1])
historical_path = Path(sys.argv[2])
palette_path = Path(sys.argv[3])


def no_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        assert key not in result, f"duplicate JSON key: {key}"
        result[key] = value
    return result


def read_single_line_json(path):
    raw = path.read_bytes()
    assert raw.endswith(b"\n")
    assert not raw.endswith(b"\n\n")
    assert b"\n" not in raw[:-1]
    return json.loads(raw, object_pairs_hook=no_duplicate_keys)


def channel(value):
    value /= 255
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def luminance(value):
    red, green, blue = (
        int(value[index : index + 2], 16) for index in (1, 3, 5)
    )
    return (
        0.2126 * channel(red)
        + 0.7152 * channel(green)
        + 0.0722 * channel(blue)
    )


def contrast(first, second):
    high, low = sorted(
        (luminance(first), luminance(second)),
        reverse=True,
    )
    return (high + 0.05) / (low + 0.05)


current = read_single_line_json(current_path)
historical = read_single_line_json(historical_path)
neutral_palette = json.loads(
    palette_path.read_text(encoding="utf-8"),
    object_pairs_hook=no_duplicate_keys,
)

semantic_keys = {
    "background",
    "surface",
    "surfaceElevated",
    "foreground",
    "muted",
    "accent",
    "accentForeground",
    "border",
    "focus",
    "success",
    "warning",
    "error",
}
shell = {
    "panel": "surface",
    "card": "surfaceElevated",
    "text": "foreground",
    "subduedText": "muted",
    "accent": "accent",
    "outline": "border",
    "focus": "focus",
}
denia_palette = {
    "background": "#0d1018",
    "surface": "#171925",
    "surfaceElevated": "#242033",
    "foreground": "#f4f1f7",
    "muted": "#b7afc0",
    "accent": "#e45c9e",
    "accentForeground": "#140c15",
    "border": "#806888",
    "focus": "#7fe5e8",
    "success": "#83d7b0",
    "warning": "#f2c77a",
    "error": "#ff6b7a",
}

assert set(current) == {"schemaVersion", "defaultPackId", "packs"}
assert current["schemaVersion"] == 1
assert current["defaultPackId"] == "neutral"
assert len(current["packs"]) == 2

assert set(historical) == {"schemaVersion", "defaultPackId", "packs"}
assert historical["schemaVersion"] == 1
assert historical["defaultPackId"] == "neutral"
assert len(historical["packs"]) == 1

neutral = current["packs"][0]
assert neutral == historical["packs"][0]
assert neutral["id"] == "neutral"
assert neutral["displayName"] == "CryoForge Neutral"
assert neutral["kind"] == "neutral"
assert neutral["wallpaper"] is None
assert neutral["palette"] == neutral_palette
assert set(neutral["palette"]) == semantic_keys
assert neutral["shell"] == shell
assert neutral["preview"] == {
    "thumbnail": None,
    "description": (
        "Wallpaper-independent fallback using the active CryoForge neutral "
        "palette."
    ),
    "swatches": [
        "background",
        "surfaceElevated",
        "accent",
        "foreground",
        "focus",
    ],
}

denia = current["packs"][1]
assert denia == {
    "id": "cryoforge-denia",
    "displayName": "CryoForge Denia",
    "kind": "curated",
    "wallpaper": "assets/cryoforge-denia/wallpaper.jpg",
    "palette": denia_palette,
    "shell": shell,
    "preview": {
        "thumbnail": "assets/cryoforge-denia/preview.jpg",
        "description": (
            "Dark abstract Denia composition by 1O with manually curated "
            "cyan and magenta accents."
        ),
        "swatches": [
            "background",
            "surfaceElevated",
            "accent",
            "focus",
            "foreground",
        ],
    },
}
assert set(denia["palette"]) == semantic_keys
assert len(denia["palette"]) == 12
assert all(
    re.fullmatch(r"#[0-9a-f]{6}", value)
    for value in denia["palette"].values()
)
assert [pack["id"] for pack in current["packs"]] == [
    "neutral",
    "cryoforge-denia",
]
assert [pack["kind"] for pack in current["packs"]].count("curated") == 1

for foreground in (
    "foreground",
    "muted",
    "accent",
    "focus",
    "success",
    "warning",
    "error",
):
    for background in ("background", "surface", "surfaceElevated"):
        ratio = contrast(denia_palette[foreground], denia_palette[background])
        print(f"contrast {foreground}/{background}={ratio:.6f}")
        assert ratio >= 4.5

ratio = contrast(denia_palette["accentForeground"], denia_palette["accent"])
print(f"contrast accentForeground/accent={ratio:.6f}")
assert ratio >= 4.5

ratio = contrast(denia_palette["border"], denia_palette["surfaceElevated"])
print(f"contrast border/surfaceElevated={ratio:.6f}")
assert ratio >= 3.0

for registry in (current, historical):
    raw = json.dumps(registry, separators=(",", ":")).encode()
    for forbidden in (
        b"/home/",
        b"/var/",
        b"/tmp/",
        b"http://",
        b"https://",
        b"selectedTheme",
        b"persistent",
        b"automatic",
        b"random",
        b"matugen",
        b"pywal",
        b"wallust",
    ):
        assert forbidden not in raw
PY

# The flake exports the full current package, keeps meaningful Phase 19A
# projection wiring, and registers this focused check.
grep -Fq 'cryoforge-theme-packs = cryoforgeThemePacks;' "$flake_nix"
grep -Fq 'phase19a-theme-pack-foundation-contract =' "$flake_nix"
grep -Fq 'phase19b-first-curated-theme-contract =' "$flake_nix"
grep -Fq 'version = "1.0.0";' "$flake_nix"
grep -Fq 'includeCuratedAssets = false;' "$flake_nix"
test "$(grep -o 'cryoforgeThemePacks' "$flake_nix" | wc -l)" -eq 3

# No live configuration or historical runtime package consumes the build-only
# theme package or curated pack.
! grep -R -E -i -q \
  'cryoforge-theme-packs|cryoforgeThemePacks|cryoforge-denia' \
  "$repo_root/configuration.nix" \
  "$repo_root/home.nix" \
  "$repo_root/desktop-hyprland.nix" \
  "$repo_root/desktop/profiles.nix" \
  "$repo_root/desktop/caelestia" \
  "$repo_root/desktop/hypr" \
  "$repo_root/desktop/regreet" \
  "$repo_root/packages/caelestia-chisa-pool.nix" \
  "$repo_root/packages/caelestia-chisa-pool-previews.nix" \
  "$repo_root/packages/caelestia-cryoforge.nix" \
  "$repo_root/packages/caelestia-real-greeter.nix" \
  "$repo_root/packages/caelestia-real-lock.nix"

! grep -E -i -q \
  'selector|apply[[:space:]_-]*action|selected[[:space:]_-]*theme|persist|automatic[[:space:]_-]*switch|random[[:space:]_-]*rotation|dynamic[[:space:]_-]*(colou?r|theme|extract)|service|timer|watcher|daemon|Process[[:space:]]*\{|IpcHandler[[:space:]]*\{|FileView[[:space:]]*\{|curl|wget|fetchurl|fetchFrom|builtins\.fetch' \
  "$registry_nix" "$pack_nix" "$package_nix"

# Run the untouched historical contract against the real source/package
# projection as part of Phase 19B itself.
bash \
  "$phase19a_source_root/tests/phase19a/test_theme_pack_foundation_contract.sh" \
  "$phase19a_source_root" \
  "$phase19a_package_output" \
  "$phase19a_registry_json" \
  "$expected_palette_json" \
  "$phase19a_validator_evidence"

printf '%s\n' 'phase19b first curated theme contract tests: pass'
