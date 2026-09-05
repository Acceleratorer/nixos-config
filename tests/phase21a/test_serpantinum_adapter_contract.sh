#!/usr/bin/env bash

set -euo pipefail

repo_root=${1:?missing repository source root}
production_adapter_package=${2:?missing production adapter package}
fixture_adapter_package=${3:?missing fixture adapter package}
runtime_package=${4:?missing CryoForge runtime package}
symlink_fixture=${5:?missing symlink fixture}
adapter_source=${6:?missing adapter source}
python=${PYTHON:-python3}

production_adapter="$production_adapter_package/bin/cryoforge-serpantinum-adapter"
fixture_adapter="$fixture_adapter_package/bin/cryoforge-serpantinum-adapter"
runtime_root="$runtime_package/share/cryoforge/theme-runtime"
output_json="$TMPDIR/phase21a-output.json"

test -d "$repo_root/.git"
for path in \
  "$production_adapter" \
  "$fixture_adapter" \
  "$runtime_root/schemes/chisa-pool.json" \
  "$runtime_root/schemes/cryoforge-denia.json" \
  "$runtime_root/assets/chisa-pool/wallpaper.jpg" \
  "$runtime_root/assets/cryoforge-denia/wallpaper.jpg" \
  "$symlink_fixture/scheme.json" \
  "$symlink_fixture/wallpaper.jpg" \
  "$adapter_source"; do
  test -e "$path"
done
test -x "$production_adapter"
test -x "$fixture_adapter"
test ! -L "$runtime_root/schemes/chisa-pool.json"
test ! -L "$runtime_root/schemes/cryoforge-denia.json"

sha256() {
  sha256sum "$1" | cut -d ' ' -f 1
}

write_resolver_fixture() {
  local output=$1
  local pack_id=$2
  local wallpaper_pack_id=$3
  local generation=$4
  local source=$5
  local scheme_path=$6
  local wallpaper_path=$7
  local thumbnail_path=$8
  local scheme_sha256=${9:-$(sha256 "$scheme_path")}
  local wallpaper_sha256=${10:-$(sha256 "$wallpaper_path")}
  local thumbnail_sha256=${11:-$(sha256 "$thumbnail_path")}

  "$python" - \
    "$output" \
    "$pack_id" \
    "$wallpaper_pack_id" \
    "$generation" \
    "$source" \
    "$scheme_path" \
    "$scheme_sha256" \
    "$wallpaper_path" \
    "$wallpaper_sha256" \
    "$thumbnail_path" \
    "$thumbnail_sha256" <<'PY'
import json
import pathlib
import sys

(
    output,
    pack_id,
    wallpaper_pack_id,
    generation,
    source,
    scheme_path,
    scheme_sha256,
    wallpaper_path,
    wallpaper_sha256,
    thumbnail_path,
    thumbnail_sha256,
) = sys.argv[1:]

value = {
    "schemaVersion": 1,
    "packId": pack_id,
    "wallpaperPackId": wallpaper_pack_id,
    "generation": int(generation),
    "source": source,
    "schemePath": scheme_path,
    "schemeSha256": scheme_sha256,
    "wallpaperPath": wallpaper_path,
    "wallpaperSha256": wallpaper_sha256,
    "thumbnailPath": thumbnail_path,
    "thumbnailSha256": thumbnail_sha256,
}
pathlib.Path(output).write_text(
    json.dumps(value, separators=(",", ":")) + "\n",
    encoding="utf-8",
)
PY
}

