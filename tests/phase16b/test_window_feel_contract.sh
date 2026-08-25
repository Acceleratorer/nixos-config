#!/usr/bin/env bash

set -euo pipefail

cryoforge_vars=${1:?missing CryoForge variables}
cryoforge_general=${2:?missing CryoForge general config}
cryoforge_decoration=${3:?missing CryoForge decoration config}
cryoforge_animations=${4:?missing CryoForge animations}
cryoforge_rules=${5:?missing CryoForge rules}
cryoforge_execs=${6:?missing CryoForge execs}
cryoforge_functions=${7:?missing CryoForge functions}
cryoforge_keybinds=${8:?missing CryoForge keybinds}
cryoforge_gestures=${9:?missing CryoForge gestures}
stock_vars=${10:?missing stock variables}
stock_decoration=${11:?missing stock decoration}
stock_animations=${12:?missing stock animations}
stock_rules=${13:?missing stock rules}
stock_functions=${14:?missing stock functions}
stock_keybinds=${15:?missing stock keybinds}
stock_gestures=${16:?missing stock gestures}
upstream_root=${17:?missing pinned Caelestia dots}
classic_config=${18:?missing classic Hyprland config}
profiles_nix=${19:?missing desktop profiles expression}
flake_nix=${20:?missing flake expression}
special_patch=${21:?missing accepted special-workspace patch}
region_patch=${22:?missing region screenshot patch}
region_script=${23:?missing region screenshot script}
gallery_patch=${24:?missing Chisa gallery patch}
cryoforge_package=${25:?missing CryoForge package expression}

for file in \
  "$cryoforge_vars" \
  "$cryoforge_general" \
  "$cryoforge_decoration" \
  "$cryoforge_animations" \
  "$cryoforge_rules" \
  "$cryoforge_execs" \
  "$cryoforge_functions" \
  "$cryoforge_keybinds" \
  "$cryoforge_gestures" \
  "$stock_vars" \
  "$stock_decoration" \
  "$stock_animations" \
  "$stock_rules" \
  "$stock_functions" \
  "$stock_keybinds" \
  "$stock_gestures" \
  "$classic_config" \
  "$profiles_nix" \
  "$flake_nix" \
  "$special_patch" \
  "$region_patch" \
  "$region_script" \
  "$gallery_patch" \
  "$cryoforge_package"; do
  test -r "$file"
done

same_file() {
  test "$(sha256sum "$1" | cut -d ' ' -f 1)" = \
    "$(sha256sum "$2" | cut -d ' ' -f 1)"
}

# Phase 16B is a guarded CryoForge-only source transformation. Stock remains
# byte-for-byte pinned upstream, and classic retains its independent config.
same_file "$stock_vars" "$upstream_root/hypr/variables.lua"
same_file "$stock_decoration" "$upstream_root/hypr/hyprland/decoration.lua"
same_file "$stock_animations" "$upstream_root/hypr/hyprland/animations.lua"
same_file "$stock_rules" "$upstream_root/hypr/hyprland/rules.lua"
same_file "$stock_functions" "$upstream_root/hypr/utils/functions.lua"
same_file "$stock_keybinds" "$upstream_root/hypr/hyprland/keybinds.lua"
same_file "$stock_gestures" "$upstream_root/hypr/hyprland/gestures.lua"
same_file "$cryoforge_general" "$upstream_root/hypr/hyprland/general.lua"
! grep -Fq 'activeWindowOpacity' "$stock_vars"
! grep -Fq 'specialWorkspaceDim' "$stock_vars"
! grep -Fq 'activeWindowOpacity' "$classic_config"
! grep -Fq 'specialWorkspaceDim' "$classic_config"

# Geometry and focus treatment.
grep -Fqx '    workspaceGaps              = 20,' "$cryoforge_vars"
grep -Fqx '    windowGapsIn               = 6,' "$cryoforge_vars"
grep -Fqx '    windowGapsOut              = 12,' "$cryoforge_vars"
grep -Fqx '    singleWindowGapsOut        = 18,' "$cryoforge_vars"
grep -Fqx '    windowRounding             = 14,' "$cryoforge_vars"
grep -Fqx '    windowBorderSize           = 2,' "$cryoforge_vars"
grep -Fq 'gaps_workspaces = vars.workspaceGaps' "$cryoforge_general"
grep -Fq 'gaps_in         = vars.windowGapsIn' "$cryoforge_general"
grep -Fq 'gaps_out        = vars.windowGapsOut' "$cryoforge_general"
grep -Fq 'border_size     = vars.windowBorderSize' "$cryoforge_general"
grep -Fq '"rgba(" .. scheme.term10 .. "f2)"' "$cryoforge_vars"
grep -Fq '"rgba(" .. scheme.term13 .. "e6)"' "$cryoforge_vars"
grep -Fqx '        angle = 45,' "$cryoforge_vars"
grep -Fq 'scheme.outlineVariant' "$cryoforge_vars"

