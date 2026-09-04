#!/usr/bin/env bash

set -euo pipefail

repo_root=${1:?missing repository source root}
theme_packs=${2:?missing theme-pack output}
publisher_package=${3:?missing test publisher output}
runtime_package=${4:?missing test runtime output}

# The test publisher and resolver are intentionally bound to this fixed state
# root by flake.nix; keep the transaction fixture on that same path.
public_root=/build/phase19d-public-state
publisher="$publisher_package/bin/cryoforge-publish-active-theme"
resolver="$runtime_package/bin/cryoforge-resolve-active-theme"
helper="$runtime_package/bin/cryoforge-apply-theme-pack"
theme_pack_root="$theme_packs/share/cryoforge/theme-packs"
runtime_root="$runtime_package/share/cryoforge/theme-runtime"
source_registry="$theme_pack_root/source-registry.json"
gallery_registry="$theme_pack_root/registry.json"
manifest="$publisher_package/share/cryoforge/theme-publisher/manifest.json"
python=${PYTHON:-python3}

test -r "$repo_root/desktop/themes/registry.nix"
for path in \
  "$source_registry" \
  "$gallery_registry" \
  "$manifest" \
  "$publisher" \
  "$resolver" \
  "$helper"; do
  test -r "$path"
done

sha256() {
  sha256sum "$1" | cut -d ' ' -f 1
}

json_field() {
  local field=$1

  "$python" -c '
import json
import sys

value = json.load(sys.stdin)
print(value[sys.argv[1]])
' "$field"
}

rm -rf "$public_root"
mkdir -m 0755 "$public_root"

"$python" - \
  "$source_registry" \
  "$gallery_registry" \
  "$manifest" \
  "$theme_pack_root" \
  "$runtime_root" <<'PY'
import hashlib
import json
import pathlib
import re
import sys

source_path, gallery_path, manifest_path, pack_root, runtime_root = map(
    pathlib.Path, sys.argv[1:]
)


def no_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        assert key not in result, key
        result[key] = value
    return result


source = json.loads(source_path.read_text(), object_pairs_hook=no_duplicate_keys)
gallery = json.loads(gallery_path.read_text(), object_pairs_hook=no_duplicate_keys)
manifest = json.loads(manifest_path.read_text(), object_pairs_hook=no_duplicate_keys)

assert set(source) == {"schemaVersion", "defaultPackId", "fallbackPackId", "packs"}
assert source["schemaVersion"] == 2
assert source["defaultPackId"] == "neutral"
source_ids = [pack["id"] for pack in source["packs"]]
assert len(source_ids) == 19
assert len(source_ids) == len(set(source_ids))
assert source_ids[0] == "neutral"
curated = [pack for pack in source["packs"] if pack["kind"] == "curated"]
curated_ids = [pack["id"] for pack in curated]
assert len(curated) == 18
assert source["packs"][0]["allowedWallpaperPackIds"] == curated_ids

assert set(gallery) == {"schemaVersion", "defaultPackId", "packs"}
assert gallery["schemaVersion"] == 1
assert [pack["id"] for pack in gallery["packs"]] == source_ids

assert set(manifest) == {"schemaVersion", "packs", "wallpapers"}
assert manifest["schemaVersion"] == 1
assert sorted(manifest["packs"]) == sorted(source_ids)
assert sorted(manifest["wallpapers"]) == sorted(curated_ids)

