#!/usr/bin/env bash

set -euo pipefail

shell_root=${1:?missing packaged CryoForge shell root}
upstream_root=${2:?missing pinned Caelestia shell source}
package_nix=${3:?missing CryoForge package expression}
focus_patch=${4:?missing Nexus Focus Hub patch}
focus_page=${5:?missing Focus Hub page source}
flake_nix=${6:?missing flake expression}
flake_lock=${7:?missing flake lock}
repo_root=${8:?missing repository source root}
target_system=${9:?missing real-greeter system output}

for file in \
  "$shell_root/modules/nexus/PageRegistry.qml" \
  "$shell_root/modules/nexus/PageCompRegistry.qml" \
  "$shell_root/modules/nexus/pages/FocusHubPage.qml" \
  "$upstream_root/modules/nexus/PageRegistry.qml" \
  "$upstream_root/modules/nexus/PageCompRegistry.qml" \
  "$package_nix" \
  "$focus_patch" \
  "$focus_page" \
  "$flake_nix" \
  "$flake_lock"; do
  test -r "$file"
done
test -d "$target_system"

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

assert_sha256() {
  test "$(sha256 "$1")" = "$2"
}

allowed_phase16d_paths=(
  "desktop/caelestia/nexus/FocusHubPage.qml"
  "desktop/caelestia/cryoforge-nexus-focus-hub.patch"
  "packages/caelestia-cryoforge.nix"
  "tests/phase16d/test_nexus_focus_hub_contract.sh"
  "flake.nix"
)

for path in "${allowed_phase16d_paths[@]}"; do
  test -r "$repo_root/$path"
done

# When run from the authoritative checkout, the Phase 16D diff must contain
# exactly the five allowlisted paths. The Nix flake invocation receives a
# filtered source tree without Git metadata, so its static path assertions
# above remain the portable equivalent.
if git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
  actual_paths=$(
    {
      git -C "$repo_root" diff --name-only origin/main --
      git -C "$repo_root" ls-files --others --exclude-standard
    } | sort -u
  )
  expected_paths=$(printf '%s\n' "${allowed_phase16d_paths[@]}" | sort -u)
  test "$actual_paths" = "$expected_paths"
fi

assert_sha256 "$focus_patch" \
  9084c0012ceff1a635c2fad4443e09b0470e6fc96205bc8a25d13c6ec055b287
assert_sha256 "$upstream_root/modules/nexus/PageRegistry.qml" \
  d257afbcc7f67b2206892b0fe209b5485ff9db46483d48d8bc5b25a81200c032
assert_sha256 "$upstream_root/modules/nexus/PageCompRegistry.qml" \
  97e55e31cd177cb63fd3d494343b93bd427a53a82c8e3f87401fcdaf6a469e91

# Apply every accepted Nexus-adjacent patch in package order. Any offset is
# allowed by the existing Chisa/screenshot patches, but fuzz is never allowed.
patch_root=$(mktemp -d -t phase16d-nexus-patch.XXXXXXXX)
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
done

cmp "$patch_root/modules/nexus/PageRegistry.qml" \
  "$shell_root/modules/nexus/PageRegistry.qml"
cmp "$patch_root/modules/nexus/PageCompRegistry.qml" \
  "$shell_root/modules/nexus/PageCompRegistry.qml"

test -r "$shell_root/modules/nexus/pages/FocusHubPage.qml"
cmp "$focus_page" "$shell_root/modules/nexus/pages/FocusHubPage.qml"

focus_line=$(grep -n -m1 'label: qsTr("Focus Hub")' \
  "$shell_root/modules/nexus/PageRegistry.qml" | cut -d: -f1)
appearance_line=$(grep -n -m1 '// Appearance' \
  "$shell_root/modules/nexus/PageRegistry.qml" | cut -d: -f1)
test "$focus_line" -lt "$appearance_line"
first_label=$(
  sed -n '/readonly property list<var> pages: \[/,$p' \
    "$shell_root/modules/nexus/PageRegistry.qml" \
    | grep -m1 'label:'
)
test "$first_label" = '            label: qsTr("Focus Hub"),'

focus_component_line=$(grep -n -m1 'FocusHubPage {}' \
  "$shell_root/modules/nexus/PageCompRegistry.qml" | cut -d: -f1)
appearance_component_line=$(grep -n -m1 '// Appearance' \
  "$shell_root/modules/nexus/PageCompRegistry.qml" | cut -d: -f1)
test "$focus_component_line" -lt "$appearance_component_line"
first_component=$(
  sed -n '/readonly property list<Component> pageComps: \[/,$p' \
    "$shell_root/modules/nexus/PageCompRegistry.qml" \
    | grep -m1 -A 2 'Component {'
)
printf '%s\n' "$first_component" | grep -Fq 'FocusHubPage {}'

