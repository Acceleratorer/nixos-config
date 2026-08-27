#!/usr/bin/env bash

set -euo pipefail

repo_root=${1:?missing repository source root}
package_output=${2:?missing theme-pack package output}
expected_registry_json=${3:?missing expected rendered registry}
expected_palette_json=${4:?missing expected palette JSON}
validator_evidence=${5:?missing validator evidence}

registry_nix="$repo_root/desktop/themes/registry.nix"
palette_nix="$repo_root/desktop/palette.nix"
package_nix="$repo_root/packages/cryoforge-theme-packs.nix"
flake_nix="$repo_root/flake.nix"
flake_lock="$repo_root/flake.lock"
installed_registry="$package_output/share/cryoforge/theme-packs/registry.json"

for file in \
  "$registry_nix" \
  "$palette_nix" \
  "$package_nix" \
  "$flake_nix" \
  "$flake_lock" \
  "$installed_registry" \
  "$expected_registry_json" \
  "$expected_palette_json" \
  "$validator_evidence"; do
  test -r "$file"
done

allowed_paths=(
  "desktop/themes/registry.nix"
  "packages/cryoforge-theme-packs.nix"
  "tests/phase19a/test_theme_pack_foundation_contract.sh"
  "flake.nix"
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
  local excluded=$2

  (
    cd "$root"
    find . -type f ! -path "$excluded" -print0 \
      | sort -z \
      | xargs -0 sha256sum \
      | sha256sum \
      | cut -d ' ' -f 1
  )
}

# All pre-Phase-19A desktop sources, package integrations, assets, QML, and
# historical contracts remain byte-identical to the accepted R2 baseline.
test "$(tree_sha256_without "$repo_root/desktop" './themes/*')" = \
  ceef33f0d985940ca78cfb3376b5ea4d61e01b44c4c7e5006d7bbd9fd402a193
test "$(tree_sha256_without "$repo_root/packages" './cryoforge-theme-packs.nix')" = \
  e5cb9f6f5275ec77a6a05a3653b38beaebe061c967f0eaf69c24d3c69193d86b
test "$(tree_sha256_without "$repo_root/tests" './phase19a/*')" = \
  eb4a2deb7dc6a0a264257f16e9158aee216206c3af5aeb116fbb9f3757e21ac9
test "$(sha256 "$palette_nix")" = \
  8897b1df8d0c407de6536c6cf3014b4cdd3d675c25e804148c9b91f1024d6f35
test "$(sha256 "$repo_root/desktop/profiles.nix")" = \
  9de59b0dca05eb17df9b8452472b353f12ec8cdc48de1bcd93c1f1c86d1c433e
test "$(sha256 "$flake_lock")" = \
  bbca26850cfa467fc5afc177802ae1f3bbca20827f8577e5af9285711f30ade3
test "$(sha256 "$repo_root/packages/caelestia-cryoforge.nix")" = \
  fa1e2df3757d80d5a4093c03201141a302a46cd064cf7a1f69df0dc8c317ab56
test "$(sha256 "$repo_root/desktop/apps/kitty.nix")" = \
  c7a8efdfe35c7ad9936ad768fb99aa577ee10d52755531a290d38bed2dff1f89
test "$(sha256 "$repo_root/desktop/apps/fastfetch.nix")" = \
  c8aed6c3fccaa086968793e37daa2514eac2c641578f7d996c8fe598bc5e2a18

# The source is a single pure model. Neutral imports the existing palette,
# carries no second raw palette, and Chisa remains outside this registry.
grep -Fq 'registry ? {' "$registry_nix"
grep -Fq 'schemaVersion = 1;' "$registry_nix"
grep -Fq 'defaultPackId = "neutral";' "$registry_nix"
test "$(grep -Fxc '        id = "neutral";' "$registry_nix")" -eq 1
grep -Fq 'displayName = "CryoForge Neutral";' "$registry_nix"
grep -Fq 'kind = "neutral";' "$registry_nix"
grep -Fq 'palette = import ../palette.nix;' "$registry_nix"
! grep -E -q '"#[0-9a-fA-F]{6}"' "$registry_nix"
! grep -E -i -q 'chisa|denia|img[1-9]' "$registry_nix"

