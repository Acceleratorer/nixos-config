#!/usr/bin/env bash

set -euo pipefail

readonly state_root='@STATE_ROOT@'
readonly manifest='@MANIFEST@'
readonly expected_uid='@EXPECTED_UID@'
readonly python='@PYTHON@'

if [[ $# -ne 0 ]]; then
  printf '{"ok":false,"error":"usage"}\n' >&2
  exit 1
fi

unset HOME XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME
export PYTHONDONTWRITEBYTECODE=1
export PYTHONNOUSERSITE=1

exec "$python" - \
  "$state_root" \
  "$manifest" \
  "$expected_uid" <<'PY'
import hashlib
import json
import os
import pathlib
import re
import stat
import sys

MAX_STATE_BYTES = 512
MAX_OUTPUT_BYTES = 2048
MAX_GENERATION = 9_007_199_254_740_991
PUBLIC_KEYS = {"schemaVersion", "packId", "wallpaperPackId", "generation"}
SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class InvalidPublicState(Exception):
    pass


class FatalResolverError(Exception):
    pass


def pairs_without_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise InvalidPublicState("duplicate-key")
        result[key] = value
    return result


def no_symlink_components(path, error_type):
    current = pathlib.Path("/")
    for component in pathlib.Path(path).parts[1:]:
        current /= component
        try:
            info = os.lstat(current)
        except FileNotFoundError as error:
            raise error_type("missing-component") from error
        if stat.S_ISLNK(info.st_mode):
            raise error_type("symlink-component")


def validate_asset(asset):
    path = asset["path"]
    expected_hash = asset["sha256"]
    if (
        not isinstance(path, str)
        or not path.startswith("/nix/store/")
        or not re.fullmatch(r"[0-9a-f]{64}", expected_hash)
    ):
        raise FatalResolverError("invalid-manifest")
    no_symlink_components(path, FatalResolverError)
    info = os.lstat(path)
    if not stat.S_ISREG(info.st_mode) or info.st_size < 1:
        raise FatalResolverError("invalid-asset")
    digest = hashlib.sha256()
    flags = os.O_RDONLY | os.O_CLOEXEC | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags)
    try:
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    finally:
        os.close(descriptor)
    if digest.hexdigest() != expected_hash:
        raise FatalResolverError("asset-hash-mismatch")


def read_public_state(path, expected_owner):
    info = os.lstat(path)
    if (
        not stat.S_ISREG(info.st_mode)
        or info.st_uid != expected_owner
        or stat.S_IMODE(info.st_mode) != 0o644
        or info.st_nlink != 1
        or info.st_size < 1
        or info.st_size > MAX_STATE_BYTES
    ):
        raise InvalidPublicState("unsafe-state-file")
    flags = os.O_RDONLY | os.O_CLOEXEC | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags)
    try:
        opened = os.fstat(descriptor)
        if (
            opened.st_dev != info.st_dev
            or opened.st_ino != info.st_ino
            or opened.st_size != info.st_size
        ):
            raise InvalidPublicState("state-race")
        raw = os.read(descriptor, MAX_STATE_BYTES + 1)
        if len(raw) != info.st_size:
            raise InvalidPublicState("state-race")
    finally:
        os.close(descriptor)
    try:
        return json.loads(raw, object_pairs_hook=pairs_without_duplicates)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise InvalidPublicState("malformed-state") from error


def validate_identity(value, manifest_data):
    if (
        not isinstance(value, dict)
        or set(value) != PUBLIC_KEYS
        or value["schemaVersion"] != 1
        or not isinstance(value["packId"], str)
        or not isinstance(value["wallpaperPackId"], str)
        or not SLUG.fullmatch(value["packId"])
        or not SLUG.fullmatch(value["wallpaperPackId"])
        or not isinstance(value["generation"], int)
        or isinstance(value["generation"], bool)
        or value["generation"] < 1
        or value["generation"] > MAX_GENERATION
    ):
        raise InvalidPublicState("malformed-state")
    pack = manifest_data["packs"].get(value["packId"])
    if (
        pack is None
        or value["wallpaperPackId"] not in pack["allowedWallpaperPackIds"]
        or value["wallpaperPackId"] not in manifest_data["wallpapers"]
    ):
        raise InvalidPublicState("unsupported-state")
    return value


