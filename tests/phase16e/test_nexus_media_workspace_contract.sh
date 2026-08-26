#!/usr/bin/env bash

set -euo pipefail

shell_root=${1:?missing packaged CryoForge shell root}
pre16e_shell_root=${2:?missing pre-Phase-16E CryoForge shell root}
upstream_root=${3:?missing pinned Caelestia shell source}
package_nix=${4:?missing CryoForge package expression}
pre16e_package_nix=${5:?missing pre-Phase-16E package expression}
pre16d_package_nix=${6:?missing pre-Phase-16D package expression}
media_patch=${7:?missing Nexus Media Workspace patch}
media_page=${8:?missing Media Workspace page source}
focus_patch=${9:?missing Nexus Focus Hub patch}
focus_page=${10:?missing Focus Hub page source}
flake_nix=${11:?missing flake expression}
flake_lock=${12:?missing flake lock}
repo_root=${13:?missing repository source root}
target_system=${14:?missing real-greeter system output}

for file in \
  "$shell_root/modules/nexus/PageRegistry.qml" \
  "$shell_root/modules/nexus/PageCompRegistry.qml" \
  "$shell_root/modules/nexus/pages/FocusHubPage.qml" \
  "$shell_root/modules/nexus/pages/MediaWorkspacePage.qml" \
  "$pre16e_shell_root/modules/nexus/PageRegistry.qml" \
  "$pre16e_shell_root/modules/nexus/PageCompRegistry.qml" \
  "$pre16e_shell_root/modules/nexus/pages/FocusHubPage.qml" \
  "$upstream_root/modules/nexus/PageRegistry.qml" \
  "$upstream_root/modules/nexus/PageCompRegistry.qml" \
  "$upstream_root/services/Players.qml" \
  "$upstream_root/components/widgets/CoverArt.qml" \
  "$package_nix" \
  "$pre16e_package_nix" \
  "$pre16d_package_nix" \
  "$media_patch" \
  "$media_page" \
  "$focus_patch" \
  "$focus_page" \
  "$flake_nix" \
  "$flake_lock"; do
  test -r "$file"
done
test -d "$target_system"
test ! -e "$pre16e_shell_root/modules/nexus/pages/MediaWorkspacePage.qml"

sha256() {
  local value
  value=$(sha256sum "$1")
  printf '%s\n' "${value%% *}"
}

