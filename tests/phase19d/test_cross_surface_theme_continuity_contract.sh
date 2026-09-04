#!/usr/bin/env bash

set -euo pipefail

repo_root=${1:?missing repository source root}
theme_packs=${2:?missing theme-pack output}
production_publisher_package=${3:?missing production publisher output}
test_publisher_package=${4:?missing test publisher output}
runtime_package=${5:?missing runtime output}
selector_root=${6:?missing selector shell root}
greeter_package=${7:?missing real-greeter output}
greetd_command=${8:?missing rendered greetd command}
greetd_unit=${9:?missing rendered greetd unit}
system_output=${10:?missing rendered NixOS system}
boundary_evidence=${11:?missing evaluated boundary evidence}
production_runtime_package=${12:?missing production runtime output}
production_publisher_invoker=${13:?missing production publisher invoker}

public_root=/build/phase19d-public-state
production_publisher="$production_publisher_package/bin/cryoforge-publish-active-theme"
publisher="$test_publisher_package/bin/cryoforge-publish-active-theme"
resolver="$runtime_package/bin/cryoforge-resolve-active-theme"
helper="$runtime_package/bin/cryoforge-apply-theme-pack"
runtime_root="$runtime_package/share/cryoforge/theme-runtime"
production_resolver="$production_runtime_package/bin/cryoforge-resolve-active-theme"
production_helper="$production_runtime_package/bin/cryoforge-apply-theme-pack"
source_registry="$theme_packs/share/cryoforge/theme-packs/source-registry.json"
gallery_registry="$runtime_root/registry.json"
production_manifest="$production_publisher_package/share/cryoforge/theme-publisher/manifest.json"
manifest="$test_publisher_package/share/cryoforge/theme-publisher/manifest.json"
policy="$production_publisher_package/share/polkit-1/actions/org.cryoforge.theme.publish.policy"
installed_gallery="$selector_root/modules/nexus/pages/wallandstyle/ThemePackGallery.qml"
greeter_root="$greeter_package/share/caelestia-real-greeter"
python=${PYTHON:-python3}

sha256() {
  sha256sum "$1" | cut -d ' ' -f 1
}

for path in \
  "$production_publisher" \
  "$publisher" \
  "$resolver" \
  "$helper" \
  "$production_resolver" \
  "$production_helper" \
  "$production_publisher_invoker" \
  "$source_registry" \
  "$gallery_registry" \
  "$production_manifest" \
  "$manifest" \
  "$policy" \
  "$installed_gallery" \
  "$greeter_root/real-greeter/GreeterContent.qml" \
  "$greeter_root/services/Wallpapers.qml" \
  "$greeter_package/bin/.caelestia-real-greeter-qml-wrapped" \
  "$greetd_command" \
  "$greetd_unit" \
  "$system_output" \
  "$boundary_evidence"; do
  test -e "$path"
done
test "$production_publisher" != "$publisher"
test "$production_runtime_package" != "$runtime_package"
test -x "$production_publisher_invoker"
test "$(sha256 "$production_manifest")" = "$(sha256 "$manifest")"

json_field() {
  local field=$1

  "$python" -c '
import json
import sys

value = json.load(sys.stdin)
field = sys.argv[1]
if field not in value:
    raise SystemExit(1)
print(value[field])
' "$field"
}

resolve_json() {
  "$resolver"
}

resolve_field() {
  local field=$1

  resolve_json | json_field "$field"
}

public_fingerprint() {
  if [ -e "$public_root/active.json" ]; then
    sha256 "$public_root/active.json"
  else
    printf '%s\n' missing
  fi
}

tree_fingerprint() {
  local root=$1

  if [ ! -e "$root" ]; then
    printf '%s\n' missing
    return
  fi
  {
    find "$root" -type d -printf 'd %m %p\n' | sort
    find "$root" -type l -printf 'l %m %p -> %l\n' | sort
    find "$root" -type f -print0 |
      sort -z |
      while IFS= read -r -d '' path; do
        printf 'f %s %s ' "$(stat -c '%a' "$path")" "$path"
        sha256sum "$path"
      done
  } | sha256sum | cut -d ' ' -f 1
}

wait_for_identity() {
  local pack_id=$1
  local attempts=0

  while [ "$attempts" -lt 500 ]; do
    if [ "$(resolve_field packId)" = "$pack_id" ]; then
      return
    fi
    attempts=$((attempts + 1))
    sleep 0.01
  done
  return 1
}

assert_clean_output() {
  "$python" - "$@" <<'PY'
import pathlib
import sys

for name in sys.argv[1:]:
    data = pathlib.Path(name).read_bytes()
    assert b"\x1b" not in data
    assert b"/dev/pts/" not in data
    for byte in data:
        assert byte in (0x09, 0x0A, 0x0D) or byte >= 0x20
PY
}

allowed_paths=(
  "desktop/themes/registry.nix"
  "desktop/themes/chisa-pool/pack.nix"
  "desktop/themes/chisa-pool/SOURCE.md"
  "desktop/themes/caelestia-schemes.nix"
  "desktop/themes/apply-theme-pack.sh"
  "desktop/themes/publish-active-theme.sh"
  "desktop/themes/resolve-active-theme.sh"
  "desktop/themes/org.cryoforge.theme.publish.policy"
  "packages/cryoforge-theme-packs.nix"
  "packages/cryoforge-theme-runtime.nix"
  "packages/cryoforge-theme-publisher.nix"
  "packages/caelestia-cryoforge-theme-selector.nix"
  "desktop/caelestia/cryoforge-nexus-theme-selector.patch"
  "desktop/caelestia/nexus/ThemePackGallery.qml"
  "desktop/profiles.nix"
  "packages/caelestia-real-greeter.nix"
  "desktop/caelestia/real-greeter-system.nix"
  "desktop/caelestia/real-greeter/launch-runtime.sh"
  "desktop/caelestia/real-greeter/GreeterContent.qml"
  "desktop/caelestia/real-greeter/services/Wallpapers.qml"
  "flake.nix"
  "tests/phase19d/test_cross_surface_theme_continuity_contract.sh"
)

if git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
  actual_paths=$(
    {
      git -C "$repo_root" diff --name-only
      git -C "$repo_root" ls-files --others --exclude-standard
    } | sort -u
  )
  for path in $actual_paths; do
    printf '%s\n' "${allowed_paths[@]}" | grep -Fqx "$path"
  done
  test -z "$(git -C "$repo_root" diff --cached --name-status)"
  git -C "$repo_root" diff --check
  git -C "$repo_root" diff --cached --check
fi

# Registry and package projections are exact, finite, and asset-pinned.
"$python" - "$source_registry" "$gallery_registry" "$manifest" "$runtime_root" <<'PY'
import json
import pathlib
import re
import sys

source_path, gallery_path, manifest_path, runtime_root = map(pathlib.Path, sys.argv[1:])


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        assert key not in result
        result[key] = value
    return result


source = json.loads(source_path.read_text(), object_pairs_hook=unique_object)
gallery = json.loads(gallery_path.read_text(), object_pairs_hook=unique_object)
manifest = json.loads(manifest_path.read_text(), object_pairs_hook=unique_object)

assert set(source) == {"schemaVersion", "defaultPackId", "fallbackPackId", "packs"}
assert source["schemaVersion"] == 2
assert source["defaultPackId"] == "neutral"
assert source["fallbackPackId"] == "chisa-pool"
assert [pack["id"] for pack in source["packs"]] == [
    "neutral",
    "chisa-pool",
    "cryoforge-denia",
]