# Near-solid application opacity is global, while protected classes override
# every state to 1.0. There is no blanket upstream 0.95 window rule.
grep -Fqx '    activeWindowOpacity        = 1.0,' "$cryoforge_vars"
grep -Fqx '    inactiveWindowOpacity      = 0.98,' "$cryoforge_vars"
grep -Fqx '    fullscreenWindowOpacity    = 1.0,' "$cryoforge_vars"
grep -Fqx '    opaqueWindowOpacity        = "1.0 override 1.0 override 1.0 override",' "$cryoforge_vars"
grep -Fq 'active_opacity     = vars.activeWindowOpacity' "$cryoforge_decoration"
grep -Fq 'inactive_opacity   = vars.inactiveWindowOpacity' "$cryoforge_decoration"
grep -Fq 'fullscreen_opacity = vars.fullscreenWindowOpacity' "$cryoforge_decoration"
! grep -Eq 'windowOpacity|0\.95[[:space:]]+override|fullscreen[[:space:]]*=[[:space:]]*false.*opacity' "$cryoforge_rules"

fullscreen_block=$(sed -n '/-- Fullscreen content is gapless/,/^})/p' "$cryoforge_rules")
printf '%s\n' "$fullscreen_block" | grep -Fq 'match       = { fullscreen = true }'
printf '%s\n' "$fullscreen_block" | grep -Fq 'border_size = 0'
printf '%s\n' "$fullscreen_block" | grep -Fq 'rounding    = 0'
printf '%s\n' "$fullscreen_block" | grep -Fq 'no_shadow   = true'
printf '%s\n' "$fullscreen_block" | grep -Fq 'no_blur     = true'
printf '%s\n' "$fullscreen_block" | grep -Fq 'opacity     = vars.opaqueWindowOpacity'
grep -Fq 'workspace = "w[tv1]s[false]", gaps_out = vars.singleWindowGapsOut' "$cryoforge_rules"
grep -Fq 'workspace = "f[1]s[false]", gaps_out = vars.singleWindowGapsOut' "$cryoforge_rules"

# Blur and shadow remain bounded, neutral, and disabled for opaque content.
blur_size=$(sed -nE 's/^[[:space:]]*blurSize[[:space:]]*=[[:space:]]*([0-9]+),$/\1/p' "$cryoforge_vars")
blur_passes=$(sed -nE 's/^[[:space:]]*blurPasses[[:space:]]*=[[:space:]]*([0-9]+),$/\1/p' "$cryoforge_vars")
test -n "$blur_size"
test -n "$blur_passes"
test "$blur_size" -le 8
test "$blur_passes" -le 2
grep -Fqx '    blurEnabled                = true,' "$cryoforge_vars"
grep -Fqx '    blurXray                   = false,' "$cryoforge_vars"
grep -Fqx '    blurSpecialWs              = false,' "$cryoforge_vars"
grep -Fqx '    blurPopups                 = true,' "$cryoforge_vars"
grep -Fqx '    blurInputMethods           = true,' "$cryoforge_vars"
grep -Fq 'ignore_opacity    = false' "$cryoforge_decoration"
grep -Fqx '    shadowRange                = 10,' "$cryoforge_vars"
grep -Fqx '    shadowRenderPower          = 3,' "$cryoforge_vars"
grep -Fq 'scheme.shadow' "$cryoforge_vars"
! grep -Fq 'scheme.inversePrimary' "$cryoforge_vars"

opaque_block=$(sed -n '/create_tag(opaque_tag, {/,/^})/p' "$cryoforge_rules")
game_block=$(sed -n '/create_tag(game_tag, {/,/^})/p' "$cryoforge_rules")
xwl_block=$(sed -n '/create_tag(xwl_popup_tag, {/,/^})/p' "$cryoforge_rules")
for block in "$opaque_block" "$game_block" "$xwl_block"; do
  printf '%s\n' "$block" | grep -Fq 'opaque'
  printf '%s\n' "$block" | grep -Fq 'no_blur'
  printf '%s\n' "$block" | grep -Fq 'opacity'
done
grep -Fq '"foot|kitty"' "$cryoforge_rules"
grep -Fq '"org.quickshell"' "$cryoforge_rules"
grep -Fq '"feh|imv|swappy"' "$cryoforge_rules"
grep -Fq '"krita|gimp|inkscape|darktable"' "$cryoforge_rules"
grep -Fq '"resolve|kdenlive|shotcut"' "$cryoforge_rules"
grep -Fq '"steam_app_[0-9]+"' "$cryoforge_rules"
grep -Fq '"gamescope"' "$cryoforge_rules"