# The package renders one deterministic JSON file with one trailing newline,
# installs it read-only, and has no runtime or fetch dependency.
grep -Fq 'builtins.toJSON registry + "\n"' "$package_nix"
grep -Fq '"$out/share/cryoforge/theme-packs/registry.json"' "$package_nix"
grep -Fq 'install -Dm0444' "$package_nix"
! grep -E -i -q \
  'runtimeInputs|buildInputs|propagatedBuildInputs|fetchurl|fetchFrom|builtins\.fetch|curl|wget|https?://' \
  "$package_nix"

test "$package_output" = "$(readlink -f "$package_output")"
case "$package_output" in
  /nix/store/*-cryoforge-theme-packs-1.0.0) ;;
  *) exit 1 ;;
esac
test "$(stat -c '%a' "$installed_registry")" = 444
test "$(find "$package_output" -type f -printf '%P\n')" = \
  "share/cryoforge/theme-packs/registry.json"
test -z "$(find "$package_output" -type l -print)"
test "$(sha256 "$installed_registry")" = "$(sha256 "$expected_registry_json")"
test "$(cat "$validator_evidence")" = \
  "valid local curated assets accepted; malformed models rejected"

python3 - "$installed_registry" "$expected_palette_json" <<'PY'
import json
import re
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
palette_path = Path(sys.argv[2])
raw = registry_path.read_bytes()

def no_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        assert key not in result, f"duplicate JSON key: {key}"
        result[key] = value
    return result

assert raw.endswith(b"\n")
assert not raw.endswith(b"\n\n")
assert b"\n" not in raw[:-1]

registry = json.loads(raw, object_pairs_hook=no_duplicate_keys)
palette = json.loads(
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

assert set(registry) == {"schemaVersion", "defaultPackId", "packs"}
assert registry["schemaVersion"] == 1
assert registry["defaultPackId"] == "neutral"
assert len(registry["packs"]) == 1

pack = registry["packs"][0]
assert set(pack) == {
    "id",
    "displayName",
    "kind",
    "wallpaper",
    "palette",
    "shell",
    "preview",
}
assert pack["id"] == "neutral"
assert pack["displayName"] == "CryoForge Neutral"
assert pack["kind"] == "neutral"
assert pack["wallpaper"] is None
assert pack["palette"] == palette
assert set(pack["palette"]) == semantic_keys
assert len(pack["palette"]) == 12
assert all(
    re.fullmatch(r"#[0-9a-f]{6}", value)
    for value in pack["palette"].values()
)
assert pack["shell"] == shell
assert set(pack["shell"].values()) <= semantic_keys

preview = pack["preview"]
assert set(preview) == {"thumbnail", "description", "swatches"}
assert preview["thumbnail"] is None
assert preview["description"] == (
    "Wallpaper-independent fallback using the active CryoForge neutral palette."
)
assert 1 <= len(preview["swatches"]) <= 6
assert len(preview["swatches"]) == len(set(preview["swatches"]))
assert set(preview["swatches"]) <= semantic_keys

ids = [candidate["id"] for candidate in registry["packs"]]
assert len(ids) == len(set(ids))
assert ids.count(registry["defaultPackId"]) == 1

for forbidden in (
    b"/nix/store/",
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

# Flake wiring is limited to package/check projection. There is no NixOS,
# Home Manager, Caelestia, greeter, lock, QML, or activation consumer.
grep -Fq 'cryoforge-theme-packs = cryoforgeThemePacks;' "$flake_nix"
grep -Fq 'phase19a-theme-pack-foundation-contract =' "$flake_nix"
test "$(grep -o 'cryoforgeThemePacks' "$flake_nix" | wc -l)" -eq 3

! grep -E -i -q \
  'selector|apply[[:space:]]+action|preview[[:space:]_-]*execution|selected[[:space:]_-]*theme|persist|automatic[[:space:]_-]*switch|random[[:space:]_-]*rotation|dynamic[[:space:]_-]*(colou?r|theme)|matugen|pywal|wallust|timer|watcher|daemon|Process[[:space:]]*\{|IpcHandler[[:space:]]*\{|FileView[[:space:]]*\{|curl|wget|fetchurl|fetchFrom|builtins\.fetch' \
  "$registry_nix" "$package_nix"

printf '%s\n' 'phase19a theme-pack foundation contract tests: pass'