packs = {pack["id"]: pack for pack in source["packs"]}
assert packs["neutral"]["kind"] == "overlay"
assert packs["neutral"]["assets"] == {"wallpaper": None, "thumbnail": None}
assert packs["neutral"]["allowedWallpaperPackIds"] == [
    "chisa-pool",
    "cryoforge-denia",
]
assert packs["chisa-pool"]["fallback"] == {
    "missingPublicState": True,
    "invalidPublicState": True,
    "recovery": True,
}
assert packs["chisa-pool"]["scheme"]["mode"] == "fixed"
assert len(packs["chisa-pool"]["scheme"]["colours"]) == 74
assert packs["chisa-pool"]["assets"]["wallpaper"]["sha256"] == (
    "a4dfcf92c4170405ac37102b27c606c5e9b1bb6cd77c9f04d530fa752aab604c"
)
assert packs["cryoforge-denia"]["assets"]["wallpaper"]["sha256"] == (
    "34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb"
)

assert set(gallery) == {"schemaVersion", "defaultPackId", "packs"}
assert gallery["schemaVersion"] == 1
assert [pack["id"] for pack in gallery["packs"]] == [
    "neutral",
    "chisa-pool",
    "cryoforge-denia",
]
assert gallery["packs"][0]["wallpaper"] is None
assert gallery["packs"][1]["wallpaper"] == "assets/chisa-pool/wallpaper.jpg"
assert gallery["packs"][2]["wallpaper"] == "assets/cryoforge-denia/wallpaper.jpg"

assert set(manifest) == {"schemaVersion", "packs", "wallpapers"}
assert manifest["schemaVersion"] == 1
assert sorted(manifest["packs"]) == [
    "chisa-pool",
    "cryoforge-denia",
    "neutral",
]
assert sorted(manifest["wallpapers"]) == ["chisa-pool", "cryoforge-denia"]
assert manifest["packs"]["neutral"]["allowedWallpaperPackIds"] == [
    "chisa-pool",
    "cryoforge-denia",
]

for pack_id in ("neutral", "chisa-pool", "cryoforge-denia"):
    scheme = pathlib.Path(manifest["packs"][pack_id]["scheme"]["path"])
    assert scheme.is_file()
    assert re.fullmatch(r"[0-9a-f]{64}", manifest["packs"][pack_id]["scheme"]["sha256"])
    assert (runtime_root / "schemes" / f"{pack_id}.json").is_file()

for pack_id in ("chisa-pool", "cryoforge-denia"):
    wallpaper = pathlib.Path(manifest["wallpapers"][pack_id]["wallpaper"]["path"])
    thumbnail = pathlib.Path(manifest["wallpapers"][pack_id]["thumbnail"]["path"])
    assert wallpaper.is_file() and thumbnail.is_file()
    assert str(wallpaper).startswith("/nix/store/")
    assert str(thumbnail).startswith("/nix/store/")
PY

test "$(sha256 "$runtime_root/assets/chisa-pool/wallpaper.jpg")" = \
  a4dfcf92c4170405ac37102b27c606c5e9b1bb6cd77c9f04d530fa752aab604c
test "$(sha256 "$runtime_root/assets/chisa-pool/preview.jpg")" = \
  a4dfcf92c4170405ac37102b27c606c5e9b1bb6cd77c9f04d530fa752aab604c
test "$(sha256 "$runtime_root/assets/cryoforge-denia/wallpaper.jpg")" = \
  34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb

# The dedicated action is narrow and the publisher is root-only in production.
grep -Fq '<action id="org.cryoforge.theme.publish">' "$policy"
grep -Fq '<allow_active>auth_self_keep</allow_active>' "$policy"
grep -Fq 'org.freedesktop.policykit.exec.path' "$policy"
grep -Fq "$production_publisher" "$policy"
! grep -E -q 'systemd|sh -c|bash -c|command_line|allow_any>yes|allow_inactive>yes' "$policy"
grep -Fq "readonly state_root='/var/lib/cryoforge-theme'" "$production_publisher"
grep -Fq "readonly require_root='1'" "$production_publisher"
! grep -Fq 'CRYOFORGE_THEME_STATE_ROOT' "$production_publisher"
! grep -E -q 'state_root=.*(HOME|XDG_)' "$production_publisher"
! grep -Fq '${HOME' "$production_publisher"
grep -Fq "readonly state_root='/build/phase19d-public-state'" "$publisher"
grep -Fq "readonly require_root='0'" "$publisher"
! grep -Fq 'CRYOFORGE_THEME_STATE_ROOT' "$publisher"
! grep -E -q 'state_root=.*(HOME|XDG_)' "$publisher"
! grep -Fq '${HOME' "$publisher"

# The production invoker must use the privileged NixOS wrapper explicitly.
grep -Fq 'exec /run/wrappers/bin/pkexec --disable-internal-agent' \
  "$production_publisher_invoker"
test "$(grep -Fc '/run/wrappers/bin/pkexec' "$production_publisher_invoker")" = 1
! grep -E -q '(^|[[:space:]])pkexec([[:space:]]|$)' \
  "$production_publisher_invoker"
! grep -Fq '2>/dev/null' \
  "$production_publisher_invoker"

# Publisher refusal stderr remains bounded and reaches the UI collector.
publication_block=$(sed -n \
  '/phase19d_publication_output=/,/phase19d_committed_generation=/p' \
  "$helper")
! printf '%s\n' "$publication_block" | grep -Fq '2>/dev/null'
grep -Fq 'stderr: StdioCollector' "$installed_gallery"
grep -Fq 'applyError.text.trim()' "$installed_gallery"
grep -Fq 'detail.replace(/^cryoforge-theme-error:\s*/, "")' \
  "$installed_gallery"

rm -rf "$public_root"
fallback=$(resolve_json)
test "$(printf '%s' "$fallback" | json_field source)" = fallback
test "$(printf '%s' "$fallback" | json_field packId)" = chisa-pool
test "$(printf '%s' "$fallback" | json_field wallpaperPackId)" = chisa-pool
test "$(printf '%s' "$fallback" | json_field generation)" = 0

mkdir -m 0755 "$public_root"
chisa_publish=$("$publisher" chisa-pool chisa-pool 0)
test "$(printf '%s' "$chisa_publish" | json_field generation)" = 1
test "$(resolve_field source)" = public
test "$(resolve_field packId)" = chisa-pool
test "$(resolve_field wallpaperPackId)" = chisa-pool
test "$(stat -c '%a' "$public_root")" = 755
test "$(stat -c '%a' "$public_root/active.json")" = 644
test "$(stat -c '%a' "$public_root/.publish.lock")" = 600
test "$(wc -l < "$public_root/active.json")" -eq 1
test "$(tail -c 1 "$public_root/active.json" | od -An -tuC)" = "  10"

before=$(public_fingerprint)
if "$publisher" chisa-pool chisa-pool 0 >/dev/null 2>&1; then
  exit 1
fi
test "$(public_fingerprint)" = "$before"

neutral_publish=$("$publisher" neutral chisa-pool 1)
test "$(printf '%s' "$neutral_publish" | json_field generation)" = 2
test "$(resolve_field packId)" = neutral
test "$(resolve_field wallpaperPackId)" = chisa-pool

