# CryoForge NixOS configuration

CryoForge is a personal, declarative NixOS and Hyprland configuration for one
ASUS laptop with an AMD display GPU and an NVIDIA offload GPU. It is not a
general-purpose NixOS distribution or a portable hardware profile.

> [!IMPORTANT]
> Review the username, filesystem declarations, NVIDIA PRIME bus IDs, ASUS
> Aura product ID, display assumptions, and recovery access before using this
> repository on another machine. Build success does not prove that the
> configuration is safe for different hardware.

## Stack and current target

The flake pins the NixOS 26.05 release stack for `x86_64-linux`, with Home
Manager following `release-26.05`. Hyprland is the graphical session, and the
Caelestia inputs are pinned to immutable revisions.

The current development and build target is:

```text
nixos-caelestia-cryoforge-real-greeter
```

This identifies the repository target. It does not claim that the running
system or boot profile currently uses that output.

## Flake outputs

[`flake.nix`](flake.nix) exports four NixOS configurations:

| Output | Purpose |
| --- | --- |
| `nixos` | Classic recovery and fallback desktop |
| `nixos-caelestia-stock` | Pinned Caelestia Stock profile with Nix-owned integration |
| `nixos-caelestia-cryoforge` | Caelestia CryoForge desktop with the accepted ReGreet login |
| `nixos-caelestia-cryoforge-real-greeter` | Current target: Caelestia CryoForge with the real Caelestia cold-login greeter and ReGreet recovery |

## Desktop profiles

The supported desktop profiles are defined in
[`desktop/profiles.nix`](desktop/profiles.nix):

| Profile | Role |
| --- | --- |
| Classic (`classic`) | Recovery and fallback path using Waybar, Mako, hyprpaper, hypridle, and SwayOSD |
| Pinned Caelestia Stock (`caelestia-stock`) | Pinned upstream Caelestia shell and Hyprland sources with bounded Nix integration |
| Caelestia CryoForge (`caelestia-cryoforge`) | The pinned stock foundation plus guarded CryoForge shell, window-feel, gallery, screenshot, and application-base changes |

Profile targets conflict with one another so that two bars, notification
owners, wallpaper owners, or shell stacks do not intentionally run at the
same time. Classic remains available when the Caelestia path cannot be used.

## Authentication and security boundaries

Login and locking are separate systems:

| Boundary | Implementation |
| --- | --- |
| Cold login | `greetd` launches the real Caelestia greeter as the unprivileged `greeter` user |
| Login recovery | ReGreet remains available through the real-greeter recovery path |
| Logged-in session lock | Caelestia uses `WlSessionLock` surfaces and PAM; the CryoForge lock binding enters the Caelestia lock IPC path |

The cold-login package does not contain the session-lock API, and the
session-lock package does not authenticate through `greetd` or ReGreet. This
separation is enforced by the lock and greeter contracts.

This repository does **not** claim Secure Boot, disk encryption, or encrypted
swap. The current hardware declaration uses a plain ext4 root filesystem and
a separate plain swap device. The
[`docs/luks-secure-boot-migration.md`](docs/luks-secure-boot-migration.md)
document is a future migration plan, not a description of protections already
enabled.

## Accepted functionality

The current repository baseline includes:

- packaged Chisa Pool wallpaper and avatar assets used by the CryoForge shell,
  greeter, and lock presentation;
- a finite, manual Chisa gallery containing the approved Chisa Pool preset,
  with temporary preview and an explicit **Apply** action;
- quiet Plymouth boot using the `bgrt` theme and conservative console logging;
- the accepted CryoForge window-feel policy;
- one unified region screenshot flow;
- a stable, neutral Kitty and Fastfetch base;
- complete removal of Gammastep and night-light startup from the current
  CryoForge profile;
- a Classic recovery and fallback path.

These items are accepted in source and covered by repository checks. This
status does not describe the active system or its selected boot generation.

## Screenshot workflow

In Caelestia CryoForge, <kbd>Print</kbd> opens region selection through the
Caelestia screenshot action and the packaged region helper.

- Select the whole output when a full-screen capture is wanted.
- Cancelling selection, or returning an empty selection, exits without taking
  a screenshot, changing the clipboard, creating the screenshot cache
  directory, or showing a success notification.
- A successful selection is captured into the Caelestia screenshot cache,
  copied to the clipboard, and announced with a **Screenshot taken**
  notification.
- The notification's **Open** action opens the cached image in Swappy.
- The **Save** action moves the image to
  `$CAELESTIA_SCREENSHOTS_DIR` when set, otherwise to
  `$XDG_PICTURES_DIR/Screenshots`, with `~/Pictures/Screenshots` as the final
  fallback. A second notification reports the saved path.
- Dismissing the first notification leaves the capture in the cache and its
  image data on the clipboard.

The area-picker open action and screenshot IPC action share this same helper.

## Neutral application base

[`desktop/palette.nix`](desktop/palette.nix) is a fixed,
wallpaper-independent semantic palette:

| Name | Value |
| --- | --- |
| `background` | `#05070d` |
| `surface` | `#0a1020` |
| `surfaceElevated` | `#111a2e` |
| `foreground` | `#dcebff` |
| `muted` | `#8193ab` |
| `accent` | `#77b6e1` |
| `accentForeground` | `#05070d` |
| `border` | `#4d6fb7` |
| `focus` | `#00e5ff` |
| `success` | `#4dd4ac` |
| `warning` | `#f2c66d` |
| `error` | `#ff637f` |

The CryoForge profile uses these tokens to seed neutral Kitty and Fastfetch
configuration only when the corresponding user file is missing:

- `~/.config/kitty/kitty.conf`
- `~/.config/fastfetch/config.jsonc`

