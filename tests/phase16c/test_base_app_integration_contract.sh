#!/usr/bin/env bash

set -euo pipefail

palette_source=${1:?missing neutral palette source}
kitty_adapter=${2:?missing Kitty adapter source}
fastfetch_adapter=${3:?missing Fastfetch adapter source}
target_seed_script=${4:?missing target user seed script}
stock_seed_script=${5:?missing stock user seed script}
profiles_nix=${6:?missing desktop profiles expression}
flake_nix=${7:?missing flake expression}
flake_lock=${8:?missing flake lock}
home_nix=${9:?missing Home Manager expression}
configuration_nix=${10:?missing NixOS configuration}
desktop_hyprland=${11:?missing Hyprland system expression}
chisa_dir=${12:?missing protected Chisa source directory}
greeter_dir=${13:?missing protected real-greeter source directory}
regreet_dir=${14:?missing protected ReGreet source directory}
hypr_dir=${15:?missing protected Hyprland source directory}
cryoforge_package=${16:?missing CryoForge package expression}
real_greeter_package=${17:?missing real-greeter package expression}
real_lock_package=${18:?missing real-lock package expression}
real_greeter_system=${19:?missing real-greeter system expression}
gallery_patch=${20:?missing Phase 16A gallery patch}
special_patch=${21:?missing accepted special-workspace patch}
region_patch=${22:?missing accepted screenshot patch}
region_script=${23:?missing accepted screenshot script}
cryoforge_vars=${24:?missing CryoForge variables}
cryoforge_general=${25:?missing CryoForge general config}
cryoforge_decoration=${26:?missing CryoForge decoration config}
cryoforge_animations=${27:?missing CryoForge animations}
cryoforge_rules=${28:?missing CryoForge rules}
cryoforge_execs=${29:?missing CryoForge execs}
cryoforge_functions=${30:?missing CryoForge functions}
cryoforge_keybinds=${31:?missing CryoForge keybinds}
cryoforge_gestures=${32:?missing CryoForge gestures}

for file in \
  "$palette_source" \
  "$kitty_adapter" \
  "$fastfetch_adapter" \
  "$target_seed_script" \
  "$stock_seed_script" \
  "$profiles_nix" \
  "$flake_nix" \
  "$flake_lock" \
  "$home_nix" \
  "$configuration_nix" \
  "$desktop_hyprland" \
  "$cryoforge_package" \
  "$real_greeter_package" \
  "$real_lock_package" \
  "$real_greeter_system" \
  "$gallery_patch" \
  "$special_patch" \
  "$region_patch" \
  "$region_script" \
  "$cryoforge_vars" \
  "$cryoforge_general" \
  "$cryoforge_decoration" \
  "$cryoforge_animations" \
  "$cryoforge_rules" \
  "$cryoforge_execs" \
  "$cryoforge_functions" \
  "$cryoforge_keybinds" \
  "$cryoforge_gestures"; do
  test -r "$file"
done

for dir in "$chisa_dir" "$greeter_dir" "$regreet_dir" "$hypr_dir"; do
  test -d "$dir"
done

kitty_config=$(grep -oE \
  '/nix/store/[^[:space:]]+-cryoforge-neutral-kitty\.conf' \
  "$target_seed_script" | head -n 1)
fastfetch_config=$(grep -oE \
  '/nix/store/[^[:space:]]+-cryoforge-neutral-fastfetch\.jsonc' \
  "$target_seed_script" | head -n 1)
test -n "$kitty_config"
test -n "$fastfetch_config"
test -r "$kitty_config"
test -r "$fastfetch_config"

sha256() {
  local value
  value=$(sha256sum "$1")
  printf '%s\n' "${value%% *}"
}

tree_sha256() {
  (
    cd "$1"
    find . -type f -print0 \
      | sort -z \
      | xargs -0 sha256sum \
      | sha256sum \
      | cut -d ' ' -f 1
  )
}

assert_sha256() {
  test "$(sha256 "$1")" = "$2"
}

assert_tree_sha256() {
  test "$(tree_sha256 "$1")" = "$2"
}

# The fixed source contains exactly the requested semantic contract.
while read -r token value; do
  test "$(grep -Fxc "  $token = \"$value\";" "$palette_source")" -eq 1
done <<'TOKENS'
background #05070d
surface #0a1020
surfaceElevated #111a2e
foreground #dcebff
muted #8193ab
accent #77b6e1
accentForeground #05070d
border #4d6fb7
focus #00e5ff
success #4dd4ac
warning #f2c66d
error #ff637f
TOKENS