crlf_sha256() {
  sed 's/$/\r/' "$1" | sha256sum | cut -d ' ' -f 1
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

assert_no_runtime_diagnostic() {
  local output_file
  for output_file in "$@"; do
    ! grep -Fq 'ButtonRow is not a type' "$output_file"
  done
}

assert_button_row_component_import() {
  local page=$1
  grep -Fxq 'import Caelestia.Components' "$page"
  if grep -Fq 'ButtonRow {' "$page"; then
    grep -Fxq 'import Caelestia.Components' "$page"
  fi
}

allowed_phase16e_paths=(
  "desktop/caelestia/nexus/MediaWorkspacePage.qml"
  "desktop/caelestia/cryoforge-nexus-media-workspace.patch"
  "packages/caelestia-cryoforge.nix"
  "tests/phase16e/test_nexus_media_workspace_contract.sh"
  "flake.nix"
)

for path in "${allowed_phase16e_paths[@]}"; do
  test -r "$repo_root/$path"
done

if git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
  actual_paths=$(
    {
      git -C "$repo_root" diff --name-only origin/main --
      git -C "$repo_root" ls-files --others --exclude-standard
    } | sort -u
  )
  expected_paths=$(printf '%s\n' "${allowed_phase16e_paths[@]}" | sort -u)
  test "$actual_paths" = "$expected_paths"
fi

assert_sha256 "$media_page" \
  0f9e92d8a59e6504a0ec4588b767f4f312e9e88774aed4c87e3c8520c9214303
assert_sha256 "$media_patch" \
  2fb9bd5d7074705c7c9cf9dc20263abe52bc23c362e9885ab0fe5ed799db0cdd
assert_sha256 "$package_nix" \
  fa1e2df3757d80d5a4093c03201141a302a46cd064cf7a1f69df0dc8c317ab56
assert_sha256 "$focus_page" \
  ac150335343934b6529312fa0b98580e60e6bf39301f481d0956da90c62a5b8f
assert_sha256 "$focus_patch" \
  9084c0012ceff1a635c2fad4443e09b0470e6fc96205bc8a25d13c6ec055b287

assert_sha256 "$upstream_root/modules/nexus/PageRegistry.qml" \
  d257afbcc7f67b2206892b0fe209b5485ff9db46483d48d8bc5b25a81200c032
assert_sha256 "$upstream_root/modules/nexus/PageCompRegistry.qml" \
  97e55e31cd177cb63fd3d494343b93bd427a53a82c8e3f87401fcdaf6a469e91
assert_sha256 "$upstream_root/services/Players.qml" \
  935e8e35f27d314f9222de9abacad43003f362a56a74f6acf616989e46a60d97
assert_sha256 "$upstream_root/components/widgets/CoverArt.qml" \
  373542849aa3a57f66e626357054453460bea101df34a7b5cafeecb30298e791
test "$(crlf_sha256 "$upstream_root/services/Players.qml")" = \
  6a3babd3f23c000cd0206a81c0c69177272e5787b53f24086056cbffb6574f3f
test "$(crlf_sha256 "$upstream_root/components/widgets/CoverArt.qml")" = \
  7a1ba3e0c4d03566dbaf7fd62963715e35298422dad1f00761d341fd15edb810

# The package order and strict patch chain are both contractual. The first
# four patches produce the historical Phase 16D package; only then may 16E
# add its registry entries.
patches_block=$(sed -n '/patches = (old.patches or \[ \]) ++ \[/,/^  \];/p' "$package_nix")
for patch_entry in \
  '../desktop/caelestia/cryoforge-special-workspaces.patch' \
  'chisaPresetPatch' \
  'regionScreenshotPatch' \
  'nexusFocusHubPatch' \
  'nexusMediaWorkspacePatch'; do
  printf '%s\n' "$patches_block" | grep -Fq "$patch_entry"
done
grep -Fq 'chisaPresetPatch = ../desktop/caelestia/cryoforge-chisa-preset-gallery.patch;' "$package_nix"
grep -Fq 'regionScreenshotPatch = ../desktop/caelestia/cryoforge-region-screenshot.patch;' "$package_nix"
grep -Fq 'nexusFocusHubPatch = ../desktop/caelestia/cryoforge-nexus-focus-hub.patch;' "$package_nix"
grep -Fq 'nexusMediaWorkspacePatch = ../desktop/caelestia/cryoforge-nexus-media-workspace.patch;' "$package_nix"
special_line=$(printf '%s\n' "$patches_block" | grep -n -m1 'cryoforge-special-workspaces.patch' | cut -d: -f1)
gallery_line=$(printf '%s\n' "$patches_block" | grep -n -m1 'chisaPresetPatch' | cut -d: -f1)
region_line=$(printf '%s\n' "$patches_block" | grep -n -m1 'regionScreenshotPatch' | cut -d: -f1)
focus_line=$(printf '%s\n' "$patches_block" | grep -n -m1 'nexusFocusHubPatch' | cut -d: -f1)
media_line=$(printf '%s\n' "$patches_block" | grep -n -m1 'nexusMediaWorkspacePatch' | cut -d: -f1)
test "$special_line" -lt "$gallery_line"
test "$gallery_line" -lt "$region_line"
test "$region_line" -lt "$focus_line"
test "$focus_line" -lt "$media_line"
grep -Fq 'patchFlags = (old.patchFlags or [ "-p1" ]) ++ [ "--fuzz=0" ];' "$package_nix"

patch_root=$(mktemp -d -t phase16e-nexus-patch.XXXXXXXX)
trap 'rm -rf "$patch_root"' EXIT
cp -R "$upstream_root/." "$patch_root/"
chmod -R u+w "$patch_root"

for patch_file in \
  "$repo_root/desktop/caelestia/cryoforge-special-workspaces.patch" \
  "$repo_root/desktop/caelestia/cryoforge-chisa-preset-gallery.patch" \
  "$repo_root/desktop/caelestia/cryoforge-region-screenshot.patch" \
  "$focus_patch"; do
  patch_output=$(
    patch --batch --forward --fuzz=0 --strip=1 --directory="$patch_root" \
      < "$patch_file" 2>&1
  )
  ! printf '%s\n' "$patch_output" | grep -E -i -q \
    'fuzz|failed|reversed|skipping'
  ! printf '%s\n' "$patch_output" | grep -Fq 'ButtonRow is not a type'
done

cmp "$patch_root/modules/nexus/PageRegistry.qml" \
  "$pre16e_shell_root/modules/nexus/PageRegistry.qml"
cmp "$patch_root/modules/nexus/PageCompRegistry.qml" \
  "$pre16e_shell_root/modules/nexus/PageCompRegistry.qml"
cmp "$focus_page" "$pre16e_shell_root/modules/nexus/pages/FocusHubPage.qml"
grep -Fq 'label: qsTr("Focus Hub")' \
  "$pre16e_shell_root/modules/nexus/PageRegistry.qml"
! grep -Fq 'Media Workspace' \
  "$pre16e_shell_root/modules/nexus/PageRegistry.qml"
! grep -Fq 'MediaWorkspacePage {}' \
  "$pre16e_shell_root/modules/nexus/PageCompRegistry.qml"

patch_output=$(
  patch --batch --forward --fuzz=0 --strip=1 --directory="$patch_root" \
    < "$media_patch" 2>&1
)
! printf '%s\n' "$patch_output" | grep -E -i -q \
  'fuzz|failed|reversed|skipping'
! printf '%s\n' "$patch_output" | grep -Fq 'ButtonRow is not a type'

cmp "$patch_root/modules/nexus/PageRegistry.qml" \
  "$shell_root/modules/nexus/PageRegistry.qml"
cmp "$patch_root/modules/nexus/PageCompRegistry.qml" \
  "$shell_root/modules/nexus/PageCompRegistry.qml"
cmp "$media_page" "$shell_root/modules/nexus/pages/MediaWorkspacePage.qml"
cmp "$focus_page" "$shell_root/modules/nexus/pages/FocusHubPage.qml"
assert_button_row_component_import "$media_page"
assert_button_row_component_import \
  "$shell_root/modules/nexus/pages/MediaWorkspacePage.qml"

assert_sha256 "$shell_root/modules/nexus/PageRegistry.qml" \
  466000d47281e05b570538b85d619a4b2bb5943417762e70153e5ba7a9678180
assert_sha256 "$shell_root/modules/nexus/PageCompRegistry.qml" \
  a754b17aa3c28b1184c1ca16ac183b998be51746f478500a9ef3ecab3f64f3e5
assert_sha256 "$shell_root/modules/nexus/pages/MediaWorkspacePage.qml" \
  0f9e92d8a59e6504a0ec4588b767f4f312e9e88774aed4c87e3c8520c9214303

mapfile -t first_labels < <(
  sed -n '/readonly property list<var> pages: \[/,$p' \
    "$shell_root/modules/nexus/PageRegistry.qml" \
    | grep 'label:' \
    | head -3
)
test "${first_labels[0]}" = '            label: qsTr("Focus Hub"),'
test "${first_labels[1]}" = '            label: qsTr("Media Workspace"),'
test "${first_labels[2]}" = '            label: qsTr("Wallpaper & style"),'

mapfile -t first_components < <(
  grep -E 'FocusHubPage \{\}|MediaWorkspacePage \{\}|WallpaperAndStyle \{\}' \
    "$shell_root/modules/nexus/PageCompRegistry.qml" \
    | head -3
)
test "${first_components[0]}" = '            FocusHubPage {}'
test "${first_components[1]}" = '            MediaWorkspacePage {}'
test "${first_components[2]}" = '                    WallpaperAndStyle {}'

# Page structure, hierarchy, read-only progress, exact controls, selector, and
# empty-state behavior all use existing token-driven Caelestia primitives.
for token in \
  'PageBase {' \
  'ConnectedRect {' \
  'SectionHeader {' \
  'CoverArt {' \
  'StyledProgressBar {' \
  'ButtonRow {' \
  'IconButton {' \
  'SplitButton {' \
  'Variants {' \
  'MenuItem {' \
  'Tokens.padding' \
  'Tokens.spacing' \
  'Tokens.font' \
  'Colours.palette'; do
  grep -Fq "$token" "$media_page"
done
! grep -E -q '#[0-9a-fA-F]{3,8}' "$media_page"
grep -Fq 'width: root.cappedWidth' "$media_page"
grep -Fq 'title: qsTr("Media Workspace")' "$media_page"
grep -Fq 'trackTitle' "$media_page"
grep -Fq 'trackArtist' "$media_page"
grep -Fq 'trackAlbum' "$media_page"
grep -Fq 'Players.getIdentity' "$media_page"
grep -Fq 'Unknown title' "$media_page"
grep -Fq 'Unknown artist' "$media_page"
grep -Fq 'Unknown album' "$media_page"
grep -Fq 'MPRIS-capable player starts' "$media_page"
grep -Fq 'music_off' "$media_page"
grep -Fq 'Number.isFinite' "$media_page"
grep -Fq 'trackLength <= 2147483647' "$media_page"
grep -Fq 'root.trackPosition / root.trackLength' "$media_page"
grep -Fq 'formatDuration' "$media_page"
grep -Fq 'Length unavailable' "$media_page"

test "$(grep -c 'IconButton {' "$media_page")" -eq 3
for capability in canGoPrevious canTogglePlaying canGoNext; do
  grep -Fq "disabled: !root.activePlayer?.$capability" "$media_page"
  grep -Fq "if (active?.$capability)" "$media_page"
done
for method in previous togglePlaying next; do
  grep -Fq "active.$method();" "$media_page"
done
grep -Fq 'Players.manualActive = (item as PlayerItem).modelData' "$media_page"

players_references=$(grep -oE 'Players\.[A-Za-z][A-Za-z0-9]*' "$media_page" | sort -u)
while IFS= read -r reference; do
  case "$reference" in
    Players.active|Players.getIdentity|Players.list|Players.manualActive) ;;
    *) exit 1 ;;
  esac