Existing files and symlinks win. The activation logic does not overwrite,
replace, or forcibly migrate user-owned Kitty or Fastfetch configuration.
Kitty receives an opaque neutral terminal theme with visible focus cues;
Fastfetch uses the built-in compact NixOS logo and declarative system modules.

Phrolova is not installed. The inspected source is Windows/macOS cursor data,
not a Linux Xcursor theme, so no Phrolova package or cursor route was added.

## CryoForge window feel

The accepted CryoForge-only compositor values are:

| Setting | Value |
| --- | ---: |
| Inner gaps | `6` |
| Outer gaps | `12` |
| Single-window outer gaps | `18` |
| Border size | `2` |
| Rounding | `14` |
| Blur size | `6` |
| Blur passes | `2` |
| Blur xray | off |
| Active opacity | `1.0` |
| Inactive opacity | `0.98` |
| Fullscreen opacity | `1.0` |
| Special-workspace dim | `0.10` |

Fullscreen and protected content receive stricter opaque, unblurred rules.
Caelestia Stock remains pinned to its upstream values, and Classic keeps its
independent Hyprland configuration.

## Repository architecture

Important paths:

- [`flake.nix`](flake.nix) pins inputs, defines packages and checks, and
  exports the four NixOS configurations.
- [`configuration.nix`](configuration.nix) contains machine-level NixOS
  configuration and imports the generated hardware declaration.
- [`hardware-configuration.nix`](hardware-configuration.nix) is specific to
  this laptop's filesystems and platform.
- [`desktop-hyprland.nix`](desktop-hyprland.nix) owns Hyprland system
  integration, PAM registration, portals, packages, and shared session units.
- [`home.nix`](home.nix) connects Home Manager to the selected desktop
  profile.
- [`desktop/profiles.nix`](desktop/profiles.nix) owns profile targets,
  Caelestia service boundaries, guarded Hyprland adaptations, and missing-file
  seeding.
- [`desktop/palette.nix`](desktop/palette.nix) and
  [`desktop/apps/`](desktop/apps/) define the neutral application base.
- [`desktop/caelestia/`](desktop/caelestia/) contains Chisa assets, guarded
  shell patches, the screenshot helper, and real-greeter sources.
- [`desktop/hypr/`](desktop/hypr/) and the other classic desktop directories
  provide the independent Classic recovery environment.
- [`desktop/regreet/`](desktop/regreet/) packages the accepted ReGreet
  recovery presentation.
- [`packages/`](packages/) contains derivations for the CryoForge shell,
  Chisa assets and previews, the real greeter, the real lock contract, Codex,
  and Hyprexpo.
- [`tests/`](tests/) contains focused contracts for the lock boundary, Chisa
  gallery, window feel, neutral application base, and screenshot flow.
- [`docs/`](docs/) contains migration guidance and historical phase notes;
  source and current contracts take precedence when an older note describes
  an earlier state.

## Build and activation

Run checks and build the current target without changing the running system:

```bash
nix flake check --offline
```

```bash
nix build --offline --no-link --print-out-paths \
  path:.#nixosConfigurations.nixos-caelestia-cryoforge-real-greeter.config.system.build.toplevel
```

After reviewing the build, a privileged test activation is:

```bash
sudo nixos-rebuild test \
  --flake path:.#nixos-caelestia-cryoforge-real-greeter \
  --no-write-lock-file
```

To make the evaluated generation available as the next boot default without
switching the currently running system:

```bash
sudo nixos-rebuild boot \
  --flake path:.#nixos-caelestia-cryoforge-real-greeter \
  --no-write-lock-file
```

The commands have different effects:

- `nix flake check --offline` evaluates the flake and runs its checks without
  activating a system.
- `nix build --offline --no-link` builds the system closure but performs no
  activation and no boot-profile change.
- `nixos-rebuild test` activates the candidate for the running system but
  does not select it as the boot default; rebooting returns to the configured
  boot generation.
- `nixos-rebuild boot` selects the generation for a future boot but does not
  activate it in the current session.

The commands use `path:.` so local tracked changes are evaluated without
mutating `flake.lock`.

## Non-destructive recovery

- Keep a working terminal or TTY open during any test activation.
- Build first, then use `nixos-rebuild test` before considering
  `nixos-rebuild boot`.
- If a test activation is unusable, reboot into the unchanged boot default or
  choose a known-good generation from systemd-boot. Do not delete working
  generations while evaluating a candidate.
- At cold login, use the real greeter's recovery action to return to ReGreet.
- If the Caelestia desktop path is unavailable, use the `nixos` output or the
  Classic profile as the recovery desktop.
- Treat the LUKS and Secure Boot document as a separate offline migration. It
  is not a live-system repair procedure.

## Status and roadmap

Completed:

- authentication architecture;
- Chisa gallery;
- CryoForge window feel;
- unified screenshot fix;
- neutral Kitty and Fastfetch base;
- Phase 16D — Nexus Focus Hub;
- Phase 16E — Nexus Media Workspace;
- R2 — Stable-base freeze, including the R2A documentation/build freeze and
  the R2B cold-reboot smoke test of login, session startup, lock/unlock,
  Nexus, screenshot, and recovery behavior.

Next planned phase:

- Phase 19A — curated theme-pack foundation.

Future roadmap:

- Phases 19B–19D — first curated theme, manual Nexus selection, and bounded
  application integration.

Future theme packs must preserve a stable neutral base first. Each pack may
provide an explicit curated palette plus a wallpaper and bounded UI/application
tokens. The policy excludes dynamic color extraction, timers, random rotation,
network fetches, and uncontrolled theme engines.