# Authentication and utility floaters are narrowly matched, centered where
# appropriate, monitor-relative, opaque, and protected from compositor blur.
grep -Fq '{ class = "polkit-gnome-authentication-agent-1" }' "$cryoforge_rules"
grep -Fq '{ class = "Bitwarden" }' "$cryoforge_rules"
grep -Fq '{ title = "^(Authentication Required|Authenticate|Password Required)$" }' "$cryoforge_rules"
protected_block=$(sed -n '/create_tag(protected_dialog_tag, {/,/^})/p' "$cryoforge_rules")
printf '%s\n' "$protected_block" | grep -Fq 'float'
printf '%s\n' "$protected_block" | grep -Fq 'center'
printf '%s\n' "$protected_block" | grep -Fq 'opaque'
printf '%s\n' "$protected_block" | grep -Fq 'no_blur'
grep -Fq '{ class = "[Tt]hunar", title = "File (Operation|Upload)( Progress)?" }' "$cryoforge_rules"
grep -Fq '{ class = "[Tt]hunar", title = ".* Properties" }' "$cryoforge_rules"
grep -Fq '"(Select|Open)( a)? (File|Folder)(s)?"' "$cryoforge_rules"
grep -Fq '"Save As"' "$cryoforge_rules"
grep -Fq '{ title = "(Save|Export) Image", class = "gimp" }' "$cryoforge_rules"
grep -Fq '"org.pulseaudio.pavucontrol|com.saivert.pwvucontrol"' "$cryoforge_rules"
grep -Fq '"org.gnome.FileRoller|file-roller"' "$cryoforge_rules"
grep -Fq '"blueman-manager"' "$cryoforge_rules"
grep -Fq '{ class = "steam", title = "Friends List" }' "$cryoforge_rules"
grep -Fq '{ class = "com-atlauncher-App", title = "ATLauncher Console" }' "$cryoforge_rules"
grep -Fq '{ class = "PandoraLauncher",    title = "Minecraft Game Output" }' "$cryoforge_rules"
! grep -Fq '"Library"' "$cryoforge_rules"
! grep -Fq 'match = { float = true, xwayland = false }' "$cryoforge_rules"
printf '%s\n' "$xwl_block" | grep -Fq 'no_shadow'
printf '%s\n' "$xwl_block" | grep -Fq 'no_dim'
! printf '%s\n' "$xwl_block" | grep -Fq 'center'

# PiP remains one title-triggered route. The existing resizer explicitly
# targets the matched window and now uses that window's monitor.
pip_rule=$(sed -n '/-- Picture in picture/,/^})/p' "$cryoforge_rules")
printf '%s\n' "$pip_rule" | grep -Fq 'title = "Picture(-| )in(-| )[Pp]icture"'
printf '%s\n' "$pip_rule" | grep -Fq 'move              = "(monitor_w*0.97-window_w) (monitor_h*0.97-window_h)"'
printf '%s\n' "$pip_rule" | grep -Fq 'pin               = true'
printf '%s\n' "$pip_rule" | grep -Fq 'float             = true'
printf '%s\n' "$pip_rule" | grep -Fq 'keep_aspect_ratio = true'
printf '%s\n' "$pip_rule" | grep -Fq 'no_blur           = true'
grep -Fq 'fn.resizer(win, "Picture[- ]in[- ][Pp]icture", 0, 0, pip_actions, false)' "$cryoforge_execs"

move_block=$(sed -n '/local function move_actions(win)/,/^end/p' "$cryoforge_functions")
printf '%s\n' "$move_block" | grep -Fq 'local screen = win and win.monitor or nil'
printf '%s\n' "$move_block" | grep -Fq '(monitor_height / 4)'
printf '%s\n' "$move_block" | grep -Fq 'math.max(200, target_width)'
printf '%s\n' "$move_block" | grep -Fq 'math.max(150, target_height)'
printf '%s\n' "$move_block" | grep -Fq '* 0.03'
printf '%s\n' "$move_block" | grep -Fq 'window = win'
! printf '%s\n' "$move_block" | grep -Fq 'get_active_monitor'
grep -Fq 'sz.window = window' "$cryoforge_functions"
grep -Fq 'window = window }))' "$cryoforge_functions"
! grep -E -q 'HDMI|DP-[0-9]|eDP-[0-9]' "$cryoforge_rules" "$cryoforge_functions" "$cryoforge_keybinds"

manual_pip=$(sed -n '/create_bind(vars.kbWindowPip/,/^end)/p' "$cryoforge_keybinds")
printf '%s\n' "$manual_pip" | grep -Fq 'local pip = fn.move_actions(a) or {}'
printf '%s\n' "$manual_pip" | grep -Fq 'hl.dsp.window.float({ action = "on", window = a })'
printf '%s\n' "$manual_pip" | grep -Fq 'hl.dsp.window.pin({ action = "on", window = "address:" .. a.address })'
grep -Fqx 'create_bind(vars.kbPinWindow, hl.dsp.window.pin())' "$cryoforge_keybinds"