done <<< "$players_references"

players_assignments=$(
  grep -E 'Players\.[A-Za-z][A-Za-z0-9]*[[:space:]]*=' "$media_page" || true
)
test "$(printf '%s\n' "$players_assignments" | grep -c .)" -eq 1
printf '%s\n' "$players_assignments" \
  | grep -Fq 'Players.manualActive = (item as PlayerItem).modelData'

player_method_calls=$(
  grep -oE 'active\.(previous|togglePlaying|next)\(' "$media_page" | sort -u
)
test "$player_method_calls" = $'active.next(\nactive.previous(\nactive.togglePlaying('
! grep -E -q \
  '(Players\.active|activePlayer|active)\??\.(position|length|shuffle|loopState|volume)[[:space:]]*=' \
  "$media_page"

! grep -E -i -q \
  'Timer[[:space:]]*\{|Process[[:space:]]*\{|FileView[[:space:]]*\{|IpcHandler[[:space:]]*\{|Quickshell\.exec|execDetached|systemctl|shell[[:space:]]+command' \
  "$media_page" "$media_patch"
! grep -E -i -q \
  'ServiceRef[[:space:]]*\{|PersistentProperties[[:space:]]*\{|CustomShortcut[[:space:]]*\{|systemd|ExecStart|daemon|watcher|inotify' \
  "$media_page" "$media_patch"