denia_publish=$("$publisher" cryoforge-denia cryoforge-denia 2)
test "$(printf '%s' "$denia_publish" | json_field generation)" = 3
test "$(resolve_field packId)" = cryoforge-denia
test "$(resolve_field wallpaperPackId)" = cryoforge-denia

for args in \
  "unsupported cryoforge-denia 3" \
  "../neutral cryoforge-denia 3" \
  "neutral ../cryoforge-denia 3" \
  "neutral neutral 3" \
  "neutral cryoforge-denia -1" \
  "neutral cryoforge-denia 01" \
  "neutral cryoforge-denia 3 extra"; do
  before=$(public_fingerprint)
  if "$publisher" $args >/dev/null 2>&1; then
    exit 1
  fi
  test "$(public_fingerprint)" = "$before"
done

valid_state=$(cat "$public_root/active.json")
printf '%s\n' \
  '{"schemaVersion":1,"packId":"cryoforge-denia","packId":"chisa-pool","wallpaperPackId":"chisa-pool","generation":4}' \
  > "$public_root/active.json"
chmod 0644 "$public_root/active.json"
test "$(resolve_field packId)" = chisa-pool
printf '%s\n' \
  '{"schemaVersion":1,"packId":"unknown","wallpaperPackId":"chisa-pool","generation":4}' \
  > "$public_root/active.json"
test "$(resolve_field packId)" = chisa-pool
printf '%0600d\n' 0 > "$public_root/active.json"
test "$(resolve_field packId)" = chisa-pool
printf '%s\n' "$valid_state" > "$public_root/active.json"
chmod 0600 "$public_root/active.json"
test "$(resolve_field packId)" = chisa-pool
chmod 0644 "$public_root/active.json"
test "$(resolve_field packId)" = cryoforge-denia

mv "$public_root/active.json" "$public_root/active.valid"
ln -s active.valid "$public_root/active.json"
test "$(resolve_field packId)" = chisa-pool
if "$publisher" chisa-pool chisa-pool 3 >/dev/null 2>&1; then
  exit 1
fi
rm "$public_root/active.json"
mv "$public_root/active.valid" "$public_root/active.json"

touch "$public_root/.active.json.tmp.injected"
if "$publisher" chisa-pool chisa-pool 3 >/dev/null 2>&1; then
  exit 1
fi
rm "$public_root/.active.json.tmp.injected"

mv "$public_root/.publish.lock" "$public_root/.publish.lock.real"
ln -s .publish.lock.real "$public_root/.publish.lock"
if "$publisher" chisa-pool chisa-pool 3 >/dev/null 2>&1; then
  exit 1
fi
rm "$public_root/.publish.lock"
mv "$public_root/.publish.lock.real" "$public_root/.publish.lock"

# Serialize writers by holding the exact publisher lock.
lock_ready="$TMPDIR/lock-ready"
lock_release="$TMPDIR/lock-release"
"$python" - "$public_root/.publish.lock" "$lock_ready" "$lock_release" <<'PY' &
import fcntl
import os
import pathlib
import sys
import time

descriptor = os.open(sys.argv[1], os.O_RDWR)
fcntl.flock(descriptor, fcntl.LOCK_EX)
pathlib.Path(sys.argv[2]).touch()
while not pathlib.Path(sys.argv[3]).exists():
    time.sleep(0.01)
os.close(descriptor)
PY
lock_holder=$!
while [ ! -e "$lock_ready" ]; do sleep 0.01; done
"$publisher" chisa-pool chisa-pool 3 > "$TMPDIR/locked-publish.out" &
blocked_publisher=$!
sleep 0.1
kill -0 "$blocked_publisher"
touch "$lock_release"
wait "$lock_holder"
wait "$blocked_publisher"
test "$(resolve_field generation)" = 4
test "$(resolve_field packId)" = chisa-pool

# Repeated publication is always observed as complete JSON.
reader_stop="$TMPDIR/reader-stop"
"$python" - "$public_root/active.json" "$reader_stop" <<'PY' &
import json
import pathlib
import sys
import time

path = pathlib.Path(sys.argv[1])
stop = pathlib.Path(sys.argv[2])
while not stop.exists():
    raw = path.read_bytes()
    assert raw.endswith(b"\n") and b"\n" not in raw[:-1]
    value = json.loads(raw)
    assert set(value) == {
        "schemaVersion", "packId", "wallpaperPackId", "generation",
    }
    time.sleep(0.001)
PY
reader_pid=$!
generation=4
for index in $(seq 1 20); do
  if [ $((index % 2)) -eq 0 ]; then
    "$publisher" chisa-pool chisa-pool "$generation" >/dev/null
  else
    "$publisher" neutral chisa-pool "$generation" >/dev/null
  fi
  generation=$((generation + 1))
done
touch "$reader_stop"
wait "$reader_pid"
test "$(resolve_field generation)" = "$generation"

# A separate build-time helper with a deliberately wrong Denia hash proves
# hash-invalid public state falls back to immutable Chisa.
tampered_manifest="$TMPDIR/tampered-manifest.json"
"$python" - "$manifest" "$tampered_manifest" <<'PY'
import json
import pathlib
import sys

value = json.loads(pathlib.Path(sys.argv[1]).read_text())
value["wallpapers"]["cryoforge-denia"]["wallpaper"]["sha256"] = "0" * 64
pathlib.Path(sys.argv[2]).write_text(
    json.dumps(value, separators=(",", ":")) + "\n"
)
PY
tampered_resolver="$TMPDIR/resolve-tampered"
sed \
  -e "s|@STATE_ROOT@|$public_root|g" \
  -e "s|@MANIFEST@|$tampered_manifest|g" \
  -e "s|@EXPECTED_UID@|-1|g" \
  -e "s|@PYTHON@|$python|g" \
  "$repo_root/desktop/themes/resolve-active-theme.sh" \
  > "$tampered_resolver"
chmod 0555 "$tampered_resolver"
"$publisher" cryoforge-denia cryoforge-denia "$generation" >/dev/null
generation=$((generation + 1))
test "$("$BASH" "$tampered_resolver" | json_field packId)" = chisa-pool
test "$("$BASH" "$tampered_resolver" | json_field source)" = fallback

tampered_publisher="$TMPDIR/publish-tampered"
sed \
  -e "s|@STATE_ROOT@|$public_root|g" \
  -e "s|@MANIFEST@|$tampered_manifest|g" \
  -e "s|@REQUIRE_ROOT@|0|g" \
  -e "s|@EXPECTED_UID@|-1|g" \
  -e "s|@PYTHON@|$python|g" \
  "$repo_root/desktop/themes/publish-active-theme.sh" \
  > "$tampered_publisher"
chmod 0555 "$tampered_publisher"
before=$(public_fingerprint)
if "$BASH" "$tampered_publisher" cryoforge-denia cryoforge-denia "$generation" \
  >/dev/null 2>&1; then
  exit 1
fi
test "$(public_fingerprint)" = "$before"

# Restore a valid canonical Chisa identity for transaction tests.
"$publisher" chisa-pool chisa-pool "$generation" >/dev/null
generation=$((generation + 1))

session_root="$TMPDIR/session"
mkdir -p "$session_root/home"
run_helper() {
  env \
    HOME="$session_root/home" \
    XDG_STATE_HOME="$session_root/state" \
    XDG_DATA_HOME="$session_root/data" \
    "$helper" "$@"
}

