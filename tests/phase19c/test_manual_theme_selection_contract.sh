#!/usr/bin/env bash

set -euo pipefail

repo_root=${1:?missing repository source root}
runtime_output=${2:?missing Phase 19C runtime output}
selector_shell=${3:?missing wrapped CryoForge shell output}
accepted_shell=${4:?missing accepted CryoForge shell output}
upstream_root=${5:?missing pinned Caelestia source}
historical_root=${6:?missing pre-Phase-19C source projection}
boundary_evidence=${7:?missing package and system boundary evidence}
caelestia_cli=${8:?missing guarded CryoForge CLI package}
upstream_cli=${9:?missing pinned upstream Caelestia CLI package}
cli_source=${10:?missing pinned Caelestia CLI source}
real_greeter_source=${11:?missing filtered real-greeter source boundary}
real_greeter=${12:?missing corrected real-greeter package}
real_greeter_session=${13:?missing corrected real-greeter session}
real_greetd_unit=${14:?missing corrected rendered greetd unit}
real_greeter_package_closure=${15:?missing corrected real-greeter package closure}
real_greeter_session_closure=${16:?missing corrected real-greeter session closure}
selector_quickshell=${17:?missing pinned selector Quickshell package}

runtime_root="$runtime_output/share/cryoforge/theme-runtime"
helper="$runtime_output/bin/cryoforge-apply-theme-pack"
selector_output=${selector_shell%/share/caelestia-shell}
source_page="$repo_root/desktop/caelestia/nexus/ThemePackGallery.qml"
installed_page="$selector_shell/modules/nexus/pages/wallandstyle/ThemePackGallery.qml"
selector_patch="$repo_root/desktop/caelestia/cryoforge-nexus-theme-selector.patch"
selector_package="$repo_root/packages/caelestia-cryoforge-theme-selector.nix"
runtime_package="$repo_root/packages/cryoforge-theme-runtime.nix"
scheme_adapter="$repo_root/desktop/themes/caelestia-schemes.nix"
helper_source="$repo_root/desktop/themes/apply-theme-pack.sh"
cli_scheme_source="$cli_source/src/caelestia/utils/scheme.py"
cli_scheme_command_source="$cli_source/src/caelestia/subcommands/scheme.py"
cli_wallpaper_source="$cli_source/src/caelestia/utils/wallpaper.py"
cli_site_packages=("$caelestia_cli"/lib/python*/site-packages)
test "${#cli_site_packages[@]}" -eq 1
cli_scheme_root="${cli_site_packages[0]}/caelestia/data/schemes/cryoforge-pack"
guarded_cli_scheme_source="${cli_site_packages[0]}/caelestia/utils/scheme.py"
selector_launcher="$selector_output/bin/.caelestia-shell-wrapped"
selector_qt_wrapper="$selector_output/bin/caelestia-shell"

for path in \
  "$runtime_root/registry.json" \
  "$runtime_root/schemes/neutral.json" \
  "$runtime_root/schemes/cryoforge-denia.json" \
  "$runtime_root/assets/cryoforge-denia/preview.jpg" \
  "$runtime_root/assets/cryoforge-denia/wallpaper.jpg" \
  "$helper" \
  "$source_page" \
  "$installed_page" \
  "$selector_patch" \
  "$selector_package" \
  "$runtime_package" \
  "$scheme_adapter" \
  "$helper_source" \
  "$boundary_evidence" \
  "$caelestia_cli/bin/caelestia" \
  "$upstream_cli/bin/caelestia" \
  "$cli_scheme_source" \
  "$cli_scheme_command_source" \
  "$cli_wallpaper_source" \
  "$guarded_cli_scheme_source" \
  "$cli_scheme_root/neutral/dark.txt" \
  "$cli_scheme_root/cryoforge-denia/dark.txt" \
  "$selector_launcher" \
  "$selector_qt_wrapper"; do
  test -r "$path"
done

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

state_fingerprint() {
  {
    find "$1" -type d -printf 'd %m %p\n' | sort
    find "$1" -type l -printf 'l %m %p -> %l\n' | sort
    find "$1" -type f -print0 | sort -z | while IFS= read -r -d '' path; do
      printf 'f %s %s ' "$(stat -c '%a' "$path")" "$path"
      sha256sum "$path"
    done
  } | sha256sum | cut -d ' ' -f 1
}

assert_custom_scheme() {
  python3 - "$1" "$2" "$3" <<'PY'
import json
import pathlib
import sys

scheme = json.loads(pathlib.Path(sys.argv[1]).read_text())
canonical = json.loads(pathlib.Path(sys.argv[2]).read_text())
assert scheme["name"] == "cryoforge-pack"
assert scheme["flavour"] == sys.argv[3]
assert scheme["cryoforge"] == {"schemaVersion": 1, "packId": sys.argv[3]}
assert scheme["mode"] == "dark"
assert scheme["colours"] == canonical["colours"]
PY
}

run_cli() {
  local label=$1
  shift
  set +e
  strace -f -qq \
    -e trace=open,openat,openat2,write \
    -o "$trace_root/$label.trace" \
    "$caelestia_cli/bin/caelestia" "$@" \
    > "$trace_root/$label.stdout" \
    2> "$trace_root/$label.stderr"
  local status=$?
  set -e
  printf '%s %s\n' "$label" "$status" >> "$trace_root/statuses.txt"
  return "$status"
}

allowed_paths=(
  "desktop/caelestia/cryoforge-nexus-theme-selector.patch"
  "desktop/caelestia/nexus/ThemePackGallery.qml"
  "desktop/profiles.nix"
  "desktop/themes/apply-theme-pack.sh"
  "desktop/themes/caelestia-schemes.nix"
  "flake.nix"
  "packages/caelestia-cryoforge-theme-selector.nix"
  "packages/cryoforge-theme-runtime.nix"
  "tests/phase19c/test_manual_theme_selection_contract.sh"
)

if git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
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

# The pre-login source boundary is an exact R3 projection: all required
# greeter inputs remain, while every Phase 19C dirty path is absent.
for path in "${allowed_paths[@]}"; do
  test ! -e "$real_greeter_source/$path"
done
for path in \
  packages/caelestia-chisa-pool.nix \
  packages/caelestia-real-greeter.nix \
  desktop/caelestia/real-greeter-system.nix \
  desktop/caelestia/chisa-pool/CachingImage.qml \
  desktop/caelestia/real-greeter/greeter.qml \
  desktop/caelestia/real-greeter/launch-runtime.sh \
  desktop/caelestia/real-greeter/recovery-launcher.sh \
  desktop/caelestia/real-greeter/adapters/GreetdController.qml; do
  test -r "$real_greeter_source/$path"
done
test "$(sha256 "$real_greeter_source/packages/caelestia-real-greeter.nix")" = \
  795a7009c6a8d52db1d3d1aec4c243ee6bcbac6486eb4cf2bdcccb4bad0ce17a
test "$(sha256 "$real_greeter_source/desktop/caelestia/real-greeter-system.nix")" = \
  8415f438e88ae97eb47ff916fd8c97ed15ada5131cb47b0ccd5a71a5ebb8f078

# The accepted R3 pre-login artifacts are reproduced byte-for-byte without
# embedding any accepted system, package, or session store path in source.
test "$(sha256 "$real_greeter_session")" = \
  bc652ae1eff6aabb3f8cf65301ded3f69798219cafbae15a9756004492f36cd0
test "$(sha256 "$real_greetd_unit")" = \
  ab9b677de60d60d97357609d8ca2db2797119eed58000f3aa205dbddddb9b07e
real_greetd_toml=$(
  sed -n 's|^ExecStart=.*/greetd --config ||p' "$real_greetd_unit"
)
test -r "$real_greetd_toml"
test "$(sha256 "$real_greetd_toml")" = \
  1b827f5ab3d69271a10375cbda02a4ac99bb987a4006f55ffb8c8a5997796d37
grep -Fqx 'Restart=always' "$real_greetd_unit"
! grep -Fqx 'X-RestartIfChanged=false' "$real_greetd_unit"
grep -Fqx 'X-StopIfChanged=false' "$real_greetd_unit"

phase19c_greeter_symbols='ThemePackGallery|cryoforge-nexus-theme-selector|cryoforge-theme-runtime|caelestia-cryoforge-theme-selector|cryoforge-apply-theme-pack|phase19c'
! grep -R -a -E -q \
  "$phase19c_greeter_symbols" \
  "$real_greeter" \
  "$real_greeter_session"