# Exact live Caelestia namespaces are separated. The area picker and border
# exclusion retain no-animation behavior; background, lock, and selection
# surfaces receive no compositor blur.
grep -Fq 'namespace = "caelestia-(border-exclusion|area-picker)" }, no_anim = true' "$cryoforge_rules"
grep -Fq 'namespace = "caelestia-drawers" }, animation = "fade"' "$cryoforge_rules"
grep -Fq 'namespace = "caelestia-background" }, animation = "fade"' "$cryoforge_rules"
! grep -Fq 'caelestia-(drawers|background)' "$cryoforge_rules"
! grep -E -q 'namespace = "caelestia-(border-exclusion|area-picker|background)".*blur = true' "$cryoforge_rules"
! grep -E -q 'namespace = ".*(lock|auth).*".*blur = true' "$cryoforge_rules"
grep -Fq 'namespace = "selection" }, animation = "fade"' "$cryoforge_rules"
grep -Fq 'namespace = "wayfreeze" }, animation = "fade"' "$cryoforge_rules"

# Special-workspace compositor polish is calm and bounded. The accepted
# CryoForge rejection state remains unchanged: upstream names/config survive,
# while its routed binds, gestures, and bar indicators remain suppressed.
grep -Fqx '    specialWorkspaceDim        = 0.10,' "$cryoforge_vars"
grep -Fq 'dim_special        = vars.specialWorkspaceDim' "$cryoforge_decoration"
grep -Fq 'leaf    = "specialWorkspaceIn"' "$cryoforge_animations"
grep -Fq 'leaf    = "specialWorkspaceOut"' "$cryoforge_animations"
grep -Fq 'style   = "slidefadevert 10%"' "$cryoforge_animations"
grep -Fq 'bezier  = "specialWorkSwitch"' "$cryoforge_animations"
grep -Fq 'bezier  = "specialWorkExit"' "$cryoforge_animations"
! grep -E -i -q 'bounce|wobble|rotate|rotation|spring|overshoot' "$cryoforge_animations"
! grep -Fq 'keyword' "$cryoforge_animations"

for name in special sysmon music communication todo; do
  grep -Fq "$name" "$cryoforge_vars" "$cryoforge_functions"
done
grep -Fq 'name = "special:sysmon"' "$cryoforge_functions"
grep -Fq 'special_workspace == "specialws"' "$cryoforge_functions"
! grep -Fq 'create_bind(vars.kbSpecialWs' "$cryoforge_keybinds"
! grep -Fq 'workspace = "special:sysmon"' "$cryoforge_rules"
! grep -Fq 'workspace_name = "special"' "$cryoforge_gestures"
grep -Fq 'replaceExactly "keybinds.lua special-workspace toggles" keybindsToggleSpecial ""' "$profiles_nix"
grep -Fq 'replaceExactly "rules.lua special-workspace routing" rulesSpecialRouting ""' "$profiles_nix"
grep -Fq 'replaceExactly "gestures.lua special-workspace actions" gesturesSpecialActions ""' "$profiles_nix"

# Protected phase artifacts and absence contracts.
test "$(sha256sum "$special_patch" | cut -d ' ' -f 1)" = \
  738cc7cccca63d09cedc88889f6a5374111cd015d2f76a560c9f9180265d927d
test "$(sha256sum "$region_patch" | cut -d ' ' -f 1)" = \
  6db4facdd61b639abca962b147b9e4a1bd6bb3a849a24a9a12440decb483fc83
test "$(sha256sum "$region_script" | cut -d ' ' -f 1)" = \
  b5ce59848a0750dc94f68baf2ebce15f72c727315c6e7d79fca5fb5c2cd2d495
test "$(sha256sum "$gallery_patch" | cut -d ' ' -f 1)" = \
  0b73f3dc7fd093e4d5b167079c2a8f80fcf08e6791cb4855e55bbe983ccaf877
test "$(sha256sum "$cryoforge_package" | cut -d ' ' -f 1)" = \
  eba2358673c4b316464ed80c8aebef271fc7bf00dc421760a58509d1bea4d312
! grep -E -i -q 'phase.?15a' "$profiles_nix" "$flake_nix" "$cryoforge_package"
! grep -E -i -q 'gammastep|night.?light' "$cryoforge_execs" "$profiles_nix"
! grep -E -i -q 'hyprpm|curl|wget|https?://|plugin[[:space:]]*=' \
  "$cryoforge_vars" \
  "$cryoforge_decoration" \
  "$cryoforge_animations" \
  "$cryoforge_rules" \
  "$cryoforge_functions" \
  "$cryoforge_keybinds"

printf '%s\n' 'phase16b CryoForge window feel contract tests: pass'