def resolution(identity, source, manifest_data):
    pack = manifest_data["packs"][identity["packId"]]
    wallpaper = manifest_data["wallpapers"][identity["wallpaperPackId"]]
    validate_asset(pack["scheme"])
    validate_asset(wallpaper["wallpaper"])
    validate_asset(wallpaper["thumbnail"])
    return {
        "schemaVersion": 1,
        "packId": identity["packId"],
        "wallpaperPackId": identity["wallpaperPackId"],
        "generation": identity["generation"],
        "source": source,
        "schemePath": pack["scheme"]["path"],
        "schemeSha256": pack["scheme"]["sha256"],
        "wallpaperPath": wallpaper["wallpaper"]["path"],
        "wallpaperSha256": wallpaper["wallpaper"]["sha256"],
        "thumbnailPath": wallpaper["thumbnail"]["path"],
        "thumbnailSha256": wallpaper["thumbnail"]["sha256"],
    }


try:
    state_root, manifest_path, expected_uid_raw = sys.argv[1:]
    expected_owner = os.geteuid() if expected_uid_raw == "-1" else int(expected_uid_raw)
    manifest_bytes = pathlib.Path(manifest_path).read_bytes()
    try:
        manifest_data = json.loads(
            manifest_bytes,
            object_pairs_hook=pairs_without_duplicates,
        )
    except InvalidPublicState as error:
        raise FatalResolverError("invalid-manifest") from error
    if (
        set(manifest_data) != {"schemaVersion", "packs", "wallpapers"}
        or manifest_data["schemaVersion"] != 1
        or not isinstance(manifest_data["packs"], dict)
        or not isinstance(manifest_data["wallpapers"], dict)
        or "chisa-pool" not in manifest_data["packs"]
        or "chisa-pool" not in manifest_data["wallpapers"]
    ):
        raise FatalResolverError("invalid-manifest")

    fallback = {
        "schemaVersion": 1,
        "packId": "chisa-pool",
        "wallpaperPackId": "chisa-pool",
        "generation": 0,
    }
    selected = fallback
    source = "fallback"
    try:
        no_symlink_components(state_root, InvalidPublicState)
        directory_info = os.lstat(state_root)
        if (
            not stat.S_ISDIR(directory_info.st_mode)
            or directory_info.st_uid != expected_owner
            or stat.S_IMODE(directory_info.st_mode) != 0o755
        ):
            raise InvalidPublicState("unsafe-state-directory")
        state_path = os.path.join(state_root, "active.json")
        if os.path.lexists(state_path):
            selected = validate_identity(
                read_public_state(state_path, expected_owner),
                manifest_data,
            )
            source = "public"
    except (FileNotFoundError, InvalidPublicState):
        selected = fallback
        source = "fallback"

    try:
        result = resolution(selected, source, manifest_data)
    except FatalResolverError:
        if source == "fallback":
            raise
        result = resolution(fallback, "fallback", manifest_data)

    raw = json.dumps(result, ensure_ascii=True, separators=(",", ":"))
    if len(raw.encode("ascii")) > MAX_OUTPUT_BYTES or any(
        ord(char) < 32 for char in raw
    ):
        raise FatalResolverError("output-invalid")
    print(raw)
except FatalResolverError as error:
    raw = json.dumps(
        {"ok": False, "error": str(error)},
        ensure_ascii=True,
        separators=(",", ":"),
    )
    print(raw, file=sys.stderr)
    raise SystemExit(1)
except BaseException:
    print('{"ok":false,"error":"internal-error"}', file=sys.stderr)
    raise SystemExit(1)
PY
