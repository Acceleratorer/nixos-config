#!/usr/bin/env bash

set -euo pipefail

readonly state_root='@STATE_ROOT@'
readonly manifest='@MANIFEST@'
readonly require_root='@REQUIRE_ROOT@'
readonly expected_uid='@EXPECTED_UID@'
readonly python='@PYTHON@'

fail() {
  printf '{"ok":false,"error":"%s"}\n' "$1" >&2
  exit 1
}

[[ $# -eq 3 ]] || fail "usage"
readonly pack_id=$1
readonly wallpaper_pack_id=$2
readonly expected_generation=$3

[[ "$pack_id" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "invalid-pack-id"
[[ "$wallpaper_pack_id" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "invalid-wallpaper-pack-id"
[[ "$expected_generation" =~ ^(0|[1-9][0-9]{0,15})$ ]] || fail "invalid-generation"

if [[ "$require_root" == 1 && $EUID -ne 0 ]]; then
  fail "root-required"
fi

unset HOME XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME
export PYTHONDONTWRITEBYTECODE=1
export PYTHONNOUSERSITE=1
umask 077

exec "$python" - \
  "$state_root" \
  "$manifest" \
  "$expected_uid" \
  "$pack_id" \
  "$wallpaper_pack_id" \
  "$expected_generation" <<'PY'
import fcntl
import hashlib
import json
import os
import pathlib
import re
import stat
import sys

MAX_STATE_BYTES = 512
MAX_GENERATION = 9_007_199_254_740_991
PUBLIC_KEYS = {"schemaVersion", "packId", "wallpaperPackId", "generation"}
SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class Refusal(Exception):
    pass


def refuse(code):
    raise Refusal(code)


def emit_error(code):
    raw = json.dumps(
        {"ok": False, "error": code},
        ensure_ascii=True,
        separators=(",", ":"),
    )
    if len(raw) > 256 or any(ord(char) < 32 for char in raw):
        raw = '{"ok":false,"error":"internal-error"}'
    print(raw, file=sys.stderr)


def pairs_without_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            refuse("duplicate-key")
        result[key] = value
    return result


def read_bounded_regular(path, expected_owner, expected_mode, maximum):
    try:
        info = os.lstat(path)
    except FileNotFoundError:
        return None
    if (
        not stat.S_ISREG(info.st_mode)
        or info.st_uid != expected_owner
        or stat.S_IMODE(info.st_mode) != expected_mode
        or info.st_nlink != 1
        or info.st_size < 1
        or info.st_size > maximum
    ):
        refuse("unsafe-state-file")
    flags = os.O_RDONLY | os.O_CLOEXEC | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags)
    try:
        opened = os.fstat(descriptor)
        if (
            opened.st_dev != info.st_dev
            or opened.st_ino != info.st_ino
            or opened.st_size != info.st_size
        ):
            refuse("state-race")
        raw = os.read(descriptor, maximum + 1)
        if len(raw) != info.st_size or len(raw) > maximum:
            refuse("state-size")
        return raw
    finally:
        os.close(descriptor)


def no_symlink_components(path):
    current = pathlib.Path("/")
    for component in pathlib.Path(path).parts[1:]:
        current /= component
        try:
            info = os.lstat(current)
        except FileNotFoundError:
            refuse("missing-component")
        if stat.S_ISLNK(info.st_mode):
            refuse("symlink-component")


def validate_asset(asset):
    path = asset["path"]
    expected_hash = asset["sha256"]
    if (
        not isinstance(path, str)
        or not path.startswith("/nix/store/")
        or not re.fullmatch(r"[0-9a-f]{64}", expected_hash)
    ):
        refuse("invalid-manifest")
    no_symlink_components(path)
    info = os.lstat(path)
    if not stat.S_ISREG(info.st_mode) or info.st_size < 1:
        refuse("invalid-asset")
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
        refuse("asset-hash-mismatch")


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
        refuse("malformed-state")
    pack = manifest_data["packs"].get(value["packId"])
    if (
        pack is None
        or value["wallpaperPackId"] not in pack["allowedWallpaperPackIds"]
        or value["wallpaperPackId"] not in manifest_data["wallpapers"]
    ):
        refuse("unsupported-state")
    return value


try:
    (
        state_root,
        manifest_path,
        expected_uid_raw,
        requested_pack_id,
        requested_wallpaper_id,
        expected_generation_raw,
    ) = sys.argv[1:]
    expected_owner = os.geteuid() if expected_uid_raw == "-1" else int(expected_uid_raw)
    expected_generation = int(expected_generation_raw)
    if expected_generation > MAX_GENERATION - 1:
        refuse("generation-overflow")

    manifest_bytes = pathlib.Path(manifest_path).read_bytes()
    manifest_data = json.loads(
        manifest_bytes,
        object_pairs_hook=pairs_without_duplicates,
    )
    if (
        set(manifest_data) != {"schemaVersion", "packs", "wallpapers"}
        or manifest_data["schemaVersion"] != 1
        or not isinstance(manifest_data["packs"], dict)
        or not isinstance(manifest_data["wallpapers"], dict)
    ):
        refuse("invalid-manifest")

    requested_pack = manifest_data["packs"].get(requested_pack_id)
    if (
        requested_pack is None
        or requested_wallpaper_id not in requested_pack["allowedWallpaperPackIds"]
        or requested_wallpaper_id not in manifest_data["wallpapers"]
    ):
        refuse("unsupported-composition")

    no_symlink_components(state_root)
    directory_info = os.lstat(state_root)
    if (
        not stat.S_ISDIR(directory_info.st_mode)
        or directory_info.st_uid != expected_owner
        or stat.S_IMODE(directory_info.st_mode) != 0o755
    ):
        refuse("unsafe-state-directory")

    state_path = os.path.join(state_root, "active.json")
    lock_path = os.path.join(state_root, ".publish.lock")
    if os.path.lexists(lock_path):
        lock_info = os.lstat(lock_path)
        if (
            not stat.S_ISREG(lock_info.st_mode)
            or lock_info.st_uid != expected_owner
            or stat.S_IMODE(lock_info.st_mode) != 0o600
            or lock_info.st_nlink != 1
        ):
            refuse("unsafe-lock")

    lock_flags = (
        os.O_RDWR
        | os.O_CREAT
        | os.O_CLOEXEC
        | getattr(os, "O_NOFOLLOW", 0)
    )
    lock_descriptor = os.open(lock_path, lock_flags, 0o600)
    try:
        lock_opened = os.fstat(lock_descriptor)
        if (
            not stat.S_ISREG(lock_opened.st_mode)
            or lock_opened.st_uid != expected_owner
            or stat.S_IMODE(lock_opened.st_mode) != 0o600
            or lock_opened.st_nlink != 1
        ):
            refuse("unsafe-lock")
        fcntl.flock(lock_descriptor, fcntl.LOCK_EX)

        for entry in os.scandir(state_root):
            if entry.name.startswith(".active.json.tmp."):
                refuse("unsafe-temporary-component")

        current_raw = read_bounded_regular(
            state_path,
            expected_owner,
            0o644,
            MAX_STATE_BYTES,
        )
        if current_raw is None:
            current_generation = 0
        else:
            try:
                current_value = json.loads(
                    current_raw,
                    object_pairs_hook=pairs_without_duplicates,
                )
            except (UnicodeDecodeError, json.JSONDecodeError):
                refuse("malformed-state")
            current_generation = validate_identity(
                current_value,
                manifest_data,
            )["generation"]

        if current_generation != expected_generation:
            refuse("stale-generation")

        validate_asset(requested_pack["scheme"])
        validate_asset(manifest_data["wallpapers"][requested_wallpaper_id]["wallpaper"])
        validate_asset(manifest_data["wallpapers"][requested_wallpaper_id]["thumbnail"])

        next_generation = current_generation + 1
        public_value = {
            "schemaVersion": 1,
            "packId": requested_pack_id,
            "wallpaperPackId": requested_wallpaper_id,
            "generation": next_generation,
        }
        payload = (
            json.dumps(public_value, ensure_ascii=True, separators=(",", ":"))
            + "\n"
        ).encode("ascii")
        if len(payload) > MAX_STATE_BYTES:
            refuse("state-size")

        temporary_name = (
            f".active.json.tmp.{os.getpid()}."
            f"{os.urandom(8).hex()}"
        )
        temporary_path = os.path.join(state_root, temporary_name)
        temporary_flags = (
            os.O_WRONLY
            | os.O_CREAT
            | os.O_EXCL
            | os.O_CLOEXEC
            | getattr(os, "O_NOFOLLOW", 0)
        )
        temporary_descriptor = os.open(temporary_path, temporary_flags, 0o600)
        try:
            written = 0
            while written < len(payload):
                written += os.write(temporary_descriptor, payload[written:])
            os.fsync(temporary_descriptor)
            os.fchmod(temporary_descriptor, 0o644)
            os.fsync(temporary_descriptor)
        except BaseException:
            try:
                os.unlink(temporary_path)
            except FileNotFoundError:
                pass
            raise
        finally:
            os.close(temporary_descriptor)

        os.replace(temporary_path, state_path)
        directory_descriptor = os.open(
            state_root,
            os.O_RDONLY | os.O_CLOEXEC | getattr(os, "O_DIRECTORY", 0),
        )
        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)

        result = json.dumps(
            {
                "ok": True,
                "packId": requested_pack_id,
                "wallpaperPackId": requested_wallpaper_id,
                "generation": next_generation,
            },
            ensure_ascii=True,
            separators=(",", ":"),
        )
        if len(result) > 256 or any(ord(char) < 32 for char in result):
            refuse("internal-error")
        print(result)
    finally:
        os.close(lock_descriptor)
except Refusal as error:
    emit_error(str(error))
    raise SystemExit(1)
except BaseException:
    emit_error("internal-error")
    raise SystemExit(1)
PY