make_helper_with_resolver() {
  local custom_resolver=$1
  local output=$2

  sed "s|$helper_resolver|$custom_resolver|g" "$helper" > "$output"
  chmod 0555 "$output"
}

make_helper_with_invoker() {
  local custom_invoker=$1
  local output=$2

  sed "s|$helper_invoker|$custom_invoker|g" "$helper" > "$output"
  chmod 0555 "$output"
}

make_mutating_resolver() {
  local mode=$1
  local output=$2

  "$python" - "$output" "$BASH" "$resolver" "$python" "$mode" <<'PY'
import pathlib
import shlex
import sys

output, bash, resolver, python, mode = sys.argv[1:]
program = r'''
import json
import sys

value = json.load(sys.stdin)
mode = sys.argv[1]
if value["source"] == "public" and value["packId"] == "cryoforge-denia":
    if mode == "pack":
        value["packId"] = "neutral"
    elif mode == "generation":
        value["generation"] += 1
    else:
        raise SystemExit(1)
print(json.dumps(value, ensure_ascii=True, separators=(",", ":")))
'''
pathlib.Path(output).write_text(
    f"#!{bash}\n"
    "set -euo pipefail\n"
    f"{shlex.quote(resolver)} | "
    f"{shlex.quote(python)} -c {shlex.quote(program)} {shlex.quote(mode)}\n"
)
PY
  chmod 0555 "$output"
}

