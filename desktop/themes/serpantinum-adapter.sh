#!/usr/bin/env bash

set -euo pipefail

readonly python='@PYTHON@'

if [[ $# -ne 0 ]]; then
  printf '{"ok":false,"error":"usage"}\n' >&2
  exit 1
fi

exec "$python" - <<'PY'
import hashlib
import json
import os
import pathlib
import re
import stat
import subprocess
import sys

RESOLVER = @RESOLVER@
ALLOWED_COMPOSITIONS = @ALLOWED_COMPOSITIONS@

MAX_RESOLVER_BYTES = 8 * 1024
MAX_SCHEME_BYTES = 64 * 1024
MAX_OUTPUT_BYTES = 4 * 1024
MAX_GENERATION = 9_007_199_254_740_991
RESOLVER_KEYS = {
    "schemaVersion",
    "packId",
    "wallpaperPackId",
    "generation",
    "source",
    "schemePath",
    "schemeSha256",
    "wallpaperPath",
    "wallpaperSha256",
    "thumbnailPath",
    "thumbnailSha256",
}
SCHEME_KEYS = {"name", "flavour", "cryoforge", "mode", "variant", "colours"}
CRYOFORGE_KEYS = {"schemaVersion", "packId"}
HEX = re.compile(r"^[0-9a-f]{6}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
SCHEME_COLOUR_KEYS = {
    "background",
    "error",
    "errorContainer",
    "inverseOnSurface",
    "inversePrimary",
    "inverseSurface",
    "neutral_paletteKeyColor",
    "neutral_variant_paletteKeyColor",
    "onBackground",
    "onError",
    "onErrorContainer",
    "onPrimary",
    "onPrimaryContainer",
    "onPrimaryFixed",
    "onPrimaryFixedVariant",
    "onSecondary",
    "onSecondaryContainer",
    "onSecondaryFixed",
    "onSecondaryFixedVariant",
    "onSuccess",
    "onSuccessContainer",
    "onSurface",
    "onSurfaceVariant",
    "onTertiary",
    "onTertiaryContainer",
    "onTertiaryFixed",
    "onTertiaryFixedVariant",
    "outline",
    "outlineVariant",
    "primary",
    "primaryContainer",
    "primaryFixed",
    "primaryFixedDim",
    "primary_paletteKeyColor",
    "scrim",
    "secondary",
    "secondaryContainer",
    "secondaryFixed",
    "secondaryFixedDim",
    "secondary_paletteKeyColor",
    "shadow",
    "success",
    "successContainer",
    "surface",
    "surfaceBright",
    "surfaceContainer",
    "surfaceContainerHigh",
    "surfaceContainerHighest",
    "surfaceContainerLow",
    "surfaceContainerLowest",
    "surfaceDim",
    "surfaceTint",
    "surfaceVariant",
    "term0",
    "term1",
    "term10",
    "term11",
    "term12",
    "term13",
    "term14",
    "term15",
    "term2",
    "term3",
    "term4",
    "term5",
    "term6",
    "term7",
    "term8",
    "term9",
    "tertiary",
    "tertiaryContainer",
    "tertiaryFixed",
    "tertiaryFixedDim",
    "tertiary_paletteKeyColor",
}
COLOUR_MAP = {
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


class AdapterError(Exception):
    pass


def pairs_without_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise AdapterError("duplicate-key")
        result[key] = value
    return result


def reject_constant(value):
    raise AdapterError("non-standard-json")


def parse_json(raw, error_code):
    try:
        return json.loads(
            raw,
            object_pairs_hook=pairs_without_duplicates,
            parse_constant=reject_constant,
        )
    except AdapterError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise AdapterError(error_code) from error


def validate_hash(value, field):
    if not isinstance(value, str) or SHA256.fullmatch(value) is None:
        raise AdapterError(f"invalid-{field}")


def validate_store_path(value, field):
    if not isinstance(value, str) or not value.startswith("/nix/store/"):
        raise AdapterError(f"invalid-{field}")
    if any(ord(char) < 32 for char in value):
        raise AdapterError(f"invalid-{field}")
    components = value.split("/")[3:]
    if not components or any(component in {"", ".", ".."} for component in components):
        raise AdapterError(f"invalid-{field}")

    current = pathlib.Path("/")
    for component in value.split("/")[1:]:
        current /= component
        try:
            info = os.lstat(current)
        except OSError as error:
            raise AdapterError(f"unavailable-{field}") from error
        if stat.S_ISLNK(info.st_mode):
            raise AdapterError(f"symlink-{field}")


def open_immutable_store_file(path, field):
    validate_store_path(path, field)
    try:
        info = os.lstat(path)
    except OSError as error:
        raise AdapterError(f"unavailable-{field}") from error
    if not stat.S_ISREG(info.st_mode) or stat.S_IMODE(info.st_mode) & 0o222:
        raise AdapterError(f"non-immutable-{field}")

    flags = os.O_RDONLY | os.O_CLOEXEC | getattr(os, "O_NOFOLLOW", 0)
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        raise AdapterError(f"unavailable-{field}") from error
    try:
        opened = os.fstat(descriptor)
        if (
            opened.st_dev != info.st_dev
            or opened.st_ino != info.st_ino
            or opened.st_size != info.st_size
            or opened.st_mode != info.st_mode
            or opened.st_nlink != info.st_nlink
        ):
            raise AdapterError(f"{field}-race")
        return descriptor, info
    except BaseException:
        os.close(descriptor)
        raise


def verify_and_read(path, expected_hash, field, maximum):
    validate_hash(expected_hash, f"{field}-sha256")
    descriptor, info = open_immutable_store_file(path, field)
    digest = hashlib.sha256()
    content = bytearray()
    try:
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            if len(content) + len(chunk) > maximum:
                raise AdapterError(f"{field}-too-large")
            content.extend(chunk)
            digest.update(chunk)
    except OSError as error:
        raise AdapterError(f"unreadable-{field}") from error
    finally:
        os.close(descriptor)
    if digest.hexdigest() != expected_hash:
        raise AdapterError(f"{field}-hash-mismatch")
    if len(content) != info.st_size:
        raise AdapterError(f"{field}-race")
    return bytes(content)


def verify_hash(path, expected_hash, field):
    validate_hash(expected_hash, f"{field}-sha256")
    descriptor, info = open_immutable_store_file(path, field)
    digest = hashlib.sha256()
    read_size = 0
    try:
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            read_size += len(chunk)
            digest.update(chunk)
    except OSError as error:
        raise AdapterError(f"unreadable-{field}") from error
    finally:
        os.close(descriptor)
    if digest.hexdigest() != expected_hash:
        raise AdapterError(f"{field}-hash-mismatch")
    if read_size != info.st_size:
        raise AdapterError(f"{field}-race")


def validate_resolver(value):
    if not isinstance(value, dict) or set(value) != RESOLVER_KEYS:
        raise AdapterError("malformed-resolver")
    if (
        not isinstance(value["schemaVersion"], int)
        or isinstance(value["schemaVersion"], bool)
        or value["schemaVersion"] != 1
    ):
        raise AdapterError("unsupported-resolver")

    pack_id = value["packId"]
    wallpaper_pack_id = value["wallpaperPackId"]
    if not isinstance(pack_id, str) or SLUG.fullmatch(pack_id) is None:
        raise AdapterError("invalid-pack-id")
    if not isinstance(wallpaper_pack_id, str) or SLUG.fullmatch(wallpaper_pack_id) is None:
        raise AdapterError("invalid-wallpaper-pack-id")
    if pack_id not in ALLOWED_COMPOSITIONS:
        raise AdapterError("unknown-pack-id")
    if wallpaper_pack_id not in ALLOWED_COMPOSITIONS[pack_id]:
        raise AdapterError("unsupported-wallpaper-pack-id")

    generation = value["generation"]
    if (
        not isinstance(generation, int)
        or isinstance(generation, bool)
        or generation < 0
        or generation > MAX_GENERATION
    ):
        raise AdapterError("invalid-generation")
    if value["source"] not in {"fallback", "public"}:
        raise AdapterError("invalid-source")
    if value["source"] == "fallback" and generation != 0:
        raise AdapterError("invalid-fallback-generation")
    if value["source"] == "public" and generation < 1:
        raise AdapterError("invalid-public-generation")

    for field in ("schemePath", "wallpaperPath", "thumbnailPath"):
        validate_store_path(value[field], field)
    for field in ("schemeSha256", "wallpaperSha256", "thumbnailSha256"):
        validate_hash(value[field], field)


def validate_scheme(scheme, pack_id):
    if not isinstance(scheme, dict) or set(scheme) != SCHEME_KEYS:
        raise AdapterError("malformed-scheme")
    if (
        scheme["name"] != "cryoforge-pack"
        or scheme["flavour"] != pack_id
        or scheme["mode"] != "dark"
        or scheme["variant"] != "tonalspot"
    ):
        raise AdapterError("unsupported-scheme")
    cryoforge = scheme["cryoforge"]
    if (
        not isinstance(cryoforge, dict)
        or set(cryoforge) != CRYOFORGE_KEYS
        or not isinstance(cryoforge["schemaVersion"], int)
        or isinstance(cryoforge["schemaVersion"], bool)
        or cryoforge["schemaVersion"] != 1
        or cryoforge["packId"] != pack_id
    ):
        raise AdapterError("invalid-scheme-identity")
    colours = scheme["colours"]
    if (
        not isinstance(colours, dict)
        or set(colours) != SCHEME_COLOUR_KEYS
        or any(not isinstance(value, str) or HEX.fullmatch(value) is None for value in colours.values())
    ):
        raise AdapterError("invalid-scheme-colours")


def resolver_output():
    try:
        process = subprocess.Popen(
            [RESOLVER],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
    except OSError as error:
        raise AdapterError("resolver-unavailable") from error

    try:
        raw = process.stdout.read(MAX_RESOLVER_BYTES + 1)
        if len(raw) > MAX_RESOLVER_BYTES:
            process.kill()
            process.wait()
            raise AdapterError("resolver-output-too-large")
        return_code = process.wait()
    except OSError as error:
        process.kill()
        process.wait()
        raise AdapterError("resolver-failed") from error
    finally:
        process.stdout.close()
    if return_code != 0:
        raise AdapterError("resolver-failed")
    return raw


def convert_colours(colours):
    return {
        target: f"#{colours[source]}"
        for target, source in COLOUR_MAP.items()
    }


def main():
    resolver = parse_json(resolver_output(), "malformed-resolver")
    validate_resolver(resolver)

    scheme_raw = verify_and_read(
        resolver["schemePath"],
        resolver["schemeSha256"],
        "scheme",
        MAX_SCHEME_BYTES,
    )
    verify_hash(
        resolver["wallpaperPath"],
        resolver["wallpaperSha256"],
        "wallpaper",
    )
    scheme = parse_json(scheme_raw, "malformed-scheme")
    validate_scheme(scheme, resolver["packId"])

    result = {
        "packId": resolver["packId"],
        "wallpaperPackId": resolver["wallpaperPackId"],
        "generation": resolver["generation"],
        "wallpaperPath": resolver["wallpaperPath"],
        "wallpaperSha256": resolver["wallpaperSha256"],
        "colors": convert_colours(scheme["colours"]),
    }
    raw = json.dumps(result, ensure_ascii=True, separators=(",", ":"))
    if len(raw.encode("ascii")) > MAX_OUTPUT_BYTES or any(
        ord(char) < 32 for char in raw
    ):
        raise AdapterError("output-invalid")
    print(raw)


try:
    main()
except AdapterError as error:
    print(
        json.dumps(
            {"ok": False, "error": str(error)},
            ensure_ascii=True,
            separators=(",", ":"),
        ),
        file=sys.stderr,
    )
    raise SystemExit(1)
except (KeyError, OSError, TypeError, ValueError):
    print('{"ok":false,"error":"internal-error"}', file=sys.stderr)
    raise SystemExit(1)
PY