! grep -E -q \
  "$phase19c_greeter_symbols" \
  "$real_greeter_package_closure" \
  "$real_greeter_session_closure"
! grep -R -E -q \
  '/nix/store/[a-z0-9]{32}-(nixos-system|caelestia-real-greeter-session)' \
  "$repo_root" \
  --include='*.nix' \
  --include='*.sh'

# Historical sources and contracts are projected byte-for-byte.
test "$(sha256 "$historical_root/desktop/profiles.nix")" = \
  9de59b0dca05eb17df9b8452472b353f12ec8cdc48de1bcd93c1f1c86d1c433e
test "$(sha256 "$historical_root/flake.nix")" = \
  a99978a6c7475c4cf80c34083fd4d1a67c87f19730487b576187fe1d97e91244
test "$(sha256 "$repo_root/packages/caelestia-cryoforge.nix")" = \
  fa1e2df3757d80d5a4093c03201141a302a46cd064cf7a1f69df0dc8c317ab56
test "$(sha256 "$repo_root/tests/phase19a/test_theme_pack_foundation_contract.sh")" = \
  483b0e3bbd2aedef4622f05009b55ceb8aae74a862672d81e1231f334fc75e0f
test "$(sha256 "$repo_root/tests/phase19b/test_first_curated_theme_contract.sh")" = \
  c12174853dbd50fe40b266e201d7e3d63242980589d888f4040b7b4f243ce881
test "$(sha256 "$repo_root/flake.lock")" = \
  bbca26850cfa467fc5afc177802ae1f3bbca20827f8577e5af9285711f30ade3
test "$(sha256 "$cli_scheme_source")" = \
  ef14c44b9bea5595663e0369df5a9dc76f83bd4221cfe2b7ec2a6b07391c7555
test "$(sha256 "$cli_scheme_command_source")" = \
  2e0eb6d9b59dcbd53db01c410a78e49b2717288c697372a6976b328cb45d3b54
test "$(sha256 "$cli_wallpaper_source")" = \
  00e5ae68155d795e6eefec9a10d10272d9386e7435ecba8a40d1f80315e8eab5
test "$caelestia_cli" != "$upstream_cli"
grep -Fq \
  '{"cryoforge": {"schemaVersion": 1, "packId": self.flavour}}' \
  "$guarded_cli_scheme_source"
grep -Fq 'if self.name == "cryoforge-pack"' "$guarded_cli_scheme_source"
grep -Fq \
  'caelestia-dots/shell/817a220e8e87c4df9f3681033a0d8a8054cdaa30' \
  "$repo_root/flake.nix"
grep -Fq \
  'caelestia-dots/cli/751fbc555a83faba5dd589270d14eeb22afab174' \
  "$repo_root/flake.nix"

# Runtime JSON and packaged CLI data are exact projections of one registry.
python3 - "$runtime_root" "$cli_scheme_root" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
cli_root = pathlib.Path(sys.argv[2])
registry_raw = (root / "registry.json").read_bytes()
assert registry_raw.endswith(b"\n") and b"\n" not in registry_raw[:-1]
registry = json.loads(registry_raw)
assert [pack["id"] for pack in registry["packs"]] == [
    "neutral",
    "cryoforge-denia",
]
assert [pack["displayName"] for pack in registry["packs"]] == [
    "CryoForge Neutral",
    "CryoForge Denia",
]

required = {
    "primary_paletteKeyColor", "secondary_paletteKeyColor",
    "tertiary_paletteKeyColor", "neutral_paletteKeyColor",
    "neutral_variant_paletteKeyColor", "background", "onBackground",
    "surface", "surfaceDim", "surfaceBright", "surfaceContainerLowest",
    "surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh",
    "surfaceContainerHighest", "onSurface", "surfaceVariant",
    "onSurfaceVariant", "inverseSurface", "inverseOnSurface", "outline",
    "outlineVariant", "shadow", "scrim", "surfaceTint", "primary",
    "onPrimary", "primaryContainer", "onPrimaryContainer", "inversePrimary",
    "secondary", "onSecondary", "secondaryContainer",
    "onSecondaryContainer", "tertiary", "onTertiary",
    "tertiaryContainer", "onTertiaryContainer", "error", "onError",
    "errorContainer", "onErrorContainer", "success", "onSuccess",
    "successContainer", "onSuccessContainer", "primaryFixed",
    "primaryFixedDim", "onPrimaryFixed", "onPrimaryFixedVariant",
    "secondaryFixed", "secondaryFixedDim", "onSecondaryFixed",
    "onSecondaryFixedVariant", "tertiaryFixed", "tertiaryFixedDim",
    "onTertiaryFixed", "onTertiaryFixedVariant",
    *(f"term{index}" for index in range(16)),
}
assert len(required) == 74
runtime_schemes = {}

for pack in registry["packs"]:
    raw = (root / "schemes" / f"{pack['id']}.json").read_bytes()
    assert raw.endswith(b"\n") and b"\n" not in raw[:-1]
    scheme = json.loads(raw)
    assert set(scheme) == {
        "name", "flavour", "cryoforge", "mode", "variant", "colours",
    }
    assert scheme["name"] == "cryoforge-pack"
    assert scheme["flavour"] == pack["id"]
    assert scheme["cryoforge"] == {
        "schemaVersion": 1,
        "packId": pack["id"],
    }
    assert scheme["mode"] == "dark"
    assert scheme["variant"] == "tonalspot"
    assert set(scheme["colours"]) == required
    approved = {value.removeprefix("#") for value in pack["palette"].values()}
    assert set(scheme["colours"].values()) <= approved | {"000000"}
    runtime_schemes[pack["id"]] = scheme

assert sorted(path.name for path in cli_root.iterdir()) == [
    "cryoforge-denia",
    "neutral",
]
for pack_id, scheme in runtime_schemes.items():
    flavour_root = cli_root / pack_id
    assert [path.name for path in flavour_root.iterdir()] == ["dark.txt"]
    raw = (flavour_root / "dark.txt").read_bytes()
    assert raw.endswith(b"\n") and b"\n\n" not in raw
    lines = raw.decode().splitlines()
    assert len(lines) == 74
    cli_colours = {}
    for line in lines:
        parts = line.split(" ")
        assert len(parts) == 2
        name, colour = parts
        assert name and len(colour) == 6 and not colour.startswith("#")
        cli_colours[name] = colour
    assert cli_colours == scheme["colours"]
PY

test "$(sha256 "$runtime_root/assets/cryoforge-denia/wallpaper.jpg")" = \
  34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb
test "$(sha256 "$runtime_root/assets/cryoforge-denia/preview.jpg")" = \
  f67c58a530a4e44c491937e13e33b36aedf9e6ac8b0fca8a25ba6c6696824045
test -z "$(find "$runtime_output" -type l -print)"
test -z "$(find "$runtime_root" -type f ! -perm 0444 -print)"
test "$(stat -c '%a' "$helper")" = 555
test -z "$(find "$cli_scheme_root" -type f ! -perm 0444 -print)"

# The accepted patch order is inherited, the strict selector patch is last,
# and the route replaces Colours while preserving the separate Chisa page.
grep -Fq 'patches = (old.patches or [ ]) ++ [ themeSelectorPatch ];' \
  "$selector_package"
grep -Fq '"--fuzz=0"' "$selector_package"
grep -Fq 'caelestiaShellCryoforge.pname == "caelestia-shell-cryoforge"' \
  "$selector_package"
grep -Fq 'cryoforgeCaelestiaCli.pname == "caelestia-cli-cryoforge"' \
  "$selector_package"
grep -Fq 'dependency == upstreamCaelestiaCli' "$selector_package"
grep -Fq 'then cryoforgeCaelestiaCli' "$selector_package"
launcher_strings=$(strings "$selector_launcher")
printf '%s\n' "$launcher_strings" | grep -Fq "$caelestia_cli/bin"
! printf '%s\n' "$launcher_strings" | grep -Fq "$upstream_cli/bin"
grep -Fq 'ThemePackGallery {}' \
  "$selector_shell/modules/nexus/PageCompRegistry.qml"