helper_resolver=$(sed -n 's/^readonly phase19d_resolver=//p' "$helper")
test "$(grep -Fc "$helper_resolver" "$helper")" -eq 1
helper_invoker=$(sed -n 's/^readonly phase19d_publisher_invoker=//p' "$helper")
test "$(grep -Fc "$helper_invoker" "$helper")" -eq 1
helper_chisa_scheme=$(sed -n 's/^readonly phase19d_chisa_scheme=//p' "$helper")
helper_neutral_scheme=$(sed -n 's/^readonly phase19d_neutral_scheme=//p' "$helper")
helper_denia_scheme=$(sed -n 's/^readonly phase19d_denia_scheme=//p' "$helper")
for scheme_path in \
  "$helper_chisa_scheme" \
  "$helper_neutral_scheme" \
  "$helper_denia_scheme"; do
  test -f "$scheme_path"
  test ! -L "$scheme_path"
  case "$scheme_path" in
    /nix/store/*) ;;
    *) exit 1 ;;
  esac
done

run_helper --reconcile > "$TMPDIR/reconcile-chisa.out"
test "$(cat "$session_root/state/caelestia/wallpaper/path.txt")" = \
  "$theme_packs/share/cryoforge/theme-packs/assets/chisa-pool/wallpaper.jpg"
test "$(readlink "$session_root/state/caelestia/wallpaper/current")" = \
  "$theme_packs/share/cryoforge/theme-packs/assets/chisa-pool/wallpaper.jpg"
grep -Fq '"flavour":"chisa-pool"' "$session_root/state/caelestia/scheme.json"

# A publisher refusal keeps its bounded stderr, the coordinator's refusal
# category, and the failed transaction status.
refusing_invoker="$TMPDIR/refusing-theme-publisher"
"$python" - "$refusing_invoker" "$BASH" <<'PY'
import pathlib
import sys

path, bash = sys.argv[1:]
pathlib.Path(path).write_text(
    f"#!{bash}\n"
    "set -euo pipefail\n"
    "printf '%s\\n' '{\"ok\":false,\"error\":\"unsupported-composition\"}' >&2\n"
    "exit 1\n"
)
PY
chmod 0555 "$refusing_invoker"
refusing_helper="$TMPDIR/apply-refusing-publisher"
make_helper_with_invoker "$refusing_invoker" "$refusing_helper"
refusal_public_before=$(public_fingerprint)
refusal_session_before=$(tree_fingerprint "$session_root")
refusal_status=0
env \
  HOME="$session_root/home" \
  XDG_STATE_HOME="$session_root/state" \
  XDG_DATA_HOME="$session_root/data" \
  "$BASH" "$refusing_helper" cryoforge-denia \
  > "$TMPDIR/refusal.stdout" \
  2> "$TMPDIR/refusal.stderr" || refusal_status=$?
test "$refusal_status" -ne 0
test ! -s "$TMPDIR/refusal.stdout"
test "$(wc -c < "$TMPDIR/refusal.stderr")" -le 512
grep -Fq '{"ok":false,"error":"unsupported-composition"}' \
  "$TMPDIR/refusal.stderr"
grep -Fq 'cryoforge-theme-error: canonical publication was refused' \
  "$TMPDIR/refusal.stderr"
test "$(public_fingerprint)" = "$refusal_public_before"
test "$(tree_fingerprint "$session_root")" = "$refusal_session_before"

run_helper cryoforge-denia > "$TMPDIR/apply-denia.out"
generation=$((generation + 1))
test "$(resolve_field generation)" = "$generation"
test "$(resolve_field packId)" = cryoforge-denia
test "$(resolve_field wallpaperPackId)" = cryoforge-denia
grep -Fq '"flavour":"cryoforge-denia"' "$session_root/state/caelestia/scheme.json"
test "$(cat "$session_root/state/caelestia/wallpaper/path.txt")" = \
  "$theme_packs/share/cryoforge/theme-packs/assets/cryoforge-denia/wallpaper.jpg"
resolved_denia_scheme=$(resolve_field schemePath)
test "$resolved_denia_scheme" != "$helper_denia_scheme"
test "$(sha256 "$resolved_denia_scheme")" = "$(sha256 "$helper_denia_scheme")"

run_helper neutral > "$TMPDIR/apply-neutral.out"
generation=$((generation + 1))
test "$(resolve_field packId)" = neutral
test "$(resolve_field wallpaperPackId)" = cryoforge-denia
grep -Fq '"flavour":"neutral"' "$session_root/state/caelestia/scheme.json"
test "$(cat "$session_root/state/caelestia/wallpaper/path.txt")" = \
  "$theme_packs/share/cryoforge/theme-packs/assets/cryoforge-denia/wallpaper.jpg"
resolved_neutral_scheme=$(resolve_field schemePath)
test "$resolved_neutral_scheme" != "$helper_neutral_scheme"
test "$(sha256 "$resolved_neutral_scheme")" = "$(sha256 "$helper_neutral_scheme")"

run_helper chisa-pool > "$TMPDIR/apply-chisa.out"
generation=$((generation + 1))
test "$(resolve_field generation)" = "$generation"
test "$(resolve_field packId)" = chisa-pool
test "$(resolve_field wallpaperPackId)" = chisa-pool
grep -Fq '"flavour":"chisa-pool"' "$session_root/state/caelestia/scheme.json"
resolved_chisa_scheme=$(resolve_field schemePath)
test "$resolved_chisa_scheme" != "$helper_chisa_scheme"
test "$(sha256 "$resolved_chisa_scheme")" = "$(sha256 "$helper_chisa_scheme")"

# A resolver projection with an immutable but unapproved Denia scheme hash is
# rejected after publication, compensated to Chisa, and rolled back locally.
tampered_scheme_manifest="$TMPDIR/tampered-scheme-manifest.json"
"$python" - "$manifest" "$tampered_scheme_manifest" <<'PY'
import json
import pathlib
import sys

value = json.loads(pathlib.Path(sys.argv[1]).read_text())
value["packs"]["cryoforge-denia"]["scheme"] = dict(
    value["packs"]["chisa-pool"]["scheme"]
)
pathlib.Path(sys.argv[2]).write_text(
    json.dumps(value, separators=(",", ":")) + "\n"
)
PY
expected_tampered_scheme_path=$(
  "$python" -c '
import json
import pathlib
import sys

value = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(value["packs"]["chisa-pool"]["scheme"]["path"])
' "$manifest"
)
expected_tampered_scheme_sha256=$(
  "$python" -c '
import json
import pathlib
import sys

value = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(value["packs"]["chisa-pool"]["scheme"]["sha256"])
' "$manifest"
)
tampered_scheme_resolver_source="$TMPDIR/resolve-tampered-scheme-source"
sed \
  -e "s|@STATE_ROOT@|$public_root|g" \
  -e "s|@MANIFEST@|$tampered_scheme_manifest|g" \
  -e "s|@EXPECTED_UID@|-1|g" \
  -e "s|@PYTHON@|$python|g" \
  "$repo_root/desktop/themes/resolve-active-theme.sh" \
  > "$tampered_scheme_resolver_source"
tampered_scheme_resolver="$TMPDIR/resolve-tampered-scheme"
"$python" - \
  "$tampered_scheme_resolver" \
  "$BASH" \
  "$tampered_scheme_resolver_source" <<'PY'
import pathlib
import shlex
import sys

output, bash, source = sys.argv[1:]
pathlib.Path(output).write_text(
    f"#!{bash}\n"
    "set -euo pipefail\n"
    f"exec {shlex.quote(bash)} {shlex.quote(source)}\n"
)
PY
chmod 0555 "$tampered_scheme_resolver"
tampered_scheme_helper="$TMPDIR/apply-tampered-scheme"
make_helper_with_resolver \
  "$tampered_scheme_resolver" \
  "$tampered_scheme_helper"
session_before=$(tree_fingerprint "$session_root")
tampered_scheme_release="$TMPDIR/tampered-scheme-release"
env \
  HOME="$session_root/home" \
  XDG_STATE_HOME="$session_root/state" \
  XDG_DATA_HOME="$session_root/data" \
  CRYOFORGE_THEME_TEST_PAUSE_STEP=after-publication \
  CRYOFORGE_THEME_TEST_RELEASE_FILE="$tampered_scheme_release" \
  "$BASH" "$tampered_scheme_helper" cryoforge-denia \
  > "$TMPDIR/tampered-scheme.stdout" \
  2> "$TMPDIR/tampered-scheme.stderr" &
tampered_scheme_pid=$!
wait_for_identity cryoforge-denia
generation=$((generation + 1))
test "$("$BASH" "$tampered_scheme_resolver_source" | json_field schemePath)" = \
  "$expected_tampered_scheme_path"
test "$("$BASH" "$tampered_scheme_resolver_source" | json_field schemeSha256)" = \
  "$expected_tampered_scheme_sha256"
test "$("$BASH" "$tampered_scheme_resolver_source" | json_field schemeSha256)" != \
  "$(sha256 "$helper_denia_scheme")"
touch "$tampered_scheme_release"
if wait "$tampered_scheme_pid"; then
  exit 1
fi
generation=$((generation + 1))
test "$(resolve_field packId)" = chisa-pool
test "$(resolve_field wallpaperPackId)" = chisa-pool
test "$(resolve_field generation)" = "$generation"
test "$(tree_fingerprint "$session_root")" = "$session_before"
! grep -Fq 'reconciliation required' "$TMPDIR/tampered-scheme.stderr"

# Canonical pack and generation mismatches remain post-commit failures with
# successful compensation and session rollback.
for mismatch in pack generation; do
  mismatch_resolver="$TMPDIR/resolve-mismatch-$mismatch"
  mismatch_helper="$TMPDIR/apply-mismatch-$mismatch"
  mismatch_release="$TMPDIR/mismatch-$mismatch-release"
  make_mutating_resolver "$mismatch" "$mismatch_resolver"
  make_helper_with_resolver "$mismatch_resolver" "$mismatch_helper"
  session_before=$(tree_fingerprint "$session_root")
  env \
    HOME="$session_root/home" \
    XDG_STATE_HOME="$session_root/state" \
    XDG_DATA_HOME="$session_root/data" \
    CRYOFORGE_THEME_TEST_PAUSE_STEP=after-publication \
    CRYOFORGE_THEME_TEST_RELEASE_FILE="$mismatch_release" \
    "$BASH" "$mismatch_helper" cryoforge-denia \
    > "$TMPDIR/mismatch-$mismatch.stdout" \
    2> "$TMPDIR/mismatch-$mismatch.stderr" &
  mismatch_pid=$!
  wait_for_identity cryoforge-denia
  generation=$((generation + 1))
  mismatch_json=$("$mismatch_resolver")
  if [ "$mismatch" = pack ]; then
    test "$(printf '%s' "$mismatch_json" | json_field packId)" = neutral
    test "$(printf '%s' "$mismatch_json" | json_field generation)" = "$generation"
  else
    test "$(printf '%s' "$mismatch_json" | json_field packId)" = cryoforge-denia
    test "$(printf '%s' "$mismatch_json" | json_field generation)" = \
      "$((generation + 1))"
  fi
  touch "$mismatch_release"
  if wait "$mismatch_pid"; then
    exit 1
  fi
  generation=$((generation + 1))
  test "$(resolve_field packId)" = chisa-pool
  test "$(resolve_field wallpaperPackId)" = chisa-pool
  test "$(resolve_field generation)" = "$generation"
  test "$(tree_fingerprint "$session_root")" = "$session_before"
  ! grep -Fq 'reconciliation required' "$TMPDIR/mismatch-$mismatch.stderr"
done

# Pre-publication failure leaves canonical and session state byte-identical.
public_before=$(public_fingerprint)
session_before=$(tree_fingerprint "$session_root")
if env \
  HOME="$session_root/home" \
  XDG_STATE_HOME="$session_root/state" \
  XDG_DATA_HOME="$session_root/data" \
  CRYOFORGE_THEME_TEST_FAIL_STEP=after-stage \
  "$helper" cryoforge-denia >/dev/null 2>&1; then
  exit 1
fi
test "$(public_fingerprint)" = "$public_before"
test "$(tree_fingerprint "$session_root")" = "$session_before"

# A concurrent publisher makes the coordinator's expected generation stale.
stale_release="$TMPDIR/stale-release"
env \
  HOME="$session_root/home" \
  XDG_STATE_HOME="$session_root/state" \
  XDG_DATA_HOME="$session_root/data" \
  CRYOFORGE_THEME_TEST_PAUSE_STEP=before-publication \
  CRYOFORGE_THEME_TEST_RELEASE_FILE="$stale_release" \
  "$helper" cryoforge-denia \
  > "$TMPDIR/stale.stdout" \
  2> "$TMPDIR/stale.stderr" &
stale_pid=$!
while [ ! -d "$session_root/state/caelestia/.cryoforge-theme-apply.lock" ]; do
  sleep 0.01
done
sleep 0.1
"$publisher" neutral chisa-pool "$generation" >/dev/null
generation=$((generation + 1))
touch "$stale_release"
if wait "$stale_pid"; then
  exit 1
fi
test "$(resolve_field packId)" = neutral
test "$(resolve_field generation)" = "$generation"
test "$(tree_fingerprint "$session_root")" = "$session_before"

# A post-commit promotion failure compensates to the prior identity without
# overwriting a newer generation.
session_before=$(tree_fingerprint "$session_root")
if env \
  HOME="$session_root/home" \
  XDG_STATE_HOME="$session_root/state" \
  XDG_DATA_HOME="$session_root/data" \
  CRYOFORGE_THEME_TEST_FAIL_STEP=after-scheme-promotion \
  "$helper" cryoforge-denia >/dev/null 2>&1; then
  exit 1
fi
generation=$((generation + 2))
test "$(resolve_field packId)" = neutral
test "$(resolve_field wallpaperPackId)" = chisa-pool
test "$(resolve_field generation)" = "$generation"
test "$(tree_fingerprint "$session_root")" = "$session_before"

# If a newer writer wins before compensation, compensation fails closed and
# the coordinator reports reconciliation-required.
compensation_release="$TMPDIR/compensation-release"
env \
  HOME="$session_root/home" \
  XDG_STATE_HOME="$session_root/state" \
  XDG_DATA_HOME="$session_root/data" \
  CRYOFORGE_THEME_TEST_FAIL_STEP=after-publication \
  CRYOFORGE_THEME_TEST_PAUSE_STEP=before-compensation \
  CRYOFORGE_THEME_TEST_RELEASE_FILE="$compensation_release" \
  "$helper" cryoforge-denia \
  > "$TMPDIR/compensation.stdout" \
  2> "$TMPDIR/compensation.stderr" &
compensation_pid=$!
wait_for_identity cryoforge-denia
generation=$((generation + 1))
"$publisher" chisa-pool chisa-pool "$generation" >/dev/null
generation=$((generation + 1))
touch "$compensation_release"
if wait "$compensation_pid"; then
  exit 1
fi
grep -Fq 'reconciliation required' "$TMPDIR/compensation.stderr"
grep -Fq 'canonical=chisa-pool/chisa-pool generation=' \
  "$TMPDIR/compensation.stderr"
test "$(resolve_field packId)" = chisa-pool
test "$(resolve_field generation)" = "$generation"
test "$(tree_fingerprint "$session_root")" = "$session_before"

# Interruption after the public commit leaves that commit authoritative and
# the next reconciliation reconstructs the session from it.
interrupt_release="$TMPDIR/interrupt-release"
env \
  HOME="$session_root/home" \
  XDG_STATE_HOME="$session_root/state" \
  XDG_DATA_HOME="$session_root/data" \
  CRYOFORGE_THEME_TEST_PAUSE_STEP=after-publication \
  CRYOFORGE_THEME_TEST_RELEASE_FILE="$interrupt_release" \
  "$helper" cryoforge-denia \
  > "$TMPDIR/interruption.stdout" \
  2> "$TMPDIR/interruption.stderr" &
interrupt_pid=$!
wait_for_identity cryoforge-denia
generation=$((generation + 1))
kill -TERM "$interrupt_pid"
if wait "$interrupt_pid"; then
  exit 1
fi
test "$(resolve_field packId)" = cryoforge-denia
test "$(resolve_field generation)" = "$generation"
test "$(tree_fingerprint "$session_root")" = "$session_before"

# A subsequent normal Apply derives Neutral's preserved wallpaper from the
# canonical Denia identity, not from the stale pre-interruption session.
run_helper neutral > "$TMPDIR/apply-after-interruption.out"
generation=$((generation + 1))
test "$(resolve_field packId)" = neutral
test "$(resolve_field wallpaperPackId)" = cryoforge-denia
test "$(resolve_field generation)" = "$generation"
grep -Fq '"flavour":"neutral"' "$session_root/state/caelestia/scheme.json"
test "$(cat "$session_root/state/caelestia/wallpaper/path.txt")" = \
  "$theme_packs/share/cryoforge/theme-packs/assets/cryoforge-denia/wallpaper.jpg"

# A later interrupted Chisa Apply is likewise repaired by login reconciliation.
session_before=$(tree_fingerprint "$session_root")
login_interrupt_release="$TMPDIR/login-interrupt-release"
env \
  HOME="$session_root/home" \
  XDG_STATE_HOME="$session_root/state" \
  XDG_DATA_HOME="$session_root/data" \
  CRYOFORGE_THEME_TEST_PAUSE_STEP=after-publication \
  CRYOFORGE_THEME_TEST_RELEASE_FILE="$login_interrupt_release" \
  "$helper" chisa-pool \
  > "$TMPDIR/login-interruption.stdout" \
  2> "$TMPDIR/login-interruption.stderr" &
login_interrupt_pid=$!
wait_for_identity chisa-pool
generation=$((generation + 1))
kill -TERM "$login_interrupt_pid"
if wait "$login_interrupt_pid"; then
  exit 1
fi
test "$(tree_fingerprint "$session_root")" = "$session_before"
run_helper --reconcile > "$TMPDIR/reconcile-chisa.out"
grep -Fq '"flavour":"chisa-pool"' "$session_root/state/caelestia/scheme.json"
test "$(cat "$session_root/state/caelestia/wallpaper/path.txt")" = \
  "$theme_packs/share/cryoforge/theme-packs/assets/chisa-pool/wallpaper.jpg"

# Focused rollback fixtures use the generated Phase 19D helper and its
# isolated XDG paths, while keeping the public CAS state on Chisa.
set_public_chisa() {
  local current_generation

  current_generation=$(resolve_field generation)
  "$publisher" chisa-pool chisa-pool "$current_generation" >/dev/null
}

prepare_rollback_root() {
  local root=$1

  mkdir -p "$root/home"
  env \
    HOME="$root/home" \
    XDG_STATE_HOME="$root/state" \
    XDG_DATA_HOME="$root/data" \
    "$helper" --reconcile >/dev/null
}

start_projection_reader() {
  local root=$1
  local stop=$2
  local error=$3

  "$python" - \
    "$root/state/caelestia/scheme.json" \
    "$root/state/caelestia/wallpaper/current" \
    "$stop" \
    "$error" <<'PY' &
import os
import pathlib
import sys
import time

scheme, current, stop, error = map(pathlib.Path, sys.argv[1:])
while not stop.exists():
    try:
        if not scheme.is_file() or scheme.is_symlink():
            raise AssertionError("scheme.json was unavailable or changed type")
        if not current.is_symlink():
            raise AssertionError("final wallpaper projection was unavailable")
        target = pathlib.Path(os.readlink(current))
        if not target.exists():
            raise AssertionError("final wallpaper target was unavailable")
    except (AssertionError, OSError) as exc:
        error.write_text(str(exc))
        break
    time.sleep(0.0005)
PY
}

wait_for_pause_ready() {
  local pid=$1
  local ready=$2

  while [[ ! -e "$ready" ]]; do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 1
    fi
    sleep 0.01
  done
}

# Regular-file rollback restores exact bytes, type, and mode.
set_public_chisa
exact_root="$TMPDIR/rollback-exact"
prepare_rollback_root "$exact_root"
chmod 0640 "$exact_root/state/caelestia/scheme.json"
chmod 0644 "$exact_root/state/caelestia/wallpaper/path.txt"
exact_before=$(tree_fingerprint "$exact_root")
exact_scheme_sha256=$(sha256 "$exact_root/state/caelestia/scheme.json")
exact_scheme_mode=$(stat -c '%a' "$exact_root/state/caelestia/scheme.json")
exact_path_sha256=$(sha256 "$exact_root/state/caelestia/wallpaper/path.txt")
exact_path_mode=$(stat -c '%a' "$exact_root/state/caelestia/wallpaper/path.txt")
exact_link_target=$(readlink "$exact_root/state/caelestia/wallpaper/current")
exact_status=0
env \
  HOME="$exact_root/home" \
  XDG_STATE_HOME="$exact_root/state" \
  XDG_DATA_HOME="$exact_root/data" \
  CRYOFORGE_THEME_TEST_FAIL_STEP=after-verification \
  "$helper" cryoforge-denia >/dev/null 2> "$TMPDIR/rollback-exact.stderr" \
  || exact_status=$?
test "$exact_status" -ne 0
test "$(tree_fingerprint "$exact_root")" = "$exact_before"
test "$(sha256 "$exact_root/state/caelestia/scheme.json")" = \
  "$exact_scheme_sha256"
test "$(stat -c '%a' "$exact_root/state/caelestia/scheme.json")" = \
  "$exact_scheme_mode"
test -f "$exact_root/state/caelestia/scheme.json"
test ! -L "$exact_root/state/caelestia/scheme.json"
test "$(sha256 "$exact_root/state/caelestia/wallpaper/path.txt")" = \
  "$exact_path_sha256"
test "$(stat -c '%a' "$exact_root/state/caelestia/wallpaper/path.txt")" = \
  "$exact_path_mode"
test -f "$exact_root/state/caelestia/wallpaper/path.txt"
test ! -L "$exact_root/state/caelestia/wallpaper/path.txt"
test -L "$exact_root/state/caelestia/wallpaper/current"
test "$(readlink "$exact_root/state/caelestia/wallpaper/current")" = \
  "$exact_link_target"

# A concurrent reader never observes a missing regular projection.
set_public_chisa
file_reader_root="$TMPDIR/rollback-file-reader"
prepare_rollback_root "$file_reader_root"
file_reader_stop="$TMPDIR/rollback-file-reader-stop"
file_reader_error="$TMPDIR/rollback-file-reader-error"
start_projection_reader \
  "$file_reader_root" "$file_reader_stop" "$file_reader_error"
file_reader_pid=$!
file_release="$TMPDIR/rollback-file-release"
file_ready="$TMPDIR/rollback-file-ready"
env \
  HOME="$file_reader_root/home" \
  XDG_STATE_HOME="$file_reader_root/state" \
  XDG_DATA_HOME="$file_reader_root/data" \
  CRYOFORGE_THEME_TEST_FAIL_STEP=after-verification \
  CRYOFORGE_THEME_TEST_PAUSE_STEP=rollback-before-file-replace-scheme.json \
  CRYOFORGE_THEME_TEST_RELEASE_FILE="$file_release" \
  CRYOFORGE_THEME_TEST_READY_FILE="$file_ready" \
  "$helper" cryoforge-denia \
  > "$TMPDIR/rollback-file.stdout" \
  2> "$TMPDIR/rollback-file.stderr" &
file_helper_pid=$!
wait_for_pause_ready "$file_helper_pid" "$file_ready"
test -f "$file_reader_root/state/caelestia/scheme.json"
test -L "$file_reader_root/state/caelestia/wallpaper/current"
touch "$file_release"
file_helper_status=0
wait "$file_helper_pid" || file_helper_status=$?
test "$file_helper_status" -ne 0
touch "$file_reader_stop"
wait "$file_reader_pid"
test ! -e "$file_reader_error"

# A concurrent reader never observes a missing final symlink projection.
set_public_chisa
link_reader_root="$TMPDIR/rollback-link-reader"
prepare_rollback_root "$link_reader_root"
link_reader_stop="$TMPDIR/rollback-link-reader-stop"
link_reader_error="$TMPDIR/rollback-link-reader-error"
start_projection_reader \
  "$link_reader_root" "$link_reader_stop" "$link_reader_error"
link_reader_pid=$!
link_release="$TMPDIR/rollback-link-release"
link_ready="$TMPDIR/rollback-link-ready"
env \
  HOME="$link_reader_root/home" \
  XDG_STATE_HOME="$link_reader_root/state" \
  XDG_DATA_HOME="$link_reader_root/data" \
  CRYOFORGE_THEME_TEST_FAIL_STEP=after-verification \
  CRYOFORGE_THEME_TEST_PAUSE_STEP=rollback-before-link-replace-current \
  CRYOFORGE_THEME_TEST_RELEASE_FILE="$link_release" \
  CRYOFORGE_THEME_TEST_READY_FILE="$link_ready" \
  "$helper" cryoforge-denia \
  > "$TMPDIR/rollback-link.stdout" \
  2> "$TMPDIR/rollback-link.stderr" &
link_helper_pid=$!
wait_for_pause_ready "$link_helper_pid" "$link_ready"
test -L "$link_reader_root/state/caelestia/wallpaper/current"
touch "$link_release"
link_helper_status=0
wait "$link_helper_pid" || link_helper_status=$?
test "$link_helper_status" -ne 0
touch "$link_reader_stop"
wait "$link_reader_pid"
test ! -e "$link_reader_error"

# Rollback refuses an unexpected destination type rather than overwriting it.
set_public_chisa
destination_root="$TMPDIR/rollback-unexpected-destination"
prepare_rollback_root "$destination_root"
destination_release="$TMPDIR/rollback-destination-release"
destination_ready="$TMPDIR/rollback-destination-ready"
env \
  HOME="$destination_root/home" \
  XDG_STATE_HOME="$destination_root/state" \
  XDG_DATA_HOME="$destination_root/data" \
  CRYOFORGE_THEME_TEST_FAIL_STEP=after-verification \
  CRYOFORGE_THEME_TEST_PAUSE_STEP=rollback-before-file-replace-scheme.json \
  CRYOFORGE_THEME_TEST_RELEASE_FILE="$destination_release" \
  CRYOFORGE_THEME_TEST_READY_FILE="$destination_ready" \
  "$helper" cryoforge-denia \
  > "$TMPDIR/rollback-destination.stdout" \
  2> "$TMPDIR/rollback-destination.stderr" &
destination_helper_pid=$!
wait_for_pause_ready "$destination_helper_pid" "$destination_ready"
rm "$destination_root/state/caelestia/scheme.json"
mkdir "$destination_root/state/caelestia/scheme.json"
printf '%s\n' destination-sentinel \
  > "$destination_root/state/caelestia/scheme.json/sentinel"
touch "$destination_release"
destination_status=0
wait "$destination_helper_pid" || destination_status=$?
test "$destination_status" -ne 0
test -d "$destination_root/state/caelestia/scheme.json"
test "$(cat "$destination_root/state/caelestia/scheme.json/sentinel")" = \
  destination-sentinel

# Corrupted same-directory snapshots are rejected without restoring bad bytes.
set_public_chisa
corrupt_root="$TMPDIR/rollback-corrupt-snapshot"
prepare_rollback_root "$corrupt_root"
corrupt_scheme_before=$(sha256 "$corrupt_root/state/caelestia/scheme.json")
corrupt_release="$TMPDIR/rollback-corrupt-release"
corrupt_ready="$TMPDIR/rollback-corrupt-ready"
env \
  HOME="$corrupt_root/home" \
  XDG_STATE_HOME="$corrupt_root/state" \
  XDG_DATA_HOME="$corrupt_root/data" \
  CRYOFORGE_THEME_TEST_FAIL_STEP=after-stage \
  CRYOFORGE_THEME_TEST_PAUSE_STEP=after-stage \
  CRYOFORGE_THEME_TEST_RELEASE_FILE="$corrupt_release" \
  CRYOFORGE_THEME_TEST_READY_FILE="$corrupt_ready" \
  "$helper" cryoforge-denia \
  > "$TMPDIR/rollback-corrupt.stdout" \
  2> "$TMPDIR/rollback-corrupt.stderr" &
corrupt_helper_pid=$!
wait_for_pause_ready "$corrupt_helper_pid" "$corrupt_ready"
corrupt_snapshot=$(find "$corrupt_root/state" -type f \
  -name '.scheme.json.cryoforge-backup.*' -print)
test "$(printf '%s\n' "$corrupt_snapshot" | wc -l)" = 1
printf '%s\n' corrupted-snapshot > "$corrupt_snapshot"
touch "$corrupt_release"
corrupt_status=0
wait "$corrupt_helper_pid" || corrupt_status=$?
test "$corrupt_status" -ne 0
test "$(sha256 "$corrupt_root/state/caelestia/scheme.json")" = \
  "$corrupt_scheme_before"
test -f "$corrupt_root/state/caelestia/scheme.json"
test ! -L "$corrupt_root/state/caelestia/scheme.json"

# Unsafe parent components fail closed before any rollback can escape them.
unsafe_parent_root="$TMPDIR/rollback-unsafe-parent"
unsafe_parent_outside="$TMPDIR/rollback-unsafe-parent-outside"
mkdir -p "$unsafe_parent_root/home" "$unsafe_parent_root/data" \
  "$unsafe_parent_outside"
printf '%s\n' untouched > "$unsafe_parent_outside/sentinel"
ln -s "$unsafe_parent_outside" "$unsafe_parent_root/state"
unsafe_parent_status=0
env \
  HOME="$unsafe_parent_root/home" \
  XDG_STATE_HOME="$unsafe_parent_root/state" \
  XDG_DATA_HOME="$unsafe_parent_root/data" \
  "$helper" --reconcile >/dev/null 2> "$TMPDIR/rollback-unsafe-parent.stderr" \
  || unsafe_parent_status=$?
test "$unsafe_parent_status" -ne 0
test "$(cat "$unsafe_parent_outside/sentinel")" = untouched
test "$(find "$unsafe_parent_outside" -mindepth 1 -print)" = \
  "$unsafe_parent_outside/sentinel"

# Preview and navigation lifecycle remains publication-free.
grep -Fq 'function cancelPreview(): void' "$installed_gallery"
grep -Fq 'Component.onDestruction: cancelPreview()' "$installed_gallery"
grep -Fq 'Keys.onEscapePressed' "$installed_gallery"
grep -Fq 'function closeWithoutApplying(): void' "$installed_gallery"
grep -Fq 'onClicked: root.closeWithoutApplying()' "$installed_gallery"
test "$(grep -c '@THEME_APPLY_HELPER@' "$repo_root/desktop/caelestia/nexus/ThemePackGallery.qml")" -eq 1
grep -Fq 'applyProcess.exec(["'"$production_helper"'", selectedPack.id]);' "$installed_gallery"

# The normal real greeter resolves before QML, projects only immutable assets
# into private runtime state, and carries no session-lock or PAM backend.
grep -Fq "$production_resolver" \
  "$greeter_package/bin/.caelestia-real-greeter-qml-wrapped"
grep -Fq '@RESOLVER@' "$repo_root/desktop/caelestia/real-greeter/launch-runtime.sh"
grep -Fq 'source: Wallpapers.current' "$greeter_root/real-greeter/GreeterContent.qml"
grep -Fq 'import qs.utils' "$greeter_root/services/Wallpapers.qml"
grep -Fq 'Paths.state}/wallpaper/current' "$greeter_root/services/Wallpapers.qml"
! grep -R -q '/home/accelra' "$greeter_root" --include='*.qml' --include='*.sh'
! grep -R -q -E 'WlSessionLock|Quickshell.Services.Pam' \
  "$greeter_root" --include='*.qml'
grep -R -q 'Quickshell.Services.Greetd' "$greeter_root" --include='*.qml'
! grep -R -q -E 'curl|wget|https?://|/home/|XDG_DATA_HOME.*accelra' \
  "$greeter_root" --include='*.qml' --include='*.sh'
grep -Fq 'caelestia-real-greeter-recovery-launcher' "$greetd_command"
grep -Fq 'Restart=always' "$greetd_unit"
grep -Fq 'StandardOutput=journal' "$greetd_unit"
grep -Fq 'StandardError=journal' "$greetd_unit"

# The live session lock implementation remains untouched and separately
# packaged, while the committed Phase 19C projection remains authoritative.
test "$(sha256 "$repo_root/packages/caelestia-real-lock.nix")" = \
  3c723b62e24a4f3b119ddfc3fe4e3ab50ba9771bb6007e0118bdab3b250d1175
test "$(sha256 "$repo_root/tests/phase13c/test_real_lock_contract.sh")" = \
  c98cfbaf54467346d744151ba6a974b12afa34089dddd3dcc9c4319128382927
test "$(cat "$boundary_evidence")" = \
  "Phase 19D current systems use canonical public identity; historical checks use committed f874758"

# Helpers have bounded machine output, no numbered PTY access, and no ANSI or
# other terminal-control bytes.
trace_root="$TMPDIR/traces"
mkdir "$trace_root"
strace -f -qq -e trace=open,openat,openat2,write \
  -o "$trace_root/resolver.trace" \
  "$resolver" \
  > "$trace_root/resolver.stdout" \
  2> "$trace_root/resolver.stderr"
current_generation=$(resolve_field generation)
strace -f -qq -e trace=open,openat,openat2,write \
  -o "$trace_root/publisher.trace" \
  "$publisher" neutral cryoforge-denia "$current_generation" \
  > "$trace_root/publisher.stdout" \
  2> "$trace_root/publisher.stderr"
assert_clean_output \
  "$trace_root/resolver.stdout" \
  "$trace_root/resolver.stderr" \
  "$trace_root/publisher.stdout" \
  "$trace_root/publisher.stderr"
! grep -R -E -q '/dev/pts/[0-9]+' "$trace_root"

test -z "$(find "$public_root" -name '.active.json.tmp.*' -print)"
test -z "$(find "$session_root" \
  \( -name '*.cryoforge-stage.*' -o -name '*.cryoforge-backup.*' \) \
  -print)"
test ! -e "$session_root/state/caelestia/.cryoforge-theme-apply.lock"

printf '%s\n' \
  "phase19d registry/schema/assets: pass" \
  "phase19d publisher CAS/locking/atomicity: pass" \
  "phase19d production invoker and bounded refusal stderr: pass" \
  "phase19d resolver fallback/hash validation: pass" \
  "phase19d independent scheme projections and mismatch rejection: pass" \
  "phase19d transaction rollback/compensation/interruption: pass" \
  "phase19d atomic rollback availability/type/validation: pass" \
  "phase19d Chisa/Neutral/Denia reconstruction: pass" \
  "phase19d preview/cancel/escape/back isolation: pass" \
  "phase19d greeter and historical boundaries: pass" \
  "phase19d numbered PTY/control output: none"