! grep -E -i -q \
  'curl|wget|https?://|fetchurl|fetchFrom|builtins\.fetch' \
  "$media_page" "$media_patch"
! grep -E -i -q \
  'lyrics|wallpaper|matugen|pywal|wallust|dynamic[[:space:]_-]*(colou?r|theme)|theme[[:space:]_-]*pack' \
  "$media_page" "$media_patch"
! grep -E -i -q \
  'Hypr|dispatch|workspace|move[[:space:]_-]*window|kill[[:space:]_-]*window|close[[:space:]_-]*window' \
  "$media_page" "$media_patch"
! grep -E -i -q \
  'greeter|hyprlock|WlSessionLock|ReGreet|greetd|PAM|Plymouth|screenshot|window[[:space:]_-]*feel' \
  "$media_page" "$media_patch"

package_header_hash=$(
  sed -n '1,/^}:$/p' "$package_nix" | sha256sum | cut -d ' ' -f 1
)
test "$package_header_hash" = \
  302f9f86c3581869e687a43024963695caebe53c8e7f446806807e905e4a64f2
if git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
  phase_package_additions=$(
    git -C "$repo_root" diff --unified=0 origin/main -- \
      packages/caelestia-cryoforge.nix \
      | sed -n '/^+/p' \
      | grep -v '^+++' \
      || true
  )
  ! printf '%s\n' "$phase_package_additions" \
    | grep -E -i -q \
      'runtimeInputs|buildInputs|propagatedBuildInputs|nativeBuildInputs|fetchurl|fetchFrom|builtins\.fetch|curl|wget|https?://|systemd|ExecStart|daemon|watcher|inotify'