grep -Fq 'ChisaPresetGallery {}' \
  "$selector_shell/modules/nexus/PageCompRegistry.qml"
grep -Fq 'text: qsTr("Theme packs")' \
  "$selector_shell/modules/nexus/pages/WallpaperAndStyle.qml"
grep -Fq 'InfoRow {' \
  "$selector_shell/modules/nexus/pages/WallpaperAndStyle.qml"
grep -Fq 'label: qsTr("Dark theme")' \
  "$selector_shell/modules/nexus/pages/WallpaperAndStyle.qml"
grep -Fq \
  'subtext: qsTr("CryoForge theme packs use curated dark-only palettes.")' \
  "$selector_shell/modules/nexus/pages/WallpaperAndStyle.qml"
grep -Fq 'value: qsTr("Always on")' \
  "$selector_shell/modules/nexus/pages/WallpaperAndStyle.qml"
! grep -Fq 'onToggled: Colours.setMode' \
  "$selector_shell/modules/nexus/pages/WallpaperAndStyle.qml"
! grep -Fq 'ThemePackGallery {}' \
  "$accepted_shell/modules/nexus/PageCompRegistry.qml"
test -r \
  "$accepted_shell/modules/nexus/pages/wallandstyle/ChisaPresetGallery.qml"

patch_root=$(mktemp -d -t phase19c-patch.XXXXXXXX)
trap 'rm -rf \
  "${patch_root:-}" \
  "${test_root:-}" \
  "${symlink_root:-}" \
  "${state_symlink_root:-}" \
  "${data_symlink_root:-}" \
  "${wallpaper_symlink_root:-}" \
  "${denia_symlink_root:-}" \
  "${mode_root:-}" \
  "${traversal_root:-}" \
  "${concurrency_root:-}" \
  "${empty_failure_root:-}" \
  "${trace_root:-}" \
  "${qml_tooling_root:-}" \
  "${qml_engine_root:-}" \
  "${diagnostics:-}"' EXIT
cp -R "$upstream_root/." "$patch_root/"
chmod -R u+w "$patch_root"
for patch_file in \
  "$repo_root/desktop/caelestia/cryoforge-special-workspaces.patch" \
  "$repo_root/desktop/caelestia/cryoforge-chisa-preset-gallery.patch" \
  "$repo_root/desktop/caelestia/cryoforge-region-screenshot.patch" \
  "$repo_root/desktop/caelestia/cryoforge-nexus-focus-hub.patch" \
  "$repo_root/desktop/caelestia/cryoforge-nexus-media-workspace.patch" \
  "$selector_patch"; do
  patch_output=$(
    patch --batch --forward --fuzz=0 --strip=1 --directory="$patch_root" \
      < "$patch_file" 2>&1
  )
  ! printf '%s\n' "$patch_output" | grep -E -i -q \
    'fuzz|failed|reversed|skipping'
done
cmp "$patch_root/modules/nexus/PageCompRegistry.qml" \
  "$selector_shell/modules/nexus/PageCompRegistry.qml"
cmp "$patch_root/modules/nexus/pages/WallpaperAndStyle.qml" \
  "$selector_shell/modules/nexus/pages/WallpaperAndStyle.qml"
cmp "$patch_root/modules/nexus/common/PageBase.qml" \
  "$selector_shell/modules/nexus/common/PageBase.qml"
cmp "$patch_root/services/Colours.qml" \
  "$selector_shell/services/Colours.qml"

# The UI is registry-driven, preview-first, keyboard-bounded, and explicit.
! grep -Fq 'CryoForge Denia' "$source_page"
! grep -E -q '"#[0-9a-fA-F]{6}"' "$source_page"
grep -Fq 'path: `${root.runtimeRoot}/registry.json`' "$source_page"
grep -Fq 'model: root.packs' "$source_page"
grep -Fq 'tile.modelData.preview.swatches' "$source_page"
grep -Fq 'tile.modelData.palette[modelData]' "$source_page"
grep -Fq 'text: qsTr("Keeps current wallpaper")' "$source_page"
grep -Fq 'text: qsTr("Cancel")' "$source_page"
grep -Fq 'text: root.applying ? qsTr("Applying…") : qsTr("Apply")' \
  "$source_page"
grep -Fq 'disabled: !root.canApply' "$source_page"
grep -Fq 'Math.max(0, Math.min(packs.length - 1' "$source_page"
grep -Fq 'case Qt.Key_Space:' "$source_page"
grep -Fq 'case Qt.Key_Return:' "$source_page"
grep -Fq 'case Qt.Key_Enter:' "$source_page"
grep -Fq 'if (canApply)' "$source_page"
grep -Fq 'border.width: selected ? (root.activeFocus ? 3 : 2) : 1' \
  "$source_page"
grep -Fq 'tile.applied ? qsTr("Applied")' "$source_page"
grep -Fq 'subPageCloseEnabled: !applying' "$source_page"
grep -Fq 'disabled: root.applying' "$source_page"
grep -Fq 'function closeWithoutApplying(): void' "$source_page"
grep -Fq 'function onSubPageClosed(): void' "$source_page"
grep -Fq 'function onCryoforgePackIdChanged(): void' "$source_page"
grep -Fq 'Colours.cryoforgePackId' "$source_page"
grep -Fq 'Colours.scheme === "cryoforge-pack"' "$source_page"
grep -Fq 'property string cryoforgePackId' \
  "$selector_shell/services/Colours.qml"
grep -Fq 'cryoforgePackId = scheme.cryoforge?.packId ?? "";' \
  "$selector_shell/services/Colours.qml"
grep -Fq 'property bool subPageCloseEnabled: true' \
  "$selector_shell/modules/nexus/common/PageBase.qml"
grep -Fq 'disabled: !root.subPageCloseEnabled' \
  "$selector_shell/modules/nexus/common/PageBase.qml"

preview_block=$(sed -n \
  '/^    function requestPreview/,/^    function applyPending/p' \
  "$source_page")
! printf '%s\n' "$preview_block" | grep -E -q \
  'applyProcess|THEME_APPLY_HELPER|exec\('
grep -Fq 'applyProcess.exec(["@THEME_APPLY_HELPER@", selectedPack.id]);' \
  "$source_page"
grep -Fq 'readonly property bool canApply:' "$source_page"
grep -Fq 'isSupportedPackId(selectedPack.id)' "$source_page"
grep -Fq 'Component.onDestruction: cancelPreview()' "$source_page"
grep -Fq 'Keys.onEscapePressed' "$source_page"
cancel_block=$(sed -n '/^    function cancelPreview/,/^    function selectIndex/p' \
  "$source_page")
printf '%s\n' "$cancel_block" | grep -Fq 'Wallpapers.stopPreview();'
printf '%s\n' "$cancel_block" | grep -Fq \
  'Wallpapers.previewColourLock = false;'
printf '%s\n' "$cancel_block" | grep -Fq 'Colours.showPreview = false;'
close_block=$(sed -n \
  '/^    function closeWithoutApplying/,/^    function selectIndex/p' \
  "$source_page")
printf '%s\n' "$close_block" | grep -Fq 'if (applying)'
printf '%s\n' "$close_block" | grep -Fq 'return;'
printf '%s\n' "$close_block" | grep -Fq 'cancelPreview();'
printf '%s\n' "$close_block" | grep -Fq 'nState.closeSubPage();'
grep -A3 -F 'function onSubPageClosed(): void' "$source_page" \
  | grep -Fq 'root.cancelPreview();'
grep -A3 -F 'Keys.onEscapePressed' "$source_page" \
  | grep -Fq 'closeWithoutApplying();'
grep -Fq 'Colours.load(data, true);' "$source_page"
grep -Fq 'Colours.showPreview = true;' "$source_page"
grep -Fq 'Wallpapers.previewColourLock = true;' "$source_page"
grep -Fq 'Wallpapers.preview(root.assetPath(pack.wallpaper));' "$source_page"
grep -Fq 'Wallpapers.stopPreview();' "$source_page"
grep -Fq 'Colours.load(root.previewSchemeData, false);' "$source_page"
grep -Fq 'if (code !== 0)' "$source_page"
grep -Fq 'root.reportApplyFailure' "$source_page"