test "$(grep -Ec '^  [[:alpha:]][[:alnum:]]* = "#[0-9a-f]{6}";$' "$palette_source")" -eq 12
! grep -E -q 'raised|deep-blue|ice-blue|neon-cyan|^[[:space:]]*text[[:space:]]*=' "$palette_source"

# Verify WCAG contrast for every normal-text pairing used by the adapters.
python3 - "$palette_source" <<'PY'
import re
import sys

source = open(sys.argv[1], encoding="utf-8").read().splitlines()
tokens = {}
for line in source:
    match = re.fullmatch(r'\s+([A-Za-z][A-Za-z0-9]*) = "(#[0-9a-f]{6})";', line)
    if match:
        tokens[match.group(1)] = match.group(2)

expected = {
    "background", "surface", "surfaceElevated", "foreground", "muted",
    "accent", "accentForeground", "border", "focus", "success",
    "warning", "error",
}
assert set(tokens) == expected

def channel(value):
    value /= 255
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

def luminance(value):
    value = value.removeprefix("#")
    red, green, blue = (int(value[index:index + 2], 16) for index in (0, 2, 4))
    return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)

def contrast(foreground, background):
    high, low = sorted((luminance(foreground), luminance(background)), reverse=True)
    return (high + 0.05) / (low + 0.05)

pairs = [
    ("foreground", "background"),
    ("foreground", "surface"),
    ("foreground", "surfaceElevated"),
    ("muted", "background"),
    ("muted", "surface"),
    ("muted", "surfaceElevated"),
    ("accentForeground", "accent"),
    ("focus", "background"),
    ("focus", "surface"),
    ("success", "background"),
    ("warning", "background"),
    ("error", "background"),
]
for foreground, background in pairs:
    ratio = contrast(tokens[foreground], tokens[background])
    assert ratio >= 4.5, f"{foreground}/{background} contrast is only {ratio:.2f}:1"
PY

# Both native adapters consume the shared palette instead of carrying raw
# colours or a second palette.
! grep -E -q '#[0-9a-fA-F]{6}' "$kitty_adapter" "$fastfetch_adapter"
for token in \
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
  grep -Fq "palette.$token" "$kitty_adapter"
done
for token in foreground muted accent border; do
  grep -Fq "palette.$token" "$fastfetch_adapter"
done
test "$(wc -l < "$kitty_adapter")" -le 80
test "$(wc -l < "$fastfetch_adapter")" -le 100

# Kitty is opaque and uses the neutral contract. Focus is distinguished by a
# bright border plus bold active-tab typography and a beam cursor, not colour
# alone.
grep -Fqx 'font_family CaskaydiaCove NF' "$kitty_config"
grep -Fqx 'background_opacity 1.0' "$kitty_config"
grep -Fqx 'background #05070d' "$kitty_config"
grep -Fqx 'foreground #dcebff' "$kitty_config"
grep -Fqx 'selection_background #111a2e' "$kitty_config"
grep -Fqx 'selection_foreground #dcebff' "$kitty_config"
grep -Fqx 'cursor #00e5ff' "$kitty_config"
grep -Fqx 'active_border_color #00e5ff' "$kitty_config"
grep -Fqx 'inactive_border_color #4d6fb7' "$kitty_config"
grep -Fqx 'active_tab_foreground #05070d' "$kitty_config"
grep -Fqx 'active_tab_background #77b6e1' "$kitty_config"
grep -Fqx 'active_tab_font_style bold' "$kitty_config"
grep -Fqx 'inactive_tab_font_style normal' "$kitty_config"
grep -Fqx 'cursor_shape beam' "$kitty_config"
grep -Fqx 'cursor_shape_unfocused hollow' "$kitty_config"
kitty +runpy \
  'import sys; from kitty.config import load_config; bad = []; load_config(sys.argv[1], accumulate_bad_lines=bad); assert not bad, bad' \
  "$kitty_config"

# Fastfetch stays declarative, label-driven, and uses the full built-in logo.
python3 - "$fastfetch_config" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    config = json.load(handle)

assert config["logo"] == {"type": "builtin", "source": "NixOS"}
assert config["display"]["brightColor"] is False
assert config["display"]["separator"] == "  "
assert config["display"]["key"]["width"] == 12
assert config["display"]["color"] == {
    "keys": "#8193ab",
    "title": "#77b6e1",
    "output": "#dcebff",
    "separator": "#4d6fb7",
}