fi

# Both package projections must be exact, ordered removals. Recompute them
# independently from the final package source and compare byte-for-byte.
python3 - "$package_nix" "$pre16e_package_nix" "$pre16d_package_nix" <<'PY'
from pathlib import Path
import sys

final_path, pre16e_path, pre16d_path = map(Path, sys.argv[1:])
final = final_path.read_text()

phase16e = [
    r'''  nexusMediaWorkspacePage = ../desktop/caelestia/nexus/MediaWorkspacePage.qml;
  nexusMediaWorkspacePageSha256 = "0f9e92d8a59e6504a0ec4588b767f4f312e9e88774aed4c87e3c8520c9214303";
  nexusMediaWorkspacePatch = ../desktop/caelestia/cryoforge-nexus-media-workspace.patch;
  nexusMediaWorkspacePatchSha256 = "2fb9bd5d7074705c7c9cf9dc20263abe52bc23c362e9885ab0fe5ed799db0cdd";
  nexusMediaWorkspaceSourceHashes = {
    "modules/nexus/PageRegistry.qml" = "d257afbcc7f67b2206892b0fe209b5485ff9db46483d48d8bc5b25a81200c032";
    "modules/nexus/PageCompRegistry.qml" = "97e55e31cd177cb63fd3d494343b93bd427a53a82c8e3f87401fcdaf6a469e91";
    "services/Players.qml" = "935e8e35f27d314f9222de9abacad43003f362a56a74f6acf616989e46a60d97";
    "components/widgets/CoverArt.qml" = "373542849aa3a57f66e626357054453460bea101df34a7b5cafeecb30298e791";
  };
''',
    r'''    assert lib.assertMsg (
      builtins.hashFile "sha256" nexusMediaWorkspacePage == nexusMediaWorkspacePageSha256
    ) "CryoForge Nexus Media Workspace page checksum mismatch";
    assert lib.assertMsg (
      builtins.hashFile "sha256" nexusMediaWorkspacePatch == nexusMediaWorkspacePatchSha256
    ) "CryoForge Nexus Media Workspace patch checksum mismatch";
    assert lib.assertMsg (
      lib.all (
        path:
        builtins.hashFile "sha256" "${caelestia-shell}/${path}" == nexusMediaWorkspaceSourceHashes.${path}
      ) (builtins.attrNames nexusMediaWorkspaceSourceHashes)
    ) "Refusing to apply the Nexus Media Workspace patch to changed upstream QML";
''',
    r'''    nexusMediaWorkspacePatch
''',
    r'''    ${coreutils}/bin/install -m 0444 \
      ${nexusMediaWorkspacePage} \
      "$out/share/caelestia-shell/modules/nexus/pages/MediaWorkspacePage.qml"
''',
]