# The one-shot helper is transactional and mutates only isolated XDG state.
test_root=$(mktemp -d -t phase19c-helper.XXXXXXXX)
trace_root=$(mktemp -d -t phase19c-cli-trace.XXXXXXXX)
umask 077
export HOME="$test_root/home"
export XDG_STATE_HOME="$test_root/state"
export XDG_DATA_HOME="$test_root/data"
export XDG_CONFIG_HOME="$test_root/config"
export XDG_CACHE_HOME="$test_root/cache"
export XDG_PICTURES_DIR="$test_root/pictures"
export CAELESTIA_WALLPAPERS_DIR="$test_root/wallpapers"
export PYTHONDONTWRITEBYTECODE=1
mkdir -p \
  "$HOME" \
  "$XDG_STATE_HOME/caelestia/wallpaper" \
  "$XDG_DATA_HOME" \
  "$XDG_CONFIG_HOME/caelestia" \
  "$XDG_CACHE_HOME" \
  "$XDG_PICTURES_DIR" \
  "$CAELESTIA_WALLPAPERS_DIR" \
  "$test_root/input"
printf '%s\n' \
  '{"theme":{"enableTerm":false,"enableHypr":false,"enableDiscord":false,"enableSpicetify":false,"enablePandora":false,"enableFuzzel":false,"enableBtop":false,"enableNvtop":false,"enableHtop":false,"enableGtk":false,"enableQt":false,"enableWarp":false,"enableChromium":false,"enableZed":false,"enableCava":false}}' \
  > "$XDG_CONFIG_HOME/caelestia/cli.json"
chmod 0600 "$XDG_CONFIG_HOME/caelestia/cli.json"
cp -p "$runtime_root/assets/cryoforge-denia/wallpaper.jpg" \
  "$test_root/input/local-test.jpg"
chmod 0600 "$test_root/input/local-test.jpg"
printf '%s\n' 'original-scheme' > "$XDG_STATE_HOME/caelestia/scheme.json"
printf '%s\n' '/original/wallpaper.jpg' \
  > "$XDG_STATE_HOME/caelestia/wallpaper/path.txt"

wallpaper_before=$(sha256 "$XDG_STATE_HOME/caelestia/wallpaper/path.txt")
test "$("$helper" neutral)" = '{"ok":true,"packId":"neutral"}'
test "$wallpaper_before" = \
  "$(sha256 "$XDG_STATE_HOME/caelestia/wallpaper/path.txt")"
grep -Fq '"name":"cryoforge-pack"' \
  "$XDG_STATE_HOME/caelestia/scheme.json"
grep -Fq '"flavour":"neutral"' \
  "$XDG_STATE_HOME/caelestia/scheme.json"
grep -Fq '"packId":"neutral"' \
  "$XDG_STATE_HOME/caelestia/scheme.json"
assert_custom_scheme \
  "$XDG_STATE_HOME/caelestia/scheme.json" \
  "$runtime_root/schemes/neutral.json" \
  neutral
neutral_before_get=$(sha256 "$XDG_STATE_HOME/caelestia/scheme.json")
run_cli neutral-get scheme get --name --flavour --mode --variant
test "$(cat "$trace_root/neutral-get.stdout")" = \
  $'cryoforge-pack\nneutral\ndark\ntonalspot'
test "$neutral_before_get" = \
  "$(sha256 "$XDG_STATE_HOME/caelestia/scheme.json")"

# The guarded CLI resolves the custom scheme and preserves its identity.
cp -p "$XDG_STATE_HOME/caelestia/scheme.json" "$test_root/neutral.before"
run_cli neutral-variant scheme set --variant content
assert_custom_scheme \
  "$XDG_STATE_HOME/caelestia/scheme.json" \
  "$runtime_root/schemes/neutral.json" \
  neutral
python3 - "$XDG_STATE_HOME/caelestia/scheme.json" <<'PY'
import json
import pathlib
import sys

assert json.loads(pathlib.Path(sys.argv[1]).read_text())["variant"] == "content"
PY

chmod 0640 "$XDG_STATE_HOME/caelestia/scheme.json"
cp -p "$XDG_STATE_HOME/caelestia/scheme.json" \
  "$test_root/neutral-rollback.before"
if CRYOFORGE_THEME_TEST_FAIL_STEP=after-scheme \
  "$helper" neutral >/dev/null 2>&1; then
  exit 1
fi
cmp "$test_root/neutral-rollback.before" \
  "$XDG_STATE_HOME/caelestia/scheme.json"
test "$(stat -c '%a' "$XDG_STATE_HOME/caelestia/scheme.json")" = 640
test "$("$helper" neutral)" = '{"ok":true,"packId":"neutral"}'

test "$("$helper" cryoforge-denia)" = \
  '{"ok":true,"packId":"cryoforge-denia"}'
denia_target="$XDG_DATA_HOME/cryoforge/theme-packs/cryoforge-denia/wallpaper.jpg"
test "$(sha256 "$denia_target")" = \
  34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb
test "$(cat "$XDG_STATE_HOME/caelestia/wallpaper/path.txt")" = \
  "$denia_target"
for file in \
  "$denia_target" \
  "$XDG_STATE_HOME/caelestia/scheme.json" \
  "$XDG_STATE_HOME/caelestia/wallpaper/path.txt"; do
  test "$(stat -c '%a' "$file")" = 600
done
grep -Fq '"name":"cryoforge-pack"' \
  "$XDG_STATE_HOME/caelestia/scheme.json"
grep -Fq '"flavour":"cryoforge-denia"' \
  "$XDG_STATE_HOME/caelestia/scheme.json"
grep -Fq '"packId":"cryoforge-denia"' \
  "$XDG_STATE_HOME/caelestia/scheme.json"
assert_custom_scheme \
  "$XDG_STATE_HOME/caelestia/scheme.json" \
  "$runtime_root/schemes/cryoforge-denia.json" \
  cryoforge-denia

run_cli list-flavours scheme list --flavours
test "$(sort "$trace_root/list-flavours.stdout")" = \
  $'cryoforge-denia\nneutral'
run_cli list-modes scheme list --modes
test "$(cat "$trace_root/list-modes.stdout")" = dark
run_cli list-variants scheme list --variants
test "$(cat "$trace_root/list-variants.stdout")" = \
  $'tonalspot\nvibrant\nexpressive\nfidelity\nfruitsalad\nmonochrome\nneutral\nrainbow\ncontent'
run_cli list-names scheme list --names
grep -Fqx 'cryoforge-pack' "$trace_root/list-names.stdout"
test "$(grep -Fxc 'cryoforge-pack' "$trace_root/list-names.stdout")" = 1

wallpaper_scheme_before=$(sha256 "$XDG_STATE_HOME/caelestia/scheme.json")
wallpaper_state_before=$(state_fingerprint "$XDG_STATE_HOME")
run_cli wallpaper-no-smart wallpaper \
  --file "$test_root/input/local-test.jpg" \
  --no-smart
test "$(cat "$XDG_STATE_HOME/caelestia/wallpaper/path.txt")" = \
  "$test_root/input/local-test.jpg"
test -L "$XDG_STATE_HOME/caelestia/wallpaper/current"
test "$(readlink "$XDG_STATE_HOME/caelestia/wallpaper/current")" = \
  "$test_root/input/local-test.jpg"
test -L "$XDG_STATE_HOME/caelestia/wallpaper/thumbnail.jpg"
assert_custom_scheme \
  "$XDG_STATE_HOME/caelestia/scheme.json" \
  "$runtime_root/schemes/cryoforge-denia.json" \
  cryoforge-denia
test "$wallpaper_scheme_before" != \
  "$(sha256 "$XDG_STATE_HOME/caelestia/scheme.json")"
test "$wallpaper_state_before" != "$(state_fingerprint "$XDG_STATE_HOME")"
run_cli denia-get scheme get --name --flavour --mode --variant
test "$(cat "$trace_root/denia-get.stdout")" = \
  $'cryoforge-pack\ncryoforge-denia\ndark\ntonalspot'

unsupported_cli_before=$(state_fingerprint "$XDG_STATE_HOME")
if run_cli set-light scheme set --mode light; then
  exit 1
fi
test "$unsupported_cli_before" = "$(state_fingerprint "$XDG_STATE_HOME")"
run_cli denia-get-after-light scheme get --name --flavour --mode --variant
test "$(cat "$trace_root/denia-get-after-light.stdout")" = \
  $'cryoforge-pack\ncryoforge-denia\ndark\ntonalspot'

