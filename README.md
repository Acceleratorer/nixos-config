# nixos-config

Personal NixOS configuration for an ASUS laptop with AMD+NVIDIA hybrid graphics, running NixOS 26.05 with Hyprland as the primary compositor.

## Overview

| Property | Value |
|---|---|
| NixOS channel | 26.05 (pinned) |
| Architecture | x86_64-linux |
| Window manager | Hyprland (Wayland) |
| Display manager | greetd + regreet |
| User config | Home Manager (release-26.05) |

## Structure

```
.
├── flake.nix                  # Inputs and system outputs
├── configuration.nix          # System-level NixOS config
├── hardware-configuration.nix # Hardware scan output
├── desktop-hyprland.nix       # Hyprland setup, portals, packages, systemd services
├── home.nix                   # Home Manager entrypoint
├── desktop/
│   ├── profiles.nix           # CryoForge desktop profile system (classic / caelestia)
│   ├── palette.nix            # Shared colour tokens
│   ├── wallpaper.svg          # Source for the generated fallback wallpaper
│   ├── caelestia/             # Caelestia shell config
│   ├── hypr/                  # Hyprland, hyprlock, hypridle configs
│   ├── kitty/                 # Kitty terminal config
│   ├── mako/                  # Mako notification daemon config
│   ├── rofi/                  # Rofi launcher config (forced X11 backend)
│   └── waybar/                # Waybar status bar config
├── asusd/
│   └── aura_1866.ron          # ASUS Aura RGB config for product ID 1866
├── packages/
│   ├── hyprexpo.nix           # Hyprland workspaces overview plugin (pinned v0.55.4)
│   └── codex.nix              # Codex CLI package
└── docs/
    └── luks-secure-boot-migration.md
```

## Desktop profiles

Desktop component ownership is controlled by the `nixosCryoforge.desktopProfile` option in `home.nix`. Change the value, rebuild, then start a new Hyprland session.

| Profile | Components |
|---|---|
| `classic` (default) | Waybar, Mako, hyprpaper, hypridle, SwayOSD |
| `caelestia` | Caelestia shell (Quickshell-based); falls back to `classic` on failure |

## Hardware notes

- **AMD iGPU**: display/primary GPU side (PCI 6:0:0)
- **NVIDIA dGPU**: configured for PRIME offload (PCI 1:0:0), using the open kernel module and fine-grained power management
  - Dynamic Boost is disabled pending hardware/runtime validation
- **ASUS services**: `asusd` (fan/Aura control) and `supergfxd` (GPU switching)
- GNOME is exposed as a recovery session; Hyprland is the default session and GDM is disabled

## Known limitations

The personal wallpaper, lock background, lock overlay, and avatar currently live outside Git under the user's home directory. Repair 6 is required before those assets are reproducible on a fresh install. `desktop/wallpaper.svg` provides a generated fallback, but it is not the active wallpaper configured for the current Hyprland setup.

## Applying changes

```bash
# Preview what will change
sudo nixos-rebuild dry-activate --flake .#nixos

# Apply to the running system
sudo nixos-rebuild switch --flake .#nixos

# Build without activating
sudo nixos-rebuild build --flake .#nixos
```

The flake pins `nixpkgs` to a specific NixOS 26.05 tarball and `home-manager` to its matching release branch. Update `flake.lock` deliberately with `nix flake update`.

## Nix settings

- Flakes and `nix-command` experimental features are enabled
- Garbage collection runs weekly (Sundays 03:15, keeps last 30 days)
- Store optimisation runs weekly (Mondays 03:45)
- Unfree packages are allowed

## Docs

- [`docs/luks-secure-boot-migration.md`](docs/luks-secure-boot-migration.md) — guide for adding LUKS2 full-disk encryption and Secure Boot to an existing installation
