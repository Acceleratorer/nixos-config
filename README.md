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

At the completed Phase 20 live checkpoint on September 4, 2026, the current,
booted, and next-boot system all used:

```text
/nix/store/hhz4mng8w119pvk9h42x59vnff88nwg0-nixos-system-nixos-26.05.6282.2f5a153c270b
```

The preceding Phase 19C wallpaper-persistence checkpoint on August 30, 2026
used:

```text
/nix/store/7k1qr9db019m201gpq9phvhs1a9arp8c-nixos-system-nixos-26.05.6282.2f5a153c270b
```

The real cold reboot into this generation completed successfully. The source
checkpoint is commit `8974c5e`.

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

The Phase 19D real-greeter path now resolves only the sanitized, validated
system-visible active-theme identity and maps it to immutable packaged assets.
It does not read mutable theme or wallpaper state from `accelra`'s HOME. Missing
or invalid public state fails closed to the approved Chisa fallback, while the
greeter/session/authentication boundaries remain separate.

The Phase 19D continuity contract covers the logged-in shell, wallpaper,
Caelestia lock path, real `greetd` login path, and persistence across the
accepted restart, boot, lock/unlock, suspend/resume, and cold-reboot checks.
In this context, “boot screen” means the real `greetd` password-entry screen,
not the bootloader or Plymouth.

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
- a finite, manual gallery backed by the approved theme-pack registry, with
  temporary preview and an explicit **Apply** action;
- manual Theme Pack selection in CryoForge Nexus, with CryoForge Neutral and
  18 curated wallpaper-backed packs, reversible preview, and explicit
  transactional Apply;
- quiet Plymouth boot using the `bgrt` theme and conservative console logging;
- the accepted CryoForge window-feel policy;
- one unified region screenshot flow;
- a stable, neutral Kitty and Fastfetch base;
- complete removal of Gammastep and night-light startup from the current
  CryoForge profile;
- a Classic recovery and fallback path.

These items are accepted in source and covered by repository checks. The
accepted Phase 20 runtime and next-boot generation are recorded above.

## Manual Theme Pack selection

Phase 19C introduced manual Theme Pack selection to CryoForge Nexus. The
current Phase 20 registry provides **CryoForge Neutral** plus 18 curated
wallpaper-backed packs, including **CryoForge Denia**:

- Preview is temporary and reversible through **Cancel**, <kbd>Escape</kbd>,
  and back navigation.
- Neutral changes the palette while preserving the current wallpaper.
- Each curated pack applies its pinned palette and wallpaper. The Denia
  wallpaper SHA-256 is
  `34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb`.
- Apply is explicit and transactional. There is no automatic switching.

For a curated pack, the canonical applied Caelestia scheme identity is
`name = cryoforge-pack`, `flavour = <pack-id>`, `mode = dark`, and
`variant = tonalspot`. The Denia example is:

```text
name = cryoforge-pack
flavour = cryoforge-denia
mode = dark
variant = tonalspot
```

Runtime metadata is not part of the accepted identity and may remain null; no
populated runtime metadata is claimed. The guarded Caelestia CLI and shell
consume the same packaged scheme data. CLI contracts isolate HOME and XDG
state, disable all adapters, and prohibit numbered PTY access and terminal
escape output.

No daemon, timer, watcher, network route, automatic theme switching, or live
application integration was added. Phase 21A adds only a standalone,
opt-in CryoForge-to-Serpantinum adapter package: it consumes the built
resolver output, validates immutable store files and hashes, and emits a
bounded Catppuccin-shaped JSON contract. It is not installed into any desktop
profile and does not modify Serpantinum, Caelestia, or user state.
Preview/Cancel/Back/Escape isolation and transactional Apply are covered by the
Phase 19D contract. The Phase 20 contract applies and validates all 18 curated
packs, including their schemes, wallpapers, thumbnails, resolver identities,
and generation progression. The gallery was visually reviewed before the
accepted cold reboot; the Caelestia bar, notification ownership, session
targets, and `greetd` remained healthy.

The initial implementation was commit
`25a33eebc2d6c1af06b86f74590bc022797a43d6`, followed by the earlier Phase
19C documentation commit `c974d7fa9996c726d18bd0b4dc9fee54996a481b`.
The first cold reboot into the historical `9jch…` generation passed its system
and service gate, but subsequent logged-in visual review exposed a real
wallpaper-persistence defect: the Denia scheme identity survived while the
wallpaper returned to Chisa. That reboot therefore did not prove visual Denia
persistence.

The defect had two causes:

- Home Manager's Chisa initializer unconditionally rewrote
  `wallpaper/path.txt` during startup.
- Denia Apply updated `scheme.json` and `wallpaper/path.txt`, but not
  Caelestia's canonical `wallpaper/current` link.

Commit `74dcc84dbd43fad53284e4004379efcadd63671e` corrected only
`desktop/profiles.nix`, `desktop/themes/apply-theme-pack.sh`, `flake.nix`, and
`tests/phase19c/test_manual_theme_selection_contract.sh`. The startup
initializer now preserves valid persisted wallpapers, seeds Chisa only for
missing or invalid state, and repairs `wallpaper/current` from validated
`path.txt`. Denia Apply transactionally updates and rolls back both
`path.txt` and `wallpaper/current`; Neutral continues to preserve the current
wallpaper. Traversal, unsafe symlinks, unavailable files, malformed state, and
an invalid Denia hash fail closed.