run_cli set-neutral-flavour scheme set --flavour neutral
assert_custom_scheme \
  "$XDG_STATE_HOME/caelestia/scheme.json" \
  "$runtime_root/schemes/neutral.json" \
  neutral
run_cli neutral-flavour-get scheme get --name --flavour --mode
test "$(cat "$trace_root/neutral-flavour-get.stdout")" = \
  $'cryoforge-pack\nneutral\ndark'
run_cli neutral-variant scheme set --variant expressive
assert_custom_scheme \
  "$XDG_STATE_HOME/caelestia/scheme.json" \
  "$runtime_root/schemes/neutral.json" \
  neutral
python3 - "$XDG_STATE_HOME/caelestia/scheme.json" <<'PY'
import json
import pathlib
import sys

assert json.loads(pathlib.Path(sys.argv[1]).read_text())["variant"] == "expressive"
PY

run_cli built-in scheme set --name caelestia --flavour default --mode dark
python3 - \
  "$XDG_STATE_HOME/caelestia/scheme.json" \
  "${cli_site_packages[0]}/caelestia/data/schemes/caelestia/default/dark.txt" <<'PY'
import json
import pathlib
import sys

scheme = json.loads(pathlib.Path(sys.argv[1]).read_text())
expected = {}
for line in pathlib.Path(sys.argv[2]).read_text().splitlines():
    name, colour = line.split(" ")
    expected[name] = colour
assert scheme["name"] == "caelestia"
assert scheme["flavour"] == "default"
assert scheme["mode"] == "dark"
assert "cryoforge" not in scheme
assert scheme["colours"] == expected
PY
run_cli built-in-get scheme get --name --flavour --mode --variant
test "$(cat "$trace_root/built-in-get.stdout")" = \
  $'caelestia\ndefault\ndark\nexpressive'

test "$("$helper" cryoforge-denia)" = \
  '{"ok":true,"packId":"cryoforge-denia"}'
assert_custom_scheme \
  "$XDG_STATE_HOME/caelestia/scheme.json" \
  "$runtime_root/schemes/cryoforge-denia.json" \
  cryoforge-denia

unsupported_before=$(state_fingerprint "$XDG_STATE_HOME")
if "$helper" unsupported >/dev/null 2>&1; then
  exit 1
fi
test "$unsupported_before" = "$(state_fingerprint "$XDG_STATE_HOME")"

chmod 0640 "$denia_target" "$XDG_STATE_HOME/caelestia/scheme.json"
chmod 0644 "$XDG_STATE_HOME/caelestia/wallpaper/path.txt"
for failure_step in \
  after-wallpaper-copy \
  after-scheme \
  after-wallpaper-state; do
  cp -p "$denia_target" "$test_root/denia.before"
  cp -p "$XDG_STATE_HOME/caelestia/scheme.json" "$test_root/scheme.before"
  cp -p "$XDG_STATE_HOME/caelestia/wallpaper/path.txt" \
    "$test_root/wallpaper.before"
  if CRYOFORGE_THEME_TEST_FAIL_STEP="$failure_step" \
    "$helper" cryoforge-denia >/dev/null 2>&1; then
    exit 1
  fi
  cmp "$test_root/denia.before" "$denia_target"
  cmp "$test_root/scheme.before" "$XDG_STATE_HOME/caelestia/scheme.json"
  cmp "$test_root/wallpaper.before" \
    "$XDG_STATE_HOME/caelestia/wallpaper/path.txt"
  test "$(stat -c '%a' "$denia_target")" = 640
  test "$(stat -c '%a' "$XDG_STATE_HOME/caelestia/scheme.json")" = 640
  test "$(
    stat -c '%a' "$XDG_STATE_HOME/caelestia/wallpaper/path.txt"
  )" = 644
done
test -z "$(find "$test_root" -type f \
  \( -name '*.cryoforge-backup.*' -o -name '*.cryoforge-write.*' \) \
  -print)"
test ! -e "$XDG_STATE_HOME/caelestia/.cryoforge-theme-apply.lock"
test -z "$(find "$test_root" -type f -name 'theme.lock' -print)"

python3 - "$XDG_CONFIG_HOME/caelestia/cli.json" <<'PY'
import json
import pathlib
import sys

config = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert set(config) == {"theme"}
assert set(config["theme"]) == {
    "enableTerm", "enableHypr", "enableDiscord", "enableSpicetify",
    "enablePandora", "enableFuzzel", "enableBtop", "enableNvtop",
    "enableHtop", "enableGtk", "enableQt", "enableWarp",
    "enableChromium", "enableZed", "enableCava",
}
assert all(value is False for value in config["theme"].values())
PY
test ! -e "$XDG_CONFIG_HOME/caelestia/templates"

empty_failure_root=$(mktemp -d -t phase19c-empty-failure.XXXXXXXX)
export HOME="$empty_failure_root/home"
export XDG_STATE_HOME="$empty_failure_root/state"
export XDG_DATA_HOME="$empty_failure_root/data"
mkdir -p "$HOME"
if CRYOFORGE_THEME_TEST_FAIL_STEP=after-scheme \
  "$helper" neutral >/dev/null 2>&1; then
  exit 1
fi
test ! -e "$XDG_STATE_HOME"
test -z "$(find "$empty_failure_root" \
  \( -name '*.cryoforge-backup.*' -o -name '*.cryoforge-write.*' -o \
  -name '.cryoforge-theme-apply.lock' \) -print)"

concurrency_root=$(mktemp -d -t phase19c-concurrency.XXXXXXXX)
export HOME="$concurrency_root/home"
export XDG_STATE_HOME="$concurrency_root/state"
export XDG_DATA_HOME="$concurrency_root/data"
mkdir -p "$HOME" "$XDG_STATE_HOME/caelestia"
printf '%s\n' 'concurrency-sentinel' \
  > "$XDG_STATE_HOME/caelestia/scheme.json"
mkdir -m 0700 "$XDG_STATE_HOME/caelestia/.cryoforge-theme-apply.lock"
concurrency_before=$(state_fingerprint "$XDG_STATE_HOME")
if "$helper" neutral >/dev/null 2>&1; then
  exit 1
fi
test "$concurrency_before" = "$(state_fingerprint "$XDG_STATE_HOME")"
rmdir "$XDG_STATE_HOME/caelestia/.cryoforge-theme-apply.lock"

symlink_root=$(mktemp -d -t phase19c-symlink.XXXXXXXX)
export HOME="$symlink_root/home"
export XDG_STATE_HOME="$symlink_root/state"
export XDG_DATA_HOME="$symlink_root/data"
mkdir -p "$HOME" "$XDG_STATE_HOME/caelestia" "$XDG_DATA_HOME" \
  "$symlink_root/outside"
printf '%s\n' outside > "$symlink_root/outside/scheme.json"
ln -s "$symlink_root/outside/scheme.json" \
  "$XDG_STATE_HOME/caelestia/scheme.json"
if "$helper" neutral >/dev/null 2>&1; then
  exit 1
fi
test "$(cat "$symlink_root/outside/scheme.json")" = outside

state_symlink_root=$(mktemp -d -t phase19c-state-symlink.XXXXXXXX)
export HOME="$state_symlink_root/home"
export XDG_STATE_HOME="$state_symlink_root/state"
export XDG_DATA_HOME="$state_symlink_root/data"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$state_symlink_root/outside"
ln -s "$state_symlink_root/outside" "$XDG_STATE_HOME"
if "$helper" neutral >/dev/null 2>&1; then
  exit 1
fi
test -z "$(find "$state_symlink_root/outside" -mindepth 1 -print)"

data_symlink_root=$(mktemp -d -t phase19c-data-symlink.XXXXXXXX)
export HOME="$data_symlink_root/home"
export XDG_STATE_HOME="$data_symlink_root/state"
export XDG_DATA_HOME="$data_symlink_root/data"
mkdir -p "$HOME" "$XDG_STATE_HOME" "$data_symlink_root/outside"
ln -s "$data_symlink_root/outside" "$XDG_DATA_HOME"
if "$helper" cryoforge-denia >/dev/null 2>&1; then
  exit 1
fi
test -z "$(find "$data_symlink_root/outside" -mindepth 1 -print)"

