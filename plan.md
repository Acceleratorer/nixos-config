# CryoForge Project Plan

This file is the durable project map for the CryoForge NixOS desktop. It
records the accepted baseline, completed phase work, rejected experiments,
operating rules, and the next planned work so future sessions can resume from
the same context.

## Source of truth

- Repository: `https://github.com/Acceleratorer/nixos-config`
- Authoritative checkout on NixOS: `/home/accelra/Github/nixos-config`
- Accepted code baseline before this plan was added: `main` at
  `8dc1fc3df2d77a5cc7fa01d29713c05f33b99ab6`
- For future work, verify the live baseline with `git rev-parse origin/main`;
  the hash above is a historical Phase 16E merge reference, not a permanent
  expected `HEAD`.
- Current build target:
  `nixos-caelestia-cryoforge-real-greeter`
- Pinned Caelestia shell revision:
  `817a220e8e87c4df9f3681033a0d8a8054cdaa30`
- Last verified and boot-persisted Phase 16E system:
  `/nix/store/f62gina1wffrf2r5hfiw5prmxqavgxbh-nixos-system-nixos-26.05.6282.2f5a153c270b`

Reference-only upstream clones:

- `/home/accelra/Github/shell`
- `/home/accelra/Github/caelestia`
- `/home/accelra/Github/fastfetch`

The reference clones are research inputs. They are not edited as part of
CryoForge implementation work.

## Operating policy

From this point forward, work directly on `main` unless a separate branch is
explicitly requested.

Before starting work:

```bash
cd /home/accelra/Github/nixos-config
git fetch origin
git switch main
git pull --ff-only origin main
git status --short --branch
git diff --check
```

The normal delivery loop is:

1. Define one narrowly scoped phase and its exact allowlist.
2. Inspect the existing source, contracts, and pinned upstream APIs.
3. Implement build-only.
4. Run focused and protected offline checks, then stop for review.
5. After explicit approval, test activation and review the live result
   visually when the phase changes UI.
6. Persist with `nixos-rebuild boot` only after runtime health is clean.
7. Commit directly to `main`, verify the commit, and push `main`.

No phase may silently weaken an older contract. If a historical package hash
or projection is affected, preserve the historical contract with a narrow
package projection instead of changing the old expected behavior.

## Completed phases

### Foundation

Completed the flake-based NixOS configuration, Home Manager integration,
Hyprland session management, NVIDIA PRIME offload setup, ASUS Aura support,
Classic recovery desktop, and the basic Caelestia package integration.

### Phase 12A — Caelestia Stock baseline

- Pinned Caelestia Stock inputs.
- Established the boundary between upstream Caelestia sources and Nix-owned
  integration.
- Kept Classic, Stock, and CryoForge profiles separate.

### Phase 13A — Real Caelestia desktop foundation

- Added the CryoForge profile architecture.
- Added the real Caelestia cold-login greeter path.
- Preserved a ReGreet recovery path.
- Added explicit ownership boundaries for session services.

### Phase 13B — Greeter and recovery reliability

- Added the real-greeter controller and recovery launcher.
- Added greetd activation transaction handling.
- Covered success, cancellation, retry, recovery, and password-sentinel
  scenarios.
- Kept cold login separate from the logged-in session lock.

### Phase 13C — Real session lock

- Added the real lock package and lock preview flow.
- Connected the CryoForge lock binding to the Caelestia lock IPC path.
- Protected the PAM and WlSessionLock boundary.
- Kept ReGreet and greetd out of the logged-in lock implementation.

### Phase 16A — Chisa Pool visuals and manual gallery

- Added the accepted Chisa Pool wallpaper and avatar assets.
- Added the finite manual Chisa preset gallery.
- Added preview and explicit Apply behavior.
- Added quiet Plymouth boot presentation.
- Kept the gallery static, local, and non-random.

### Phase 16B — CryoForge window feel

Accepted CryoForge-only values:

- Inner gaps: `6`
- Outer gaps: `12`
- Single-window outer gaps: `18`
- Border size: `2`
- Rounding: `14`
- Blur size: `6`
- Blur passes: `2`
- Blur xray: off
- Active opacity: `1.0`
- Inactive opacity: `0.98`
- Fullscreen opacity: `1.0`
- Special-workspace dim: `0.10`

Fullscreen, protected dialogs, screenshot surfaces, and lock-related surfaces
retain their dedicated opaque/unblurred rules.

### Phase 16C — Neutral application base

- Added the shared semantic CryoForge palette.
- Added neutral Kitty integration.
- Added declarative Fastfetch integration.
- Preserved user-owned files and symlinks.
- Seeded only missing native config files with mode `0600`.
- Added the full built-in NixOS Fastfetch logo.
- Kept the base wallpaper-independent.

### Phase 16C.1 — Fastfetch presentation

- Added the full built-in NixOS logo.
- Added the `CryoForge // user@host` title.
- Added the accepted two-break module layout.
- Verified native Fastfetch execution and safe live-config migration.

### Phase 16D — Nexus Focus Hub

- Added the first CryoForge Nexus page.
- Added a read-only live workspace/window overview.
- Reused existing Nexus primitives and Hypr state.
- Registered the page through a guarded upstream patch.
- Added no daemon, service, timer, watcher, or new dependency.

### Phase 16E — Nexus Media Workspace

