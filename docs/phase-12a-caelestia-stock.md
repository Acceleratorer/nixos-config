# Phase 12A — Caelestia Stock Foundation

This profile is a reproducible, stock Caelestia foundation. It keeps the
existing `classic` profile and experimental `caelestia` profile distinct; the
new identity is `caelestia-stock`, selected only by the
`nixos-caelestia-stock` system output.

## Pinned source tuple

- Caelestia dots: `caelestia-dots/caelestia`
  `a6ed1e5e831aba9aac46265ae156db4fab2b9e43`
- Caelestia Shell: `caelestia-dots/shell`
  `817a220e8e87c4df9f3681033a0d8a8054cdaa30`
- Caelestia CLI: `751fbc555a83faba5dd589270d14eeb22afab174`, locked by the
  Shell input
- Quickshell: `28771c7c74b42e20afca0b1b63980cb46515537c`, locked by the Shell
  input

The Shell `with-cli` package is used. CLI and Quickshell are not independent
root inputs and are not floated by this configuration.

## Immutable and writable boundaries

The upstream Hyprland Lua tree is installed as individual store-backed files.
The `hypr` directory itself remains a normal user directory. Upstream files
are preserved byte-for-byte except for the two Nix integration adapters
described below.

Home Manager seeds these missing regular files with mode `0600`:

- `~/.config/caelestia/shell.json`
- `~/.config/caelestia/shell-tokens.json`
- `~/.config/caelestia/cli.json`
- `~/.config/caelestia/hypr-vars.lua`
- `~/.config/caelestia/hypr-user.lua`
- `~/.config/hypr/scheme/current.lua`

Missing configuration directories are created with mode `0700`. Existing
regular files and symlinks are left alone. `monitors/`, `templates/`,
`~/.local/state/caelestia/`, `~/.cache/caelestia/`, and `~/.face` remain
runtime-writable; no declarative link is used for their mutable contents.

The seeded CLI policy keeps only the Hyprland Lua colour relationship enabled.
Terminal, Discord, Spicetify, Pandora, Fuzzel, btop/nvtop/htop, GTK, Qt,
Warp, Chromium, Zed, and Cava integration are explicitly disabled. No
passwordless sudo or `/etc` write policy is configured.

## Daemon ownership

| Component | Caelestia Stock owner | Classic owner / shared owner |
| --- | --- | --- |
| Shell, notifications, wallpaper, OSD, lock UI, idle timeouts | `caelestia.service` and the stock Shell | Classic does not start the stock target |
| Clipboard history | `caelestia-clipboard-text.service` and `caelestia-clipboard-image.service` | Classic Hyprland config |
| Trash cleanup | `caelestia-trash-cleanup.service` | None |
| GeoClue demo agent | `caelestia-geoclue-agent.service` | GeoClue system service is shared |
| Gammastep | `caelestia-gammastep.service` | None |
| Bluetooth MPRIS proxy | `caelestia-mpris-proxy.service` | BlueZ is shared |
| Polkit agent | Existing `hyprland-polkit-agent.service` | Shared Nix-native unit |
| GNOME Keyring | NixOS GNOME Keyring | Shared NixOS service |
| PipeWire, NetworkManager, BlueZ, portals | Existing NixOS services | Shared infrastructure |
| Waybar, Mako, hyprpaper, hypridle, SwayOSD | Not started; stock target conflicts with them | Classic target |

The stock target conflicts with Classic, the experimental Caelestia target,
and all five Classic-owned user services. It is the only stock notification,
Shell, idle/lock, wallpaper, and OSD owner.

## Nix startup adaptations

`hypr/hyprland.lua` no longer performs runtime file seeding. Home Manager is
the sole seed owner. Its Lua module path includes the normal
`~/.config/hypr` directory so an individually store-backed `hyprland.lua` can
load its sibling modules. Upstream variables, rules, keybinds, gestures,
animations, and user overrides remain intact.

`hypr/hyprland/execs.lua` removes Arch-specific or duplicated startup for
keyring, Polkit, clipboard watchers, GeoClue, Gammastep, MPRIS, trash cleanup,
and Shell startup. It keeps upstream cursor setup, adds the Nix session
preparation adapter, and stops the session target on the upstream
`hyprland.shutdown` event. The upstream title/open resizer listeners remain
unchanged.

The Shell is started by its systemd user service, not by `execs.lua`. The
upstream keybind actions remain stock; their manual restart actions are not
startup ownership.

## Why upstream installers are not used

`caelestia install`, `caelestia update`, Arch/AUR tooling, and upstream setup
scripts are intentionally not run. They mutate user configuration, state,
system packages, and/or `/etc`, which would bypass Nix's pinned source and
ownership model.

`dots-hyprland` is read-only architectural reference material only. It is not
a runtime dependency and no code is copied from it.

## Future boundary

Phase 12A keeps the GPLv3 Caelestia Shell QML untouched and byte-identical to
the pinned upstream source. Upstream CMake changes `settings.watchFiles` while
installing `shell.qml`; the Nix derivation copies the pristine source file over
that generated installation result without patching or substituting QML.
Future CryoForge visual work belongs behind a separate GPLv3 CryoForge Shell
fork boundary; it must not be represented as substitutions in this stock
profile.

## Deferred runtime checks

Runtime-only checks remain for Phase 12B: actual Hyprland Lua provider status,
WlSessionLock/PAM authentication and unlock behavior, systemd target
transitions, GeoClue/Gammastep availability, clipboard watcher lifetime,
notification ownership on D-Bus, and Shell/Nexus auto-save behavior. This
phase performs build and static checks only and does not activate or test-run
the profile.