phase16d = [
    r'''  nexusFocusHubPage = ../desktop/caelestia/nexus/FocusHubPage.qml;
''',
    r'''  nexusFocusHubPatch = ../desktop/caelestia/cryoforge-nexus-focus-hub.patch;
''',
    r'''  nexusFocusHubPatchSha256 = "9084c0012ceff1a635c2fad4443e09b0470e6fc96205bc8a25d13c6ec055b287";
''',
    r'''  nexusFocusHubSourceHashes = {
    "modules/nexus/PageRegistry.qml" = "d257afbcc7f67b2206892b0fe209b5485ff9db46483d48d8bc5b25a81200c032";
    "modules/nexus/PageCompRegistry.qml" = "97e55e31cd177cb63fd3d494343b93bd427a53a82c8e3f87401fcdaf6a469e91";
  };
''',
    r'''    assert lib.assertMsg (
      builtins.hashFile "sha256" nexusFocusHubPatch == nexusFocusHubPatchSha256
    ) "CryoForge Nexus Focus Hub patch checksum mismatch";
''',
    r'''    assert lib.assertMsg (
      lib.all (
        path:
        builtins.hashFile "sha256" "${caelestia-shell}/${path}" == nexusFocusHubSourceHashes.${path}
      ) (builtins.attrNames nexusFocusHubSourceHashes)
    ) "Refusing to apply the Nexus Focus Hub patch to changed upstream QML";
''',
    r'''    nexusFocusHubPatch
''',
    r'''    ${coreutils}/bin/install -m 0444 \
      ${nexusFocusHubPage} \
      "$out/share/caelestia-shell/modules/nexus/pages/FocusHubPage.qml"
''',
]

def remove_exact(source: str, snippets: list[str], phase: str) -> str:
    for snippet in snippets:
        count = source.count(snippet)
        assert count == 1, f"{phase} snippet matched {count} times"
        source = source.replace(snippet, "", 1)
    return source

expected_pre16e = remove_exact(final, phase16e, "Phase 16E")
assert expected_pre16e == pre16e_path.read_text()
assert "nexusFocusHubPatch" in expected_pre16e
assert "nexusMediaWorkspace" not in expected_pre16e

expected_pre16d = remove_exact(expected_pre16e, phase16d, "Phase 16D")
assert expected_pre16d == pre16d_path.read_text()
assert "nexusFocusHub" not in expected_pre16d
assert "nexusMediaWorkspace" not in expected_pre16d
PY

assert_sha256 "$pre16d_package_nix" \
  eba2358673c4b316464ed80c8aebef271fc7bf00dc421760a58509d1bea4d312
grep -Fq 'nexusFocusHubPatch' "$pre16e_package_nix"
! grep -Fq 'nexusMediaWorkspace' "$pre16e_package_nix"
! grep -Fq 'nexusFocusHub' "$pre16d_package_nix"
! grep -Fq 'nexusMediaWorkspace' "$pre16d_package_nix"
grep -Fq 'replaceExactly = label: needle: replacement: value:' "$flake_nix"
grep -Fq 'removeExactSnippets = phase: snippets: value:' "$flake_nix"
grep -Fq 'phase16eBaseCryoforgePackageSourceText' "$flake_nix"
grep -Fq 'phase16dBaseCryoforgePackageSourceText' "$flake_nix"

# The focused check is tied to the dedicated real-greeter target and never to
# the classic system.
phase16e_block=$(sed -n \
  '/phase16e-nexus-media-workspace-contract =/,/phase17a-screenshot-contract =/p' \
  "$flake_nix")