assert_output() {
  local output=$1
  local expected_scheme=$2
  local expected_pack_id=$3
  local expected_wallpaper_pack_id=$4
  local expected_generation=$5

  printf '%s\n' "$output" > "$output_json"
  "$python" - \
    "$output_json" \
    "$expected_scheme" \
    "$expected_pack_id" \
    "$expected_wallpaper_pack_id" \
    "$expected_generation" <<'PY'
import hashlib
import json
import pathlib
import sys

output_path, scheme_path, pack_id, wallpaper_pack_id, generation = sys.argv[1:]
output = json.loads(pathlib.Path(output_path).read_text(encoding="utf-8"))
scheme = json.loads(pathlib.Path(scheme_path).read_text(encoding="utf-8"))

expected_keys = {
    "packId",
    "wallpaperPackId",
    "generation",
    "wallpaperPath",
    "wallpaperSha256",
    "colors",
}
assert set(output) == expected_keys
assert output["packId"] == pack_id
assert output["wallpaperPackId"] == wallpaper_pack_id
assert output["generation"] == int(generation)
assert output["wallpaperPath"].startswith("/nix/store/")
assert output["wallpaperSha256"] == hashlib.sha256(
    pathlib.Path(output["wallpaperPath"]).read_bytes()
).hexdigest()
assert set(output["colors"]) == {
    "base",
    "mantle",
    "crust",
    "text",
    "subtext0",
    "subtext1",
    "surface0",
    "surface1",
    "surface2",
    "overlay0",
    "overlay1",
    "overlay2",
    "blue",
    "sapphire",
    "peach",
    "green",
    "red",
    "mauve",
    "pink",
    "yellow",
    "maroon",
    "teal",
}
mapping = {
    "base": "surfaceContainerLowest",
    "mantle": "surfaceContainerLow",
    "crust": "surface",
    "text": "onSurface",
    "subtext0": "onSurfaceVariant",
    "subtext1": "outline",
    "surface0": "surfaceContainer",
    "surface1": "surfaceContainerHigh",
    "surface2": "surfaceContainerHighest",
    "overlay0": "inverseSurface",
    "overlay1": "inverseSurface",
    "overlay2": "inverseSurface",
    "blue": "primary",
    "sapphire": "primaryContainer",
    "peach": "tertiary",
    "green": "secondary",
    "red": "error",
    "mauve": "primary",
    "pink": "tertiaryContainer",
    "yellow": "secondaryContainer",
    "maroon": "errorContainer",
    "teal": "secondary",
}
assert output["colors"] == {
    target: "#" + scheme["colours"][source]
    for target, source in mapping.items()
}
assert len(pathlib.Path(output_path).read_bytes()) <= 4096
PY
}

expect_rejection() {
  local fixture=$1
  local error_log="$TMPDIR/phase21a-error-$(basename "$fixture")"
  local stdout

  if stdout=$(
    PHASE21A_RESOLVER_FIXTURE="$fixture" \
      "$fixture_adapter" \
      2> "$error_log"
  ); then
    printf 'adapter unexpectedly accepted %s\n' "$fixture" >&2
    return 1
  fi
  test -z "$stdout"
  test -s "$error_log"
  "$python" - "$error_log" <<'PY'
import json
import pathlib
import sys

value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert set(value) == {"ok", "error"}
assert value["ok"] is False
assert isinstance(value["error"], str) and value["error"]
PY
}

for symbol in \
  Wallpaper \
  Matugen \
  FirstLaunch \
  lock \
  greeter \
  publisher \
  sudo \
  systemctl \
  loginctl \
  reboot \
  restart \
  Preview \
  Apply; do
  ! grep -Fq "$symbol" "$adapter_source"
done

chisa_scheme="$runtime_root/schemes/chisa-pool.json"
chisa_wallpaper="$runtime_root/assets/chisa-pool/wallpaper.jpg"
chisa_thumbnail="$runtime_root/assets/chisa-pool/preview.jpg"
denia_scheme="$runtime_root/schemes/cryoforge-denia.json"
denia_wallpaper="$runtime_root/assets/cryoforge-denia/wallpaper.jpg"
denia_thumbnail="$runtime_root/assets/cryoforge-denia/preview.jpg"

chisa_fixture="$TMPDIR/phase21a-chisa.json"
write_resolver_fixture \
  "$chisa_fixture" \
  chisa-pool \
  chisa-pool \
  1 \
  public \
  "$chisa_scheme" \
  "$chisa_wallpaper" \
  "$chisa_thumbnail"
chisa_output=$(
  PHASE21A_RESOLVER_FIXTURE="$chisa_fixture" \
    "$fixture_adapter"
)
assert_output "$chisa_output" "$chisa_scheme" chisa-pool chisa-pool 1

denia_fixture="$TMPDIR/phase21a-denia.json"
write_resolver_fixture \
  "$denia_fixture" \
  cryoforge-denia \
  cryoforge-denia \
  2 \
  public \
  "$denia_scheme" \
  "$denia_wallpaper" \
  "$denia_thumbnail"
denia_output=$(
  PHASE21A_RESOLVER_FIXTURE="$denia_fixture" \
    "$fixture_adapter"
)
assert_output "$denia_output" "$denia_scheme" cryoforge-denia cryoforge-denia 2

production_output=$("$production_adapter")
production_pack_id=$(
  printf '%s\n' "$production_output" |
    "$python" -c 'import json, sys; print(json.load(sys.stdin)["packId"])'
)
assert_output \
  "$production_output" \
  "$runtime_root/schemes/$production_pack_id.json" \
  "$production_pack_id" \
  "$(
    printf '%s\n' "$production_output" |
      "$python" -c 'import json, sys; print(json.load(sys.stdin)["wallpaperPackId"])'
  )" \
  "$(
    printf '%s\n' "$production_output" |
      "$python" -c 'import json, sys; print(json.load(sys.stdin)["generation"])'
  )"