- Added the Media Workspace page to Nexus.
- Reused the pinned `Players`/MPRIS API.
- Added artwork, title, artist, album, player identity, and progress.
- Added guarded Previous, Play/Pause, and Next controls.
- Added a player selector using `Players.manualActive`.
- Added a calm empty state when no player exists.
- Preserved capability-driven disabled states.
- Fixed the runtime `ButtonRow is not a type` defect by importing
  `Caelestia.Components`.
- Verified Brave MPRIS playback. Brave reports
  `CanGoPrevious=false` and `CanGoNext=false` for a single YouTube video, so
  those controls correctly remain disabled.

### Phase 17 — Screenshot flow

- Unified the region screenshot ownership and helper route.
- Preserved cancellation without clipboard, cache, or notification side
  effects.
- Preserved successful capture, clipboard, notification, Open, and Save
  behavior.
- Protected the area-picker, screenshot IPC, and screenshot helper boundary.

### Maintenance R1 series

- Rewrote the project README around the actual architecture and accepted
  behavior.
- Audited the feature and main branches.
- Reconciled the long-lived clone to `origin/main` after creating an external
  backup of rejected Gammastep changes.
- Persisted the accepted consolidated generation as the next boot generation.
- Kept rejected local behavior outside the repository.

## Rejected or intentionally excluded work

These decisions are part of the project history and must not be reintroduced
without an explicit new decision:

- Cirno custom ANSI Fastfetch logo: tested, visually rejected, removed.
- Phrolova cursor: inspected source was Windows/macOS cursor data rather than
  a Linux Xcursor theme; no package or route was added.
- Gammastep and unused night-light services: removed and intentionally
  excluded.
- Dynamic wallpaper color extraction.
- Automatic theme switching.
- Random wallpaper rotation.
- Timer, watcher, daemon, or background theme engine.
- Network-fetched themes or wallpaper metadata.
- Browser-specific media automation to force unsupported Previous/Next
  operations.
- Claims of Secure Boot, disk encryption, or encrypted swap. The LUKS/Secure
  Boot document is a future migration plan only.

## Stable-base invariants

Every future phase must preserve these rules:

- The neutral palette remains a valid wallpaper-independent fallback.
- Existing user-owned config files and symlinks are not overwritten.
- No `flake.lock` change unless explicitly approved.
- No upstream reference clone is edited.
- No new dependency unless its necessity is demonstrated.
- No network route in a local desktop feature.
- No hidden service, timer, watcher, or polling loop.
- No broad refactor during a feature phase.
- No weakening or deletion of an accepted contract.
- The real-greeter target remains the authoritative build/audition target.
- Classic recovery remains available.
- Cold login, logged-in lock, shell, and compositor ownership remain separate.

## Next roadmap

### R2 — Stable-base freeze

This is the next checkpoint before theme work. It is a maintenance phase, not
a feature phase.

Goals:

- Pull the merged `main` into every intended working checkout.
- Update README status so Phase 16D and Phase 16E are marked completed.
- Record the accepted Phase 16E system and repository baseline.
- Run one cold-reboot smoke test.
- Verify cold login, session startup, lock/unlock, Nexus, screenshot flow,
  and recovery behavior.
- Re-run the full offline contract/build suite.
- Confirm the long-lived checkout is clean and synchronized.

R2 must not change visual behavior or introduce theme machinery.

### Phase 19A — Curated theme-pack foundation

Define a static, explicit theme-pack format and its contracts:

- Pack ID and display name.
- Wallpaper asset reference.
- Explicit semantic palette.
- Bounded shell/UI tokens.
- Preview metadata.
- Neutral fallback behavior.
- No runtime color extraction.
- No network fetch.
- No timer, watcher, random rotation, or automatic switching.

This phase should establish the data model and tests before introducing a
large visual theme.

### Phase 19B — First curated wallpaper theme

Create the first approved custom theme based on the wallpaper direction
previously discussed:

- Select one canonical wallpaper.
- Curate the palette manually.
- Define shell, card, accent, and background relationships.
- Keep contrast and readability above decorative effects.
- Compare the result against the old candidate-board visual direction.

The theme must be a static repository asset and must not replace the neutral
base.

### Phase 19C — Manual Nexus theme selection

Integrate theme packs into the existing Nexus flow:

- Show available packs.
- Preview before applying.
- Require an explicit Apply action.
- Provide an explicit neutral fallback.
- Keep selection manual and bounded.
- Avoid configuration overwrites and hidden background work.

### Phase 19D — Bounded application integration

Only after shell/theme behavior is accepted:

- Add opt-in Kitty/Fastfetch theme adapters.
- Consider bounded GTK/Qt integration only if ownership is clear.
- Preserve missing-file-only and user-owned-file rules.
- Test rollback, persistence, and cold boot.
- Document theme authoring and recovery behavior.

## Definition of done for future phases

A phase is complete only when:

- Its scope and exact allowlist are documented.
- Gate 0 passes on clean `main`.
- Source and rendered outputs are checked.
- Focused and protected contracts pass.
- `nix flake check --offline` passes.
- The exact real-greeter configuration evaluates and builds.
- UI changes are visually reviewed.
- Activation is tested only after build and visual approval.
- Boot persistence is explicitly verified when requested.
- Health checks are clean.
- The change is committed directly to `main` and pushed.
- README and this plan remain consistent with the repository state.

Until R2 is explicitly started, do not begin Phase 19A implementation.