expected_modules = [
    {"type": "title", "format": "CryoForge // {user-name}@{host-name}"},
    {"type": "os", "key": "OS"},
    {"type": "host", "key": "Host"},
    {"type": "kernel", "key": "Kernel"},
    {"type": "uptime", "key": "Uptime"},
    {"type": "packages", "key": "Packages"},
    {"type": "break"},
    {"type": "shell", "key": "Shell"},
    {"type": "terminal", "key": "Terminal"},
    {"type": "wm", "key": "Desktop"},
    {"type": "break"},
    {"type": "cpu", "key": "CPU"},
    {"type": "gpu", "key": "GPU"},
    {"type": "memory", "key": "Memory"},
    {"type": "disk", "key": "Storage", "folders": "/"},
]
assert config["modules"] == expected_modules
module_types = [module["type"] for module in config["modules"]]
assert module_types == [
    "title", "os", "host", "kernel", "uptime", "packages", "break",
    "shell", "terminal", "wm", "break", "cpu", "gpu", "memory", "disk",
]
assert module_types.count("break") == 2
assert module_types[6] == "break"
assert module_types[10] == "break"
prohibited_modules = {
    "battery",
    "colors",
    "command",
    "dns",
    "icons",
    "localip",
    "netio",
    "network",
    "publicip",
    "temperature",
    "wifi",
}
assert not prohibited_modules.intersection(module_types)
PY
grep -Fq 'logo = {' "$fastfetch_adapter"
grep -Fqx '    type = "builtin";' <(sed -n '/logo = {/,/^  };/p' "$fastfetch_adapter")
grep -Fqx '    source = "NixOS";' <(sed -n '/logo = {/,/^  };/p' "$fastfetch_adapter")
grep -Fqx '      format = "CryoForge // {user-name}@{host-name}";' \
  <(sed -n '/type = "title";/,/^    }/p' "$fastfetch_adapter")
! grep -E -i -q \
  'https?://|/nix/store/|\.(png|jpe?g|gif|svg|webp)(["'"'"']|$)' \
  "$fastfetch_adapter" "$fastfetch_config"
! grep -E -i -q \
  'asset|file-raw|image|converter|runtime|script|command' \
  "$fastfetch_adapter" "$fastfetch_config"
fastfetch --config "$fastfetch_config" --pipe true >/dev/null

# The logo amendment adds no cursor asset or cursor route. Existing desktop
# cursor ownership remains protected by the byte-stable Home Manager and
# Hyprland sources asserted below.
! find "$(dirname "$fastfetch_adapter")" -maxdepth 1 -type f \
  \( -iname '*cursor*' -o -iname '*phrolova*' -o -iname '*.cur' \
  -o -iname '*.ani' -o -iname '*.gif' -o -iname '*mousecape*' \
  -o -iname 'index.theme' \) -print | grep -q .