wallpaper_symlink_root=$(mktemp -d -t phase19c-wallpaper-symlink.XXXXXXXX)
export HOME="$wallpaper_symlink_root/home"
export XDG_STATE_HOME="$wallpaper_symlink_root/state"
export XDG_DATA_HOME="$wallpaper_symlink_root/data"
mkdir -p "$HOME" "$XDG_STATE_HOME/caelestia/wallpaper" \
  "$XDG_DATA_HOME" "$wallpaper_symlink_root/outside"
printf '%s\n' outside > "$wallpaper_symlink_root/outside/path.txt"
ln -s "$wallpaper_symlink_root/outside/path.txt" \
  "$XDG_STATE_HOME/caelestia/wallpaper/path.txt"
if "$helper" cryoforge-denia >/dev/null 2>&1; then
  exit 1
fi
test "$(cat "$wallpaper_symlink_root/outside/path.txt")" = outside

denia_symlink_root=$(mktemp -d -t phase19c-denia-symlink.XXXXXXXX)
export HOME="$denia_symlink_root/home"
export XDG_STATE_HOME="$denia_symlink_root/state"
export XDG_DATA_HOME="$denia_symlink_root/data"
mkdir -p "$HOME" "$XDG_STATE_HOME" \
  "$XDG_DATA_HOME/cryoforge/theme-packs/cryoforge-denia" \
  "$denia_symlink_root/outside"
printf '%s\n' outside > "$denia_symlink_root/outside/wallpaper.jpg"
ln -s "$denia_symlink_root/outside/wallpaper.jpg" \
  "$XDG_DATA_HOME/cryoforge/theme-packs/cryoforge-denia/wallpaper.jpg"
if "$helper" cryoforge-denia >/dev/null 2>&1; then
  exit 1
fi
test "$(cat "$denia_symlink_root/outside/wallpaper.jpg")" = outside

traversal_root=$(mktemp -d -t phase19c-traversal.XXXXXXXX)
export HOME="$traversal_root/home"
export XDG_STATE_HOME="$traversal_root/state/../outside-state"
export XDG_DATA_HOME="$traversal_root/data"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$traversal_root/outside-state"
printf '%s\n' untouched > "$traversal_root/outside-state/sentinel"
if "$helper" neutral >/dev/null 2>&1; then
  exit 1
fi
test "$(cat "$traversal_root/outside-state/sentinel")" = untouched
test -z "$(find "$traversal_root/outside-state" -mindepth 1 \
  -not -name sentinel -print)"

mode_root=$(mktemp -d -t phase19c-modes.XXXXXXXX)
export HOME="$mode_root/home"
export XDG_STATE_HOME="$mode_root/state"
export XDG_DATA_HOME="$mode_root/data"
mkdir -p "$HOME"
test "$("$helper" cryoforge-denia)" = \
  '{"ok":true,"packId":"cryoforge-denia"}'
for directory in \
  "$XDG_STATE_HOME" \
  "$XDG_STATE_HOME/caelestia" \
  "$XDG_STATE_HOME/caelestia/wallpaper" \
  "$XDG_DATA_HOME" \
  "$XDG_DATA_HOME/cryoforge" \
  "$XDG_DATA_HOME/cryoforge/theme-packs" \
  "$XDG_DATA_HOME/cryoforge/theme-packs/cryoforge-denia"; do
  test "$(stat -c '%a' "$directory")" = 700
done
for file in \
  "$XDG_STATE_HOME/caelestia/scheme.json" \
  "$XDG_STATE_HOME/caelestia/wallpaper/path.txt" \
  "$XDG_DATA_HOME/cryoforge/theme-packs/cryoforge-denia/wallpaper.jpg"; do
  test "$(stat -c '%a' "$file")" = 600
done

# No extraction, app adapters, config overwrites, or background/network route.
! grep -E -i -q \
  'matugen|pywal|wallust|image[[:space:]_-]*extract|colour[[:space:]_-]*extract|wallpaper[[:space:]_-]*print|caelestia[[:space:]]+wallpaper' \
  "$source_page" "$helper_source" "$scheme_adapter" "$runtime_package"
! grep -E -i -q \
  'kitty|fastfetch|gtk|qt[[:space:]_-]*(theme|config)|\\.config|systemctl|systemd|sudo|curl|wget|https?://|network|daemon|\\.service|watchChanges|inotify|Timer[[:space:]]*\\{|poll|random|rotation' \
  "$source_page" "$helper_source" "$scheme_adapter" "$runtime_package" \
  "$selector_package"
! grep -E -q 'sh[[:space:]]+-c|bash[[:space:]]+-c|eval[[:space:]]' \
  "$source_page" "$helper_source"

test "$(cat "$boundary_evidence")" = \
  "current CryoForge systems use Phase 19C; Classic, Stock, lock, greeter, and historical systems use accepted boundaries"

if grep -R -E -q '/dev/pts/[0-9]+' "$trace_root"; then
  exit 1