expected_files = {
    "registry.json",
    "source-registry.json",
}
for pack in curated:
    pack_id = pack["id"]
    assert re.fullmatch(r"cryoforge-[a-z0-9-]+", pack_id)
    wallpaper = pack["assets"]["wallpaper"]
    thumbnail = pack["assets"]["thumbnail"]
    assert re.fullmatch(r"assets/[a-z0-9-]+/wallpaper\.jpg", wallpaper["path"])
    assert re.fullmatch(r"assets/[a-z0-9-]+/preview\.jpg", thumbnail["path"])
    for asset in (wallpaper, thumbnail):
        installed = pack_root / asset["path"]
        runtime_asset = runtime_root / asset["path"]
        assert installed.is_file() and not installed.is_symlink()
        assert runtime_asset.is_file() and not runtime_asset.is_symlink()
        assert hashlib.sha256(installed.read_bytes()).hexdigest() == asset["sha256"]
        assert hashlib.sha256(runtime_asset.read_bytes()).hexdigest() == asset["sha256"]
    expected_files.update(
        {
            wallpaper["path"],
            thumbnail["path"],
            f"assets/{pack_id}/SOURCE.md",
        }
    )
    scheme = manifest["packs"][pack_id]["scheme"]
    assert pathlib.Path(scheme["path"]).is_file()
    assert re.fullmatch(r"[0-9a-f]{64}", scheme["sha256"])
    runtime_scheme = runtime_root / "schemes" / f"{pack_id}.json"
    assert runtime_scheme.is_file()
    scheme_data = json.loads(runtime_scheme.read_text(), object_pairs_hook=no_duplicate_keys)
    assert scheme_data["name"] == "cryoforge-pack"
    assert scheme_data["flavour"] == pack_id
    assert scheme_data["mode"] == "dark"
    assert scheme_data["variant"] == "tonalspot"
    assert len(scheme_data["colours"]) == 74

assert {
    path.relative_to(pack_root).as_posix()
    for path in pack_root.rglob("*")
    if path.is_file()
} == expected_files
assert all(
    path.stat().st_mode & 0o777 == 0o444
    for path in pack_root.rglob("*")
    if path.is_file()
)
PY

"$publisher" chisa-pool chisa-pool 0 >/dev/null
generation=1
session_root="$TMPDIR/phase20-session"
mkdir -p "$session_root/home"

mapfile -t curated_ids < <(
  "$python" - "$source_registry" <<'PY'
import json
import sys

for pack in json.load(open(sys.argv[1]))["packs"]:
    if pack["kind"] == "curated":
        print(pack["id"])
PY
)
test "${#curated_ids[@]}" -eq 18

for pack_id in "${curated_ids[@]}"; do
  output=$(env \
    HOME="$session_root/home" \
    XDG_STATE_HOME="$session_root/state" \
    XDG_DATA_HOME="$session_root/data" \
    "$helper" "$pack_id")
  expected_generation=$((generation + 1))
  test "$(printf '%s' "$output" | json_field packId)" = "$pack_id"
  test "$(printf '%s' "$output" | json_field wallpaperPackId)" = "$pack_id"
  test "$(printf '%s' "$output" | json_field generation)" = "$expected_generation"
  test "$("$resolver" | json_field packId)" = "$pack_id"
  test "$("$resolver" | json_field wallpaperPackId)" = "$pack_id"
  test "$("$resolver" | json_field generation)" = "$expected_generation"
  grep -Fq "\"flavour\":\"$pack_id\"" \
    "$session_root/state/caelestia/scheme.json"
  expected_scheme=$(
    "$python" - "$manifest" "$pack_id" <<'PY'
import json
import sys

print(json.load(open(sys.argv[1]))["packs"][sys.argv[2]]["scheme"]["sha256"])
PY
  )
  test "$(sha256 "$session_root/state/caelestia/scheme.json")" = "$expected_scheme"
  expected_wallpaper=$(
    "$python" - "$manifest" "$pack_id" <<'PY'
import json
import sys

print(json.load(open(sys.argv[1]))["wallpapers"][sys.argv[2]]["wallpaper"]["path"])
PY
  )
  test "$(cat "$session_root/state/caelestia/wallpaper/path.txt")" = "$expected_wallpaper"
  test "$(readlink "$session_root/state/caelestia/wallpaper/current")" = "$expected_wallpaper"
  generation=$expected_generation
done

test "$(find "$session_root" -name '*.cryoforge-stage.*' -o -name '*.cryoforge-backup.*')" = ""
test ! -e "$session_root/state/caelestia/.cryoforge-theme-apply.lock"
test "$("$resolver" | json_field generation)" = "$generation"

printf '%s\n' 'phase20 all curated theme-pack apply contract tests: pass'