printf '%s\n' "$phase16e_block" | grep -Fq 'realGreeterSystem'
printf '%s\n' "$phase16e_block" \
  | grep -Fq 'nixos-caelestia-cryoforge-real-greeter'
! printf '%s\n' "$phase16e_block" | grep -Fq 'classicSystem'
! printf '%s\n' "$phase16e_block" | grep -Fq 'nixosConfigurations.nixos.'

# Preserve every previously accepted phase source and protected source tree.
assert_sha256 "$repo_root/flake.lock" \
  bbca26850cfa467fc5afc177802ae1f3bbca20827f8577e5af9285711f30ade3
assert_sha256 "$repo_root/home.nix" \
  4b05f82c54daa4c2e1f8a702dbf664bcebe5a339082a4a382bfc38600f96024a
assert_sha256 "$repo_root/configuration.nix" \
  9cd8cfccae6924b685253cc1b973434c0e46ea0f22c21cb259aae6f33175dcd3
assert_sha256 "$repo_root/desktop-hyprland.nix" \
  777763eed185393068709618d9462d1e58fd291b4344a3e7f7e56f5c2b38c2ad
assert_sha256 "$repo_root/desktop/profiles.nix" \
  9de59b0dca05eb17df9b8452472b353f12ec8cdc48de1bcd93c1f1c86d1c433e
assert_sha256 "$repo_root/desktop/palette.nix" \
  8897b1df8d0c407de6536c6cf3014b4cdd3d675c25e804148c9b91f1024d6f35
assert_sha256 "$repo_root/desktop/apps/kitty.nix" \
  c7a8efdfe35c7ad9936ad768fb99aa577ee10d52755531a290d38bed2dff1f89
assert_sha256 "$repo_root/desktop/apps/fastfetch.nix" \
  c8aed6c3fccaa086968793e37daa2514eac2c641578f7d996c8fe598bc5e2a18
assert_sha256 "$repo_root/desktop/caelestia/real-greeter-system.nix" \
  e63487de3f193c738a13bb4429b6bc83c01f73767de81057cb1e1ead58f99ce3
assert_sha256 "$repo_root/packages/caelestia-real-greeter.nix" \
  795a7009c6a8d52db1d3d1aec4c243ee6bcbac6486eb4cf2bdcccb4bad0ce17a
assert_sha256 "$repo_root/packages/caelestia-real-lock.nix" \
  3c723b62e24a4f3b119ddfc3fe4e3ab50ba9771bb6007e0118bdab3b250d1175
assert_sha256 "$repo_root/desktop/caelestia/screenshot-region.sh" \
  b5ce59848a0750dc94f68baf2ebce15f72c727315c6e7d79fca5fb5c2cd2d495
assert_sha256 "$repo_root/desktop/caelestia/cryoforge-special-workspaces.patch" \
  738cc7cccca63d09cedc88889f6a5374111cd015d2f76a560c9f9180265d927d
assert_sha256 "$repo_root/desktop/caelestia/cryoforge-chisa-preset-gallery.patch" \
  0b73f3dc7fd093e4d5b167079c2a8f80fcf08e6791cb4855e55bbe983ccaf877
assert_sha256 "$repo_root/desktop/caelestia/cryoforge-region-screenshot.patch" \
  6db4facdd61b639abca962b147b9e4a1bd6bb3a849a24a9a12440decb483fc83
assert_sha256 "$repo_root/desktop/caelestia/nexus/FocusHubPage.qml" \
  ac150335343934b6529312fa0b98580e60e6bf39301f481d0956da90c62a5b8f
assert_sha256 "$repo_root/desktop/caelestia/cryoforge-nexus-focus-hub.patch" \
  9084c0012ceff1a635c2fad4443e09b0470e6fc96205bc8a25d13c6ec055b287
assert_sha256 "$repo_root/tests/phase13c/test_real_lock_contract.sh" \
  c98cfbaf54467346d744151ba6a974b12afa34089dddd3dcc9c4319128382927