# The page is a read-only view built from the existing Nexus primitives and
# semantic theme tokens.
for token in \
  'PageBase {' \
  'ConnectedRect {' \
  'SectionHeader {' \
  'InfoRow {' \
  'StyledText {' \
  'Tokens.padding' \
  'Tokens.spacing' \
  'Tokens.font' \
  'Colours.palette.m3primary' \
  'Colours.palette.m3secondary' \
  'Colours.palette.m3tertiary' \
  'Colours.palette.m3outline'; do
  grep -Fq "$token" "$focus_page"
done
! grep -E -q '#[0-9a-fA-F]{3,8}' "$focus_page"
mutable_properties=$(
  grep -E '^[[:space:]]*property[[:space:]]+' "$focus_page" \
    | grep -Ev '^[[:space:]]*readonly[[:space:]]+|^[[:space:]]*property[[:space:]]+alias' \
    || true
)
test -z "$mutable_properties"

for state in \
  'Hypr.activeToplevel' \
  'Hypr.focusedWorkspace' \
  'Hypr.focusedMonitor' \
  'Hypr.toplevels' \
  'Hypr.workspaces' \
  'Hypr.monitors'; do
  grep -Fq "$state" "$focus_page"
done
hypr_properties=$(grep -oE 'Hypr\.[A-Za-z][A-Za-z0-9]*' "$focus_page" | sort -u)
while IFS= read -r state; do
  case "$state" in
    Hypr.activeToplevel|Hypr.focusedWorkspace|Hypr.focusedMonitor|\
    Hypr.toplevels|Hypr.workspaces|Hypr.monitors) ;;
    *) exit 1 ;;
  esac
done <<< "$hypr_properties"

# No command, I/O, network, dynamic-theme, mutation, special-workspace, or
# destructive-window route may be introduced by this page or its registry patch.
! grep -E -i -q \
  'Process[[:space:]]*\{|FileView[[:space:]]*\{|Timer[[:space:]]*\{|IpcHandler[[:space:]]*\{|Quickshell\.exec|systemctl|shell[[:space:]]+command|network|wallpaper|matugen|pywal|dynamic[[:space:]_-]*(colou?r|theme)|config[[:space:]_-]*write|write[[:space:]_-]*config|special[[:space:]_-]*workspace|kill|destroy|dispatch|move[[:space:]]+window|(^|[^[:alpha:]])pin([^[:alpha:]]|$)|(^|[^[:alpha:]])float([^[:alpha:]]|$)|curl|wget|https?://' \
  "$focus_page" "$focus_patch"
! grep -E -i -q \
  'systemd|ExecStart|service|daemon|dependency|special[[:space:]_-]*workspace' \
  "$focus_patch"

# The focused check itself is wired to the real-greeter configuration, never
# the classic nixosConfigurations.nixos output.
grep -Fq 'realGreeterSystem' "$flake_nix"
grep -Fq 'nixos-caelestia-cryoforge-real-greeter' "$flake_nix"
! grep -Fq 'nixosConfigurations.nixos.' "$flake_nix"

# Phase 16D adds no application dependency, service, or background route.
phase16d_additions=$(
  {
    git -C "$repo_root" diff --unified=0 origin/main -- flake.nix \
      packages/caelestia-cryoforge.nix 2>/dev/null || true
  } | sed -n '/^+/p' | grep -v '^+++' || true
)
! printf '%s\n' "$phase16d_additions" \
  | grep -E -i -q 'systemd|ExecStart|service|daemon|dependency'

# Preserve the accepted Phase 13C, 16A, 16B, 16C, and 17A artifacts.
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
assert_sha256 "$repo_root/tests/phase13c/test_real_lock_contract.sh" \
  c98cfbaf54467346d744151ba6a974b12afa34089dddd3dcc9c4319128382927
assert_sha256 "$repo_root/tests/phase16a/test_chisa_preset_gallery_contract.sh" \
  af8f74f47f6242699fb9f780702665503675302a5adc8858a78f0e5a6bf8da87
assert_sha256 "$repo_root/tests/phase16b/test_window_feel_contract.sh" \
  36404c9299616c60afa7a66dda60e1d6da5c3fceb6d72db1bcfdbec520032fed
assert_sha256 "$repo_root/tests/phase16c/test_base_app_integration_contract.sh" \
  620cab3456057a7e6ceb9f93c61a014e8eb9ac771210d331f2d803c8fb9ed844
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

# Match the repository's source-format and parser checks for both source and
# rendered copies.
qmlformat "$focus_page" | diff -u "$focus_page" -
qmlformat "$shell_root/modules/nexus/pages/FocusHubPage.qml" \
  | diff -u "$shell_root/modules/nexus/pages/FocusHubPage.qml" -
qmllint --bare --max-warnings 9999 \
  -I "$shell_root" \
  "$focus_page" >/dev/null
qmllint --bare --max-warnings 9999 \
  -I "$shell_root" \
  "$shell_root/modules/nexus/pages/FocusHubPage.qml" >/dev/null

printf '%s\n' 'phase16d Nexus Focus Hub contract tests: pass'