! grep -E -i -q \
  'phrolova|XCURSOR|xcursor|cursor[-_ ]*(theme|route|file)|mousecape|\.cur([[:space:]"'\'']|$)|\.ani([[:space:]"'\'']|$)' \
  "$fastfetch_adapter" "$palette_source"

# The CryoForge profile seeds only missing regular native files. Existing
# files and symlinks remain untouched and user-owned.
seed_file_block=$(sed -n '/^    seed_file() {$/,/^    }$/p' "$profiles_nix")
printf '%s\n' "$seed_file_block" | grep -Fq 'if [ ! -e "$2" ] && [ ! -L "$2" ]; then'
printf '%s\n' "$seed_file_block" | grep -Fq 'install -m 0600 "$1" "$2"'
! printf '%s\n' "$seed_file_block" | grep -E -q 'cmp|mv[[:space:]]+-f|--force'

seed_block=$(sed -n \
  '/# Phase 16C: fixed neutral app defaults/,/# End Phase 16C neutral app defaults/p' \
  "$profiles_nix")
printf '%s\n' "$seed_block" | grep -Fq 'Existing user files win.'
printf '%s\n' "$seed_block" | grep -Fq 'seed_file ${neutralKittyConfig} "$kitty_dir/kitty.conf"'
printf '%s\n' "$seed_block" | grep -Fq 'seed_file ${neutralFastfetchConfig} "$fastfetch_dir/config.jsonc"'
grep -Fq '${lib.optionalString isCryoforge' "$profiles_nix"
grep -Fq 'neutralPalette = import ./palette.nix;' "$profiles_nix"
grep -Fq '(import ./apps/kitty.nix { palette = neutralPalette; })' "$profiles_nix"
grep -Fq 'builtins.toJSON (import ./apps/fastfetch.nix { palette = neutralPalette; })' "$profiles_nix"
! grep -Fq 'pkgs.formats.json' "$profiles_nix"
grep -Fq 'default = neutralPalette;' "$profiles_nix"
! printf '%s\n' "$seed_block" | grep -E -q 'systemd|ExecStart|exec-once|home\.activation'
grep -Fq "$kitty_config" "$target_seed_script"
grep -Fq "$fastfetch_config" "$target_seed_script"
grep -Fq '"$kitty_dir/kitty.conf"' "$target_seed_script"
grep -Fq '"$fastfetch_dir/config.jsonc"' "$target_seed_script"
! grep -Fq 'cryoforge-neutral-kitty.conf' "$stock_seed_script"
! grep -Fq 'cryoforge-neutral-fastfetch.jsonc' "$stock_seed_script"

# This phase is a fixed fallback only: no wallpaper, dynamic-colour, network,
# automatic switching, selector, persistence, or theme-pack machinery.
phase_sources=(
  "$palette_source"
  "$kitty_adapter"
  "$fastfetch_adapter"
  "$kitty_config"
  "$fastfetch_config"
)
neutral_bindings=$(sed -n '/neutralPalette = import/,/^$/p' "$profiles_nix")
phase_profile_blocks=$(printf '%s\n%s\n' "$neutral_bindings" "$seed_block")
! grep -E -i -q 'chisa|deepSurface|lavender|blush|candidate.board' "${phase_sources[@]}"
! printf '%s\n' "$phase_profile_blocks" \
  | grep -E -i -q 'chisa|deepSurface|lavender|blush|candidate.board'
! grep -E -i -q \
  'wallpaper|matugen|pywal|wallust|dynamic[[:space:]_-]*(colou?r|theme)|colou?r[[:space:]_-]*extract' \
  "${phase_sources[@]}"
! printf '%s\n' "$phase_profile_blocks" \
  | grep -E -i -q \
    'wallpaper|matugen|pywal|wallust|dynamic[[:space:]_-]*(colou?r|theme)|colou?r[[:space:]_-]*extract'
! grep -E -i -q \
  'random|timer|rotation|rotate|cycle|inotify|watcher|curl|wget|https?://|fetchurl|fetchFrom|builtins\.fetch' \
  "${phase_sources[@]}"
! printf '%s\n' "$phase_profile_blocks" \
  | grep -E -i -q \
    'random|timer|rotation|rotate|cycle|inotify|watcher|curl|wget|https?://|fetchurl|fetchFrom|builtins\.fetch'
! grep -E -i -q \
  'theme[[:space:]_-]*(selector|engine|pack)|persist|rollback|automatic[[:space:]_-]*theme|theme[[:space:]_-]*switch' \
  "${phase_sources[@]}"
! printf '%s\n' "$phase_profile_blocks" \
  | grep -E -i -q \
    'theme[[:space:]_-]*(selector|engine|pack)|persist|rollback|automatic[[:space:]_-]*theme|theme[[:space:]_-]*switch'
! grep -E -i -q \
  'firefox|mozilla|zen.browser|vscode|vscodium|codium|extension' \
  "${phase_sources[@]}"
! printf '%s\n' "$phase_profile_blocks" \
  | grep -E -i -q \
    'firefox|mozilla|zen.browser|vscode|vscodium|codium|extension'
! printf '%s\n' "$phase_profile_blocks" \
  | grep -E -i -q \
    'phrolova|XCURSOR|xcursor|cursor[-_ ]*(theme|route|file)|mousecape|\.cur([[:space:]"'\'']|$)|\.ani([[:space:]"'\'']|$)'

# The focused check is anchored to the real-greeter target and never treats
# nixosConfigurations.nixos/classicSystem as the phase baseline.
phase16c_block=$(sed -n \
  '/phase16c-base-app-integration-contract =/,/phase17a-screenshot-contract =/p' \
  "$flake_nix")
printf '%s\n' "$phase16c_block" | grep -Fq 'targetHome = realGreeterSystem.config.home-manager.users.accelra;'
! printf '%s\n' "$phase16c_block" | grep -Fq 'nixosConfigurations.nixos.'
! printf '%s\n' "$phase16c_block" | grep -Fq 'targetHome = classicSystem'
! printf '%s\n' "$phase16c_block" \
  | grep -E -i -q \
    'phrolova|XCURSOR|xcursor|cursor[-_ ]*(theme|route|file)|mousecape|\.cur([[:space:]"'\'']|$)|\.ani([[:space:]"'\'']|$)'
grep -Fq 'phase16c-base-app-integration-contract' "$flake_nix"
grep -Fq './tests/phase16c/test_base_app_integration_contract.sh' "$flake_nix"

# Protected accepted behavior remains byte-for-byte stable. The generated
# Phase 16B files also protect layout, gaps, borders, rounding, blur, opacity,
# window rules, session startup, lock routing, and screenshot keybinds.
assert_sha256 "$flake_lock" bbca26850cfa467fc5afc177802ae1f3bbca20827f8577e5af9285711f30ade3
assert_sha256 "$home_nix" 4b05f82c54daa4c2e1f8a702dbf664bcebe5a339082a4a382bfc38600f96024a
assert_sha256 "$configuration_nix" 9cd8cfccae6924b685253cc1b973434c0e46ea0f22c21cb259aae6f33175dcd3
assert_sha256 "$desktop_hyprland" 777763eed185393068709618d9462d1e58fd291b4344a3e7f7e56f5c2b38c2ad
assert_sha256 "$cryoforge_package" eba2358673c4b316464ed80c8aebef271fc7bf00dc421760a58509d1bea4d312
assert_sha256 "$real_greeter_package" 795a7009c6a8d52db1d3d1aec4c243ee6bcbac6486eb4cf2bdcccb4bad0ce17a
assert_sha256 "$real_lock_package" 3c723b62e24a4f3b119ddfc3fe4e3ab50ba9771bb6007e0118bdab3b250d1175
assert_sha256 "$real_greeter_system" e63487de3f193c738a13bb4429b6bc83c01f73767de81057cb1e1ead58f99ce3
assert_sha256 "$gallery_patch" 0b73f3dc7fd093e4d5b167079c2a8f80fcf08e6791cb4855e55bbe983ccaf877
assert_sha256 "$special_patch" 738cc7cccca63d09cedc88889f6a5374111cd015d2f76a560c9f9180265d927d
assert_sha256 "$region_patch" 6db4facdd61b639abca962b147b9e4a1bd6bb3a849a24a9a12440decb483fc83
assert_sha256 "$region_script" b5ce59848a0750dc94f68baf2ebce15f72c727315c6e7d79fca5fb5c2cd2d495

assert_tree_sha256 "$chisa_dir" c4d0023da16013ef1de8e8148ba082fc3bab7921a8ba9846be039a4b3c33013a
assert_tree_sha256 "$greeter_dir" 25b5c3ab705711045d1d85f71d7940d304258dd9cbb7e74cd6eb0dbfd16b818d
assert_tree_sha256 "$regreet_dir" 5b08508f58e424dbcdf624839947ded0b13351e7dfaad3e2df09792346b3e6ce
assert_tree_sha256 "$hypr_dir" 6f2a3f371355608f8246c9803356309569bcd80d0a78bd8c60d901e8ce37d74c

assert_sha256 "$cryoforge_vars" 4de377b73d76c4a720c2ef35f38d4dc63f4280acafbd275682aed855dfd1a9ae
assert_sha256 "$cryoforge_general" f9b229abc10bae4bcd6c7c9732b72a23def4a469dd38d0f476f0aed3e57d68de
assert_sha256 "$cryoforge_decoration" 3435041b46f45c5232e4e10f8d90fc7af45f2c8f182b0ccbbcdf466ae644a45d
assert_sha256 "$cryoforge_animations" 7d7f4f41e2de5495c5c5970aa88b221b34a5b9f304b8909607777ffe727597a3
assert_sha256 "$cryoforge_rules" 6f466d2ab6b753148966fb5a4a8b0c20ede61c79c65a10681b2da241ff111e3d
assert_sha256 "$cryoforge_execs" fa910232d2ae16ae823155d8981d29739790e2d06dacffd1f35ca414f43516af
assert_sha256 "$cryoforge_functions" 03c2a014e65b5485ad199215ee4d8d427f512a79c4717b3870e41c5f4cee910e
assert_sha256 "$cryoforge_keybinds" 3ef3b41ca4243e1714a4daff808156d8d22e834bc168734bff7b6c48585ed60e
assert_sha256 "$cryoforge_gestures" 30e4d9bff2c433f4679a53a50626d22ae1b27da720959bc03921af3817be1571

printf '%s\n' 'phase16c stable neutral base app integration contract tests: pass'