assert_sha256 "$repo_root/tests/phase16a/test_chisa_preset_gallery_contract.sh" \
  af8f74f47f6242699fb9f780702665503675302a5adc8858a78f0e5a6bf8da87
assert_sha256 "$repo_root/tests/phase16b/test_window_feel_contract.sh" \
  36404c9299616c60afa7a66dda60e1d6da5c3fceb6d72db1bcfdbec520032fed
assert_sha256 "$repo_root/tests/phase16c/test_base_app_integration_contract.sh" \
  620cab3456057a7e6ceb9f93c61a014e8eb9ac771210d331f2d803c8fb9ed844
assert_sha256 "$repo_root/tests/phase16d/test_nexus_focus_hub_contract.sh" \
  7b97a8a1234f4e5be7d502900762aae5e8d1391f643fcc60658bd69e2d7604e5
assert_sha256 "$repo_root/tests/phase17a/test_screenshot_contract.sh" \
  068e07e49f673b1ec426c43bd5a731f68aef6b862ca67d5d8abd29240db0088d

test "$(tree_sha256 "$repo_root/desktop/caelestia/chisa-pool")" = \
  c4d0023da16013ef1de8e8148ba082fc3bab7921a8ba9846be039a4b3c33013a
test "$(tree_sha256 "$repo_root/desktop/caelestia/real-greeter")" = \
  25b5c3ab705711045d1d85f71d7940d304258dd9cbb7e74cd6eb0dbfd16b818d
test "$(tree_sha256 "$repo_root/desktop/regreet")" = \
  5b08508f58e424dbcdf624839947ded0b13351e7dfaad3e2df09792346b3e6ce
test "$(tree_sha256 "$repo_root/desktop/hypr")" = \
  6f2a3f371355608f8246c9803356309569bcd80d0a78bd8c60d901e8ce37d74c

diagnostic_root=$(mktemp -d -t phase16e-media-diagnostics.XXXXXXXX)
trap 'rm -rf "$patch_root" "$diagnostic_root"' EXIT

qmlformat "$media_page" \
  > "$diagnostic_root/source.qmlformat.stdout" \
  2> "$diagnostic_root/source.qmlformat.stderr"
assert_no_runtime_diagnostic \
  "$diagnostic_root/source.qmlformat.stdout" \
  "$diagnostic_root/source.qmlformat.stderr"
diff -u "$media_page" "$diagnostic_root/source.qmlformat.stdout"

rendered_media_page="$shell_root/modules/nexus/pages/MediaWorkspacePage.qml"
qmlformat "$rendered_media_page" \
  > "$diagnostic_root/rendered.qmlformat.stdout" \
  2> "$diagnostic_root/rendered.qmlformat.stderr"
assert_no_runtime_diagnostic \
  "$diagnostic_root/rendered.qmlformat.stdout" \
  "$diagnostic_root/rendered.qmlformat.stderr"
diff -u "$rendered_media_page" "$diagnostic_root/rendered.qmlformat.stdout"

qmllint --bare --max-warnings 9999 \
  -I "$shell_root" \
  "$media_page" \
  > "$diagnostic_root/source.qmllint.stdout" \
  2> "$diagnostic_root/source.qmllint.stderr"
assert_no_runtime_diagnostic \
  "$diagnostic_root/source.qmllint.stdout" \
  "$diagnostic_root/source.qmllint.stderr"

qmllint --bare --max-warnings 9999 \
  -I "$shell_root" \
  "$rendered_media_page" \
  > "$diagnostic_root/rendered.qmllint.stdout" \
  2> "$diagnostic_root/rendered.qmllint.stderr"
assert_no_runtime_diagnostic \
  "$diagnostic_root/rendered.qmllint.stdout" \
  "$diagnostic_root/rendered.qmllint.stderr"

printf '%s\n' 'phase16e Nexus Media Workspace contract tests: pass'