printf '{not-json\n' > "$TMPDIR/phase21a-malformed.json"
expect_rejection "$TMPDIR/phase21a-malformed.json"

"$python" - "$chisa_fixture" "$TMPDIR/phase21a-extra.json" <<'PY'
import json
import pathlib
import sys

value = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
value["extra"] = True
pathlib.Path(sys.argv[2]).write_text(
    json.dumps(value, separators=(",", ":")) + "\n",
    encoding="utf-8",
)
PY
expect_rejection "$TMPDIR/phase21a-extra.json"

unknown_fixture="$TMPDIR/phase21a-unknown-id.json"
write_resolver_fixture \
  "$unknown_fixture" \
  unknown \
  chisa-pool \
  3 \
  public \
  "$chisa_scheme" \
  "$chisa_wallpaper" \
  "$chisa_thumbnail"
expect_rejection "$unknown_fixture"

non_store_scheme_fixture="$TMPDIR/phase21a-non-store-scheme.json"
write_resolver_fixture \
  "$non_store_scheme_fixture" \
  chisa-pool \
  chisa-pool \
  4 \
  public \
  /tmp/phase21a-scheme.json \
  "$chisa_wallpaper" \
  "$chisa_thumbnail" \
  0000000000000000000000000000000000000000000000000000000000000000
expect_rejection "$non_store_scheme_fixture"

non_store_wallpaper_fixture="$TMPDIR/phase21a-non-store-wallpaper.json"
write_resolver_fixture \
  "$non_store_wallpaper_fixture" \
  chisa-pool \
  chisa-pool \
  5 \
  public \
  "$chisa_scheme" \
  /tmp/phase21a-wallpaper.jpg \
  "$chisa_thumbnail" \
  "$(sha256 "$chisa_scheme")" \
  0000000000000000000000000000000000000000000000000000000000000000
expect_rejection "$non_store_wallpaper_fixture"

symlink_scheme_fixture="$TMPDIR/phase21a-symlink-scheme.json"
write_resolver_fixture \
  "$symlink_scheme_fixture" \
  chisa-pool \
  chisa-pool \
  6 \
  public \
  "$symlink_fixture/scheme.json" \
  "$chisa_wallpaper" \
  "$chisa_thumbnail"
expect_rejection "$symlink_scheme_fixture"

symlink_wallpaper_fixture="$TMPDIR/phase21a-symlink-wallpaper.json"
write_resolver_fixture \
  "$symlink_wallpaper_fixture" \
  chisa-pool \
  chisa-pool \
  7 \
  public \
  "$chisa_scheme" \
  "$symlink_fixture/wallpaper.jpg" \
  "$chisa_thumbnail"
expect_rejection "$symlink_wallpaper_fixture"

scheme_mismatch_fixture="$TMPDIR/phase21a-scheme-hash-mismatch.json"
write_resolver_fixture \
  "$scheme_mismatch_fixture" \
  chisa-pool \
  chisa-pool \
  8 \
  public \
  "$chisa_scheme" \
  "$chisa_wallpaper" \
  "$chisa_thumbnail" \
  0000000000000000000000000000000000000000000000000000000000000000
expect_rejection "$scheme_mismatch_fixture"

wallpaper_mismatch_fixture="$TMPDIR/phase21a-wallpaper-hash-mismatch.json"
write_resolver_fixture \
  "$wallpaper_mismatch_fixture" \
  chisa-pool \
  chisa-pool \
  9 \
  public \
  "$chisa_scheme" \
  "$chisa_wallpaper" \
  "$chisa_thumbnail" \
  "$(sha256 "$chisa_scheme")" \
  0000000000000000000000000000000000000000000000000000000000000000
expect_rejection "$wallpaper_mismatch_fixture"

no_write_root="$TMPDIR/phase21a-no-write"
mkdir -p "$no_write_root/home" "$no_write_root/config" "$no_write_root/data" "$no_write_root/state"
before=$(
  find "$no_write_root" -mindepth 1 -printf '%y %m %p\n' |
    sort
)
env \
  HOME="$no_write_root/home" \
  XDG_CONFIG_HOME="$no_write_root/config" \
  XDG_DATA_HOME="$no_write_root/data" \
  XDG_STATE_HOME="$no_write_root/state" \
  PHASE21A_RESOLVER_FIXTURE="$chisa_fixture" \
  "$fixture_adapter" > /dev/null
after=$(
  find "$no_write_root" -mindepth 1 -printf '%y %m %p\n' |
    sort
)
test "$before" = "$after"

printf '%s\n' \
  'phase21a CryoForge to Serpantinum adapter contract tests: pass'