Focused and historical contracts, offline flake checks, all four NixOS
evaluations, real-greeter preservation, dry activation, test activation,
Neutral Apply, Denia Apply, a controlled Caelestia restart, boot persistence,
and a real cold reboot all completed successfully. On August 30, 2026, that
cold reboot proved:

- current, booted, and system-profile paths all equal the accepted `7k1…`
  system recorded above;
- Denia's scheme identity survived;
- `wallpaper/path.txt` and `wallpaper/current` both remained on the
  materialized Denia wallpaper, whose approved SHA-256 remained intact;
- the approved Denia wallpaper remained visible after login;
- `greetd.service`, `caelestia.service`, `hyprland-session.target`, and
  `nixos-cryoforge-caelestia-cryoforge.target` were active;
- system and user failed-unit counts were zero and Hyprland reported no
  configuration errors; and
- Caelestia retained ownership of `org.freedesktop.Notifications`.

### Cross-surface continuity (Phase 19D completed)

Phase 19D publishes the last successfully Applied approved theme as a minimal
system-visible identity containing schema version, pack ID, wallpaper-pack ID,
and generation. The resolver validates that identity against the immutable
manifest and falls back to Chisa on missing, malformed, unsupported, or
tampered state. Apply uses bounded authenticated publication and atomic
rollback for the logged-in scheme and wallpaper projections.

The accepted continuity checks cover the logged-in shell and wallpaper,
Caelestia `WlSessionLock`, suspend/resume through that lock path, the real
`greetd` password screen, and the subsequent logged-in session. Preview,
Cancel, Escape, and Back do not publish a cross-surface selection, and failed
Apply does not leave a partial public identity.

The system supports many curated, wallpaper-backed theme packs, not only Chisa
and Denia. Candidate wallpapers are not automatically theme packs;
they become eligible only after promotion into explicit approved packs with
stable IDs, curated palettes, immutable packaged assets, and pinned hashes.

Neutral remains distinct from Chisa: it changes the semantic palette while
preserving the currently selected wallpaper. The preserved wallpaper identity
  must remain available to the lock and greeter continuity mechanism.

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
- [`desktop/themes/`](desktop/themes/) contains the approved theme-pack
  registry, curated pack metadata/assets, authenticated publisher, and
  validated active-theme resolver.
- [`desktop/hypr/`](desktop/hypr/) and the other classic desktop directories
  provide the independent Classic recovery environment.
- [`desktop/regreet/`](desktop/regreet/) packages the accepted ReGreet
  recovery presentation.
- [`packages/`](packages/) contains derivations for the CryoForge shell,
  Chisa assets and previews, the real greeter, the real lock contract, Codex,
  the standalone Serpantinum adapter, and Hyprexpo.
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
  Nexus, screenshot, and recovery behavior;
- Phase 19A — Curated theme-pack foundation, including the static schema
  version 1 registry, neutral default pack, deterministic immutable JSON
  package, and focused validation contract. This build-only foundation has no
  runtime consumer and made no activation or behavior change;
- Phase 19B — First curated wallpaper theme, adding CryoForge Denia as the
  first curated pack while keeping neutral first and default. Denia is
  packaged as a static repository asset with its manually curated palette,
  preview, and provenance. At the Phase 19B boundary it had no runtime
  consumer and had not been applied to the live desktop;
- Phase 19C — Manual Nexus theme selection and its wallpaper-persistence
  correction, completed on August 30, 2026. The original implementation is
  commit `25a33eebc2d6c1af06b86f74590bc022797a43d6`, the earlier documentation
  commit is `c974d7fa9996c726d18bd0b4dc9fee54996a481b`, and the corrective hotfix
  is commit `74dcc84dbd43fad53284e4004379efcadd63671e`. The accepted `7k1…`
  generation passed the real cold-reboot persistence and runtime-health gate.
- Phase 19D — Persistent cross-surface theme continuity, including the
  authenticated publisher, validated public identity, resolver fallback,
  atomic rollback, real-greeter integration, and protected live continuity
  checks.
- Phase 20 — Registry-backed curated theme expansion, adding 18 immutable
  wallpaper-backed packs to Nexus. The all-curated-pack contract, full flake
  check, exact real-greeter build, Generation 57 activation/boot path, cold
  reboot, health checks, and visual gallery review passed.
- Phase 21A — CryoForge-to-Serpantinum adapter foundation. The adapter is a
  standalone, opt-in package and focused contract only; it consumes the built
  resolver, converts validated CryoForge scheme colours to Serpantinum's
  Catppuccin-shaped JSON, and performs no activation or state writes.

Next exploration:

- A separately bounded live Serpantinum integration design. The Phase 21A
  adapter does not replace Serpantinum's existing Matugen or wallpaper
  behavior, and those live paths must not replace CryoForge's immutable
  registry and canonical publisher without a new scoped phase and explicit
  contract.

Following phase:

- Phase 19E — bounded application integration, only after Phase 19D is
  accepted.

Future theme packs must preserve a stable neutral base first. Each pack may
provide an explicit curated palette plus a wallpaper and bounded UI/application
tokens. The policy excludes dynamic color extraction, network fetches, timers,
watchers, random rotation, automatic switching, and uncontrolled theme
engines.
