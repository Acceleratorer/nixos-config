#!/usr/bin/env bash

set -euo pipefail

shell_root=${1:?missing packaged CryoForge shell root}
upstream_root=${2:?missing pinned Caelestia source}
package_nix=${3:?missing CryoForge package expression}
patch=${4:?missing Chisa preset gallery patch}
manifest=${5:?missing Chisa preset manifest}
gallery=${6:?missing Chisa preset gallery source}
wallpapers=${7:?missing Chisa wallpaper service overlay}

sha256() {
  local value
  value=$(sha256sum "$1")
  printf '%s\n' "${value%% *}"
}

test -r "$shell_root/services/Wallpapers.qml"
test -r "$shell_root/services/ChisaPresets.qml"
test -r "$shell_root/modules/nexus/pages/wallandstyle/ChisaPresetGallery.qml"
test -r "$upstream_root/services/Wallpapers.qml"
test -r "$package_nix"
test -r "$patch"
test -r "$manifest"
test -r "$gallery"
test -r "$wallpapers"

# The package patch is guarded against the pinned Nexus files and only adds
# the gallery to the existing Wallpaper & Style subpage stack.
test "$(sha256 "$upstream_root/modules/nexus/PageCompRegistry.qml")" = \
  97e55e31cd177cb63fd3d494343b93bd427a53a82c8e3f87401fcdaf6a469e91
test "$(sha256 "$upstream_root/modules/nexus/pages/WallpaperAndStyle.qml")" = \
  b6bb2d3c496d226f9c3cd4db73683cd2d0223c312fc22d792a52410c78f346a9
grep -Fq 'ChisaPresetGallery {}' "$patch"
grep -Fq 'Chisa presets' "$patch"
grep -Fq 'ChisaPresetGallery {}' "$shell_root/modules/nexus/PageCompRegistry.qml"
grep -Fq 'Chisa presets' "$shell_root/modules/nexus/pages/WallpaperAndStyle.qml"

# The catalog is finite, manual, and only contains the approved Chisa Pool.
test "$(grep -c '"id": "chisa-pool"' "$manifest")" -eq 1
grep -Fq '"name": "Chisa Pool"' "$manifest"
grep -Fq 'assets/chisa-pool-direct.jpg' "$manifest"
grep -Fq 'PersistentProperties' "$manifest"
grep -Fq 'reloadableId: "chisaPresetGallery"' "$manifest"
grep -Fq 'props.selectedPresetId = preset.id;' "$manifest"
grep -Fq 'Wallpapers.preview(preset.wallpaper);' "$manifest"
grep -Fq 'Wallpapers.setManualWallpaper(preset.wallpaper);' "$manifest"
! grep -E -i -q 'random|rotation|rotate|timer|cycle|https?://|fetch|denia|img[1-9]' \
  "$manifest" "$gallery"
! grep -E -q 'Colours\.(load|setMode)|GlobalConfig' "$manifest" "$gallery"

# A preview is temporary; only the visible Apply path persists wallpaper and
# the bounded preset token selection. Escape closes via the existing stack.
grep -Fq 'text: qsTr("Apply")' "$gallery"
grep -Fq 'ChisaPresets.apply(pendingPreset);' "$gallery"
grep -Fq 'Keys.onEscapePressed' "$gallery"
grep -Fq 'Keys.onPressed' "$gallery"
grep -Fq 'forceActiveFocus()' "$gallery"
grep -Fq 'Image.PreserveAspectFit' "$gallery"
grep -Fq 'Preview selected' "$gallery"
grep -Fq 'Apply confirms the wallpaper and its Chisa accents.' "$gallery"

# Preserve the real service's state file, IPC, local file model, and existing
# preview lifecycle. The gallery path forces --no-smart and never launches
# dynamic wallpaper colour extraction.
grep -Fq 'currentNamePath: `${Paths.state}/wallpaper/path.txt`' "$wallpapers"
grep -Fq 'IpcHandler' "$wallpapers"
grep -Fq 'target: "wallpaper"' "$wallpapers"
grep -Fq 'FileView' "$wallpapers"
grep -Fq 'FileSystemModel' "$wallpapers"
grep -Fq 'function setManualWallpaper(path: string): void' "$wallpapers"
grep -Fq '"--no-smart"' "$wallpapers"
grep -Fq 'Colours.scheme === "dynamic" && !previewColourLock' "$wallpapers"
grep -Fq 'fallback: Quickshell.shellPath("assets/chisa-pool-direct.jpg")' "$wallpapers"

# Nexus remains owned by the invoking screen; the gallery never chooses an
# output by name and leaves the existing outside-dismiss behavior untouched.
grep -Fq 'nState.screen: root.screen' "$shell_root/modules/bar/popouts/Wrapper.qml"
! grep -E -q 'HDMI|DP-|monitorName' "$gallery"

test "$(sha256 "$shell_root/assets/chisa-pool-direct.jpg")" = \
  a4dfcf92c4170405ac37102b27c606c5e9b1bb6cd77c9f04d530fa752aab604c
! find "$shell_root" \( -iname '*denia*' -o -iname '*img7*' \) -print | grep -q .

printf '%s\n' 'phase16a Chisa preset gallery contract tests: pass'