fi
if grep -R -n $'\033' "$trace_root"/*.stdout "$trace_root"/*.stderr; then
  exit 1
fi
printf '%s\n' 'phase19c CLI statuses:'
cat "$trace_root/statuses.txt"
printf '%s\n' \
  "phase19c wallpaper state changed: yes" \
  "phase19c custom scheme identity and palette preserved: yes" \
  "phase19c numbered PTY opens/writes: none" \
  "phase19c terminal escape output: none"

# Match the repository formatting and warning policy for source and install.
# qmllint and qmlcachegen accepted the rejected QObject-to-Item assignment, so
# a pinned, headless Quickshell engine instantiation is required below.
diagnostics=$(mktemp -d -t phase19c-qml.XXXXXXXX)
printf '%s\n' 'phase19c QML formatting: start'
LC_ALL=C.UTF-8 qmlformat "$source_page" > "$diagnostics/source.formatted"
diff -u "$source_page" "$diagnostics/source.formatted"
LC_ALL=C.UTF-8 qmlformat "$installed_page" \
  > "$diagnostics/installed.formatted"
diff -u "$installed_page" "$diagnostics/installed.formatted"
printf '%s\n' 'phase19c QML formatting: pass'

# The installed page is the source page with exactly the two store-backed
# substitutions, and its PageBase boundary still accepts only one Item child.
python3 - \
  "$source_page" \
  "$installed_page" \
  "$runtime_root" \
  "$helper" \
  "$selector_shell/modules/nexus/common/PageBase.qml" \
  "$diagnostics" <<'PY'
import pathlib
import re
import sys

source_path = pathlib.Path(sys.argv[1])
installed_path = pathlib.Path(sys.argv[2])
runtime_root = sys.argv[3]
helper = sys.argv[4]
page_base_path = pathlib.Path(sys.argv[5])
diagnostics = pathlib.Path(sys.argv[6])

source = source_path.read_text()
installed = installed_path.read_text()
expected_installed = source.replace("@THEME_RUNTIME_ROOT@", runtime_root)
expected_installed = expected_installed.replace("@THEME_APPLY_HELPER@", helper)
assert installed == expected_installed
assert "@THEME_RUNTIME_ROOT@" not in installed
assert "@THEME_APPLY_HELPER@" not in installed
assert "default property Item contentChild" in page_base_path.read_text()


def scrub_qml(text: str) -> str:
    output = []
    state = "code"
    quote = ""
    escaped = False
    index = 0
    while index < len(text):
        char = text[index]
        following = text[index + 1] if index + 1 < len(text) else ""
        if state == "code":
            if char == "/" and following == "/":
                output.extend((" ", " "))
                state = "line-comment"
                index += 2
                continue
            if char == "/" and following == "*":
                output.extend((" ", " "))
                state = "block-comment"
                index += 2
                continue
            if char in {'"', "'", "`"}:
                output.append(" ")
                state = "string"
                quote = char
                escaped = False
                index += 1
                continue
            output.append(char)
            index += 1
            continue
        if state == "line-comment":
            if char == "\n":
                output.append("\n")
                state = "code"
            else:
                output.append(" ")
            index += 1
            continue
        if state == "block-comment":
            if char == "*" and following == "/":
                output.extend((" ", " "))
                state = "code"
                index += 2
            else:
                output.append("\n" if char == "\n" else " ")
                index += 1
            continue
        if char == "\n":
            output.append("\n")
        else:
            output.append(" ")
        if escaped:
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == quote:
            state = "code"
        index += 1
    assert state in {"code", "line-comment"}
    return "".join(output)


expected_properties = [
    ("Connections", "schemeObserver"),
    ("Connections", "subPageObserver"),
    ("FileView", "registrySource"),
    ("FileView", "previewSchemeSource"),
    ("Process", "applyRunner"),
]


def assert_root_structure(label: str, text: str) -> None:
    depth = 0
    properties = []
    direct_children = []
    for line_number, line in enumerate(scrub_qml(text).splitlines(), 1):
        stripped = line.strip()
        if depth == 1:
            typed = re.fullmatch(
                r"property\s+(Connections|FileView|Process)\s+"
                r"([A-Za-z_][A-Za-z0-9_]*)\s*:\s*\1\s*\{",
                stripped,
            )
            if typed:
                properties.append((typed.group(1), typed.group(2)))
            else:
                child = re.fullmatch(
                    r"([A-Z][A-Za-z0-9_]*)\s*\{",
                    stripped,
                )
                if child:
                    direct_children.append((child.group(1), line_number))
        depth += line.count("{") - line.count("}")
        assert depth >= 0, (label, line_number)
    assert depth == 0, label
    assert properties == expected_properties, (label, properties)
    assert [child for child, _ in direct_children] == ["ColumnLayout"], (
        label,
        direct_children,
    )


assert_root_structure("source", source)
assert_root_structure("installed", installed)

prefixes = {
    "Connections": [
        "property Connections schemeObserver: ",
        "property Connections subPageObserver: ",
    ],
    "FileView": [
        "property FileView registrySource: ",
        "property FileView previewSchemeSource: ",
    ],
    "Process": [
        "property Process applyRunner: ",
    ],
}
for values in prefixes.values():
    for prefix in values:
        assert installed.count(prefix) == 1, prefix

rejected = installed
for values in prefixes.values():
    for prefix in values:
        rejected = rejected.replace(prefix, "", 1)
(diagnostics / "rejected-all.qml").write_text(rejected)

for type_name in ("FileView", "Process"):
    fixture = installed
    prefix = prefixes[type_name][0]
    fixture = fixture.replace(prefix, "", 1)
    (diagnostics / f"rejected-{type_name.lower()}.qml").write_text(fixture)
PY
printf '%s\n' 'phase19c QML structure and fixtures: pass'

# Generate the same Quickshell tooling VFS used by the pinned shell's lint
# workflow, without requiring a compositor or touching live user state.
qml_tooling_root=$(mktemp -d -t phase19c-qml-tooling.XXXXXXXX)
selector_qt_wrapper_strings=$(strings "$selector_qt_wrapper")
selector_qml_import_path=$(
  printf '%s\n' "$selector_qt_wrapper_strings" \
    | grep -E '^/nix/store/[^[:space:]]+/lib/qt-6/qml$' \
    | sort -u \
    | paste -sd:
)
selector_qt_plugin_path=$(
  printf '%s\n' "$selector_qt_wrapper_strings" \
    | grep -E '^/nix/store/[^[:space:]]+/lib/qt-6/plugins$' \
    | sort -u \
    | paste -sd:
)
test -n "$selector_qml_import_path"
test -n "$selector_qt_plugin_path"
for entry in assets components modules services utils shell.qml; do
  ln -s "$selector_shell/$entry" "$qml_tooling_root/$entry"
done
touch "$qml_tooling_root/.qmlls.ini"
mkdir -p \
  "$qml_tooling_root/state/home" \
  "$qml_tooling_root/state/config" \
  "$qml_tooling_root/state/cache" \
  "$qml_tooling_root/state/data" \
  "$qml_tooling_root/state/local" \
  "$qml_tooling_root/state/runtime"
chmod 0700 "$qml_tooling_root/state/runtime"

set +e
env -u DISPLAY -u WAYLAND_DISPLAY \
  HOME="$qml_tooling_root/state/home" \
  XDG_CONFIG_HOME="$qml_tooling_root/state/config" \
  XDG_CACHE_HOME="$qml_tooling_root/state/cache" \
  XDG_DATA_HOME="$qml_tooling_root/state/data" \
  XDG_STATE_HOME="$qml_tooling_root/state/local" \
  XDG_RUNTIME_DIR="$qml_tooling_root/state/runtime" \
  QT_QPA_PLATFORM=offscreen \
  QSG_RHI_BACKEND=software \
  LC_ALL=C.UTF-8 \
  NO_COLOR=1 \
  NIXPKGS_QT6_QML_IMPORT_PATH="$selector_qml_import_path" \
  QT_PLUGIN_PATH="$selector_qt_plugin_path" \
  strace -f -qq \
    -e trace=open,openat,openat2,write \
    -o "$diagnostics/tooling.trace" \
    timeout 10 \
      "$selector_quickshell/bin/qs" \
        --no-color \
        --log-rules 'quickshell.ipc=false' \
        -p "$qml_tooling_root" \
    > "$diagnostics/tooling.stdout" \
    2> "$diagnostics/tooling.stderr"
tooling_status=$?
set -e
printf '%s\n' "$tooling_status" > "$diagnostics/tooling.status"
printf '%s\n' "phase19c QML tooling generation status: $tooling_status"

tooling_build_dir=$(
  sed -n 's/^buildDir="\(.*\)"/\1/p' "$qml_tooling_root/.qmlls.ini"
)
tooling_import_paths=$(
  sed -n 's/^importPaths="\(.*\)"/\1/p' "$qml_tooling_root/.qmlls.ini"
)
printf '%s\n' "phase19c QML tooling build dir: $tooling_build_dir"
if test -z "$tooling_build_dir" || test -z "$tooling_import_paths"; then
  cat "$diagnostics/tooling.stdout" "$diagnostics/tooling.stderr"
  exit 1
fi
test -d "$tooling_build_dir/qs"
qml_lint_args=(
  --bare
  --max-warnings
  9999
  -I
  "$tooling_build_dir"
)
IFS=: read -r -a tooling_import_path_list <<< "$tooling_import_paths"
for path in "${tooling_import_path_list[@]}"; do
  qml_lint_args+=(-I "$path")
done
if ! LC_ALL=C.UTF-8 qmllint "${qml_lint_args[@]}" "$source_page" \
  > "$diagnostics/source.stdout" 2> "$diagnostics/source.stderr"; then
  cat "$diagnostics/source.stdout" "$diagnostics/source.stderr"
  exit 1
fi
if ! LC_ALL=C.UTF-8 qmllint "${qml_lint_args[@]}" "$installed_page" \
  > "$diagnostics/installed.stdout" 2> "$diagnostics/installed.stderr"; then
  cat "$diagnostics/installed.stdout" "$diagnostics/installed.stderr"
  exit 1
fi
for stream in \
  "$diagnostics/source.stdout" \
  "$diagnostics/source.stderr" \
  "$diagnostics/installed.stdout" \
  "$diagnostics/installed.stderr"; do
  if test -s "$stream"; then
    cat "$stream"
    exit 1
  fi
done
printf '%s\n' 'phase19c complete-environment qmllint: pass'

qml_engine_root=$(mktemp -d -t phase19c-qml-engine.XXXXXXXX)
engine_target="$qml_engine_root/modules/nexus/pages/wallandstyle/ThemePackGallery.qml"
python3 - "$qml_engine_root" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
files = {
    "shell.qml": r'''
import QtQuick
import Quickshell
import qs.modules.nexus
import qs.modules.nexus.pages.wallandstyle

ShellRoot {
    NexusState {
        id: state
    }

    ThemePackGallery {
        nState: state
        width: 800
        height: 600
    }

    Timer {
        interval: 250
        running: true
        onTriggered: Qt.exit(0)
    }
}
''',
    "Caelestia/Config/qmldir": r'''
module Caelestia.Config
singleton Tokens 1.0 Tokens.qml
''',
    "Caelestia/Config/Tokens.qml": r'''
pragma Singleton

import QtQuick

QtObject {
    property QtObject sizes: QtObject {
        property QtObject nexus: QtObject {
            property real maxContentWidth: 800
        }
    }
    property QtObject spacing: QtObject {
        property real extraSmall: 2
        property real small: 4
        property real medium: 8
        property real large: 12
        property real largeIncreased: 16
        property real extraLarge: 20
        property real extraLargeIncreased: 24
    }
    property QtObject padding: QtObject {
        property real extraSmall: 2
        property real small: 4
        property real medium: 8
        property real large: 12
        property real extraLarge: 20
    }
    property QtObject rounding: QtObject {
        property real full: 999
        property real large: 12
    }
    property QtObject font: QtObject {
        property QtObject body: QtObject {
            property font small: Qt.font({ pixelSize: 12 })
            property font medium: Qt.font({ pixelSize: 14 })
            property font large: Qt.font({ pixelSize: 16 })
        }
        property QtObject label: QtObject {
            property font medium: Qt.font({ pixelSize: 12 })
        }
        property QtObject title: QtObject {
            property font small: Qt.font({ pixelSize: 16 })
            property font large: Qt.font({ pixelSize: 22 })
        }
        property QtObject icon: QtObject {
            property font medium: Qt.font({ pixelSize: 18 })
            property font extraLarge: Qt.font({ pixelSize: 28 })
        }
    }
}
''',
    "modules/nexus/NexusState.qml": r'''
import QtQuick

QtObject {
    signal subPageClosed

    function closeSubPage(): void {
        subPageClosed();
    }
}
''',
    "components/StyledText.qml": r'''
import QtQuick

Text {}
''',
    "components/StyledClippingRect.qml": r'''
import QtQuick

Rectangle {}
''',
    "components/StyledRect.qml": r'''
import QtQuick

Rectangle {}
''',
    "components/MaterialIcon.qml": r'''
import QtQuick

Text {
    property real fill
    property var fontStyle
}
''',
    "components/containers/VerticalFadeFlickable.qml": r'''
import QtQuick

Flickable {}
''',
    "components/controls/ButtonBase.qml": r'''
import QtQuick

Rectangle {
    enum ButtonType {
        Filled,
        Tonal,
        Text
    }

    property bool checked
    property bool disabled
    property bool isRound
    property bool radiusMorph
    property int type
    property color activeColour
    property color inactiveColour
    property color activeOnColour
    property color inactiveOnColour

    signal clicked
}
''',
    "components/controls/IconButton.qml": r'''
import QtQuick

Item {
    enum ButtonType {
        Filled,
        Tonal,
        Text
    }

    property string icon
    property var font
    property int type
    property bool isRound
    property bool disabled
    property color activeColour
    property color inactiveColour
    property color activeOnColour
    property color inactiveOnColour

    signal clicked
}
''',
    "components/controls/IconTextButton.qml": r'''
import QtQuick

Item {
    enum ButtonType {
        Filled,
        Tonal,
        Text
    }

    property string icon
    property string text
    property var font
    property int type
    property bool isRound
    property bool disabled

    signal clicked
}
''',
    "components/images/CachingImage.qml": r'''
import QtQuick

Item {
    property string path
    property int fillMode
}
''',
    "services/qmldir": r'''
module qs.services
singleton Colours 1.0 Colours.qml
singleton Wallpapers 1.0 Wallpapers.qml
''',
    "services/Colours.qml": r'''
pragma Singleton

import QtQuick

QtObject {
    property string cryoforgePackId
    property string flavour
    property string scheme
    property bool showPreview
    property QtObject palette: QtObject {
        property color m3error: "red"
        property color m3onSurface: "white"
        property color m3onSurfaceVariant: "lightgray"
        property color m3outline: "gray"
        property color m3outlineVariant: "darkgray"
        property color m3primary: "blue"
        property color m3secondary: "cyan"
    }
    property QtObject tPalette: QtObject {
        property color m3surfaceContainer: "gray"
        property color m3surfaceContainerHigh: "darkgray"
        property color m3surfaceContainerLow: "lightgray"
    }

    function load(data: string, preview: bool): void {}
}
''',
    "services/Wallpapers.qml": r'''
pragma Singleton

import QtQuick

QtObject {
    property bool previewColourLock

    function preview(path: string): void {}
    function stopPreview(): void {}
}
''',
}
for relative, content in files.items():
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.lstrip())
PY

mkdir -p \
  "$(dirname "$engine_target")" \
  "$qml_engine_root/modules/nexus/common"
ln -s \
  "$selector_shell/modules/nexus/common/PageBase.qml" \
  "$qml_engine_root/modules/nexus/common/PageBase.qml"
test -x "$selector_quickshell/bin/qs"

run_qml_engine() {
  local label=$1
  local page=$2
  local run_root="$qml_engine_root/state/$label"
  local qml_import_path="$qml_engine_root:$selector_qml_import_path"

  mkdir -p \
    "$run_root/home" \
    "$run_root/config" \
    "$run_root/cache" \
    "$run_root/data" \
    "$run_root/state" \
    "$run_root/runtime"
  chmod 0700 "$run_root/runtime"
  ln -sfn "$page" "$engine_target"

  set +e
  env -u DISPLAY -u WAYLAND_DISPLAY \
    HOME="$run_root/home" \
    XDG_CONFIG_HOME="$run_root/config" \
    XDG_CACHE_HOME="$run_root/cache" \
    XDG_DATA_HOME="$run_root/data" \
    XDG_STATE_HOME="$run_root/state" \
    XDG_RUNTIME_DIR="$run_root/runtime" \
    QT_QPA_PLATFORM=offscreen \
    QSG_RHI_BACKEND=software \
    LC_ALL=C.UTF-8 \
    NO_COLOR=1 \
    NIXPKGS_QT6_QML_IMPORT_PATH="$qml_import_path" \
    QT_PLUGIN_PATH="$selector_qt_plugin_path" \
    strace -f -qq \
      -e trace=open,openat,openat2,write \
      -o "$diagnostics/$label.trace" \
      "$selector_quickshell/bin/qs" \
        --no-color \
        --log-rules 'quickshell.ipc=false' \
        -p "$qml_engine_root/shell.qml" \
      > "$diagnostics/$label.stdout" \
      2> "$diagnostics/$label.stderr"
  local status=$?
  set -e
  cat \
    "$diagnostics/$label.stdout" \
    "$diagnostics/$label.stderr" \
    > "$diagnostics/$label.log"
  printf '%s\n' "$status" > "$diagnostics/$label.status"
  printf '%s\n' "phase19c QML engine $label status: $status"
  return "$status"
}

if run_qml_engine rejected-all "$diagnostics/rejected-all.qml"; then
  exit 1
fi
grep -Fq \
  'Cannot assign object of type "Connections" to property of type "QQuickItem*"' \
  "$diagnostics/rejected-all.log"

if run_qml_engine rejected-fileview "$diagnostics/rejected-fileview.qml"; then
  exit 1
fi
grep -Fq \
  'Cannot assign object of type "FileView" to property of type "QQuickItem*"' \
  "$diagnostics/rejected-fileview.log"

if run_qml_engine rejected-process "$diagnostics/rejected-process.qml"; then
  exit 1
fi
grep -Fq \
  'Cannot assign object of type "Process" to property of type "QQuickItem*"' \
  "$diagnostics/rejected-process.log"

run_qml_engine corrected-installed "$installed_page"
grep -Fq 'Configuration Loaded' "$diagnostics/corrected-installed.log"
! grep -Fq 'Failed to load configuration' \
  "$diagnostics/corrected-installed.log"
test "$(readlink -f "$engine_target")" = "$(readlink -f "$installed_page")"

engine_log_files=(
  "$diagnostics/rejected-all.log"
  "$diagnostics/rejected-fileview.log"
  "$diagnostics/rejected-process.log"
  "$diagnostics/corrected-installed.log"
)
! grep -R -E -q \
  'module ".*" is not installed|No PanelWindow backend loaded' \
  "${engine_log_files[@]}"
! grep -R -E -q '/dev/pts/[0-9]+' \
  "$diagnostics"/*.trace \
  "$diagnostics"/*.stdout \
  "$diagnostics"/*.stderr
! grep -R -n $'\033' \
  "$diagnostics"/*.stdout \
  "$diagnostics"/*.stderr

printf '%s\n' \
  "phase19c root visual content children: ColumnLayout only" \
  "phase19c rejected Connections/FileView/Process engine probes: failed as required" \
  "phase19c corrected installed QML engine instantiation: pass" \
  "phase19c QML engine numbered PTY access: none" \
  "phase19c QML engine terminal escape output: none"

printf '%s\n' 'phase19c manual theme selection contract tests: pass'
