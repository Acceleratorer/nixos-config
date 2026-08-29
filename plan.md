# CryoForge Project Plan

This file is the durable project map for the CryoForge NixOS desktop. It
records the accepted baseline, completed phase work, rejected experiments,
operating rules, and the next planned work so future sessions can resume from
the same context.

## Source of truth

- Repository: `https://github.com/Acceleratorer/nixos-config`
- Authoritative checkout on NixOS: `/home/accelra/Github/nixos-config`
- Historical Phase 16E merge baseline: `main` at
  `8dc1fc3df2d77a5cc7fa01d29713c05f33b99ab6`
- Historical R2B smoke-test baseline: `main` at
  `71e3e88c3bc2a560afec59b55af9d67edba02478`
- At every phase boundary, verify the current repository baseline with:
  `git rev-parse origin/main`
  The historical hashes above are not permanent expected `HEAD` values.
- Current build target:
  `nixos-caelestia-cryoforge-real-greeter`
- Pinned Caelestia shell revision:
  `817a220e8e87c4df9f3681033a0d8a8054cdaa30`
- R2 stable-base system, built in Phase 16E and verified after a cold reboot:
  `/nix/store/f62gina1wffrf2r5hfiw5prmxqavgxbh-nixos-system-nixos-26.05.6282.2f5a153c270b`
- Phase 19C implementation commit:
  `25a33eebc2d6c1af06b86f74590bc022797a43d6`
- Earlier Phase 19C documentation commit:
  `c974d7fa9996c726d18bd0b4dc9fee54996a481b`
- Wallpaper-persistence hotfix commit:
  `74dcc84dbd43fad53284e4004379efcadd63671e`
- Phase 19C accepted current, booted, and next-boot system:
  `/nix/store/7k1qr9db019m201gpq9phvhs1a9arp8c-nixos-system-nixos-26.05.6282.2f5a153c270b`
- On August 30, 2026, a real cold reboot into that generation passed the
  complete wallpaper-persistence and runtime-health gate.

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

### Phase 19A — Curated theme-pack foundation

- Added a static registry schema with `schemaVersion` 1.
- Defined the neutral default pack through references to the existing semantic
  palette.
- Added a bounded shell/UI role map for panel, card, text, subdued text,
  accent, outline, and focus roles.
- Added a deterministic, immutable JSON package containing the rendered
  registry.
- Added a focused validation contract for schema shape, identifiers, palette
  values, semantic references, local asset paths, package contents, and
  protected stable-base sources.
- Added no runtime consumer.
- Performed no activation and introduced no behavior change. Phase 19A did not
  change the active neutral palette or the live runtime.

### Phase 19B — First curated wallpaper theme

- Added the first curated pack:
  - Pack ID: `cryoforge-denia`
  - Display name: `CryoForge Denia`
  - Artist metadata: `1O`
  - Artwork ID: `145492517`
- Added the approved original as an unchanged JPEG/JFIF asset:
  - Dimensions: `9000x4301`
  - SHA-256:
    `34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb`
- Added the deterministic static preview:
  - Dimensions: `1600x765`
  - SHA-256:
    `f67c58a530a4e44c491937e13e33b36aedf9e6ac8b0fca8a25ba6c6696824045`
- Kept neutral first and default. CryoForge Denia is second and is the only
  curated pack.
- Preserved the historical Phase 19A neutral-only registry and package
  projection under its unchanged focused contract.
- Added no runtime consumer, selector, persistence, activation, or behavior
  change. At the Phase 19B boundary, CryoForge Denia was packaged but had not
  been applied to the live desktop.

### Phase 19C — Manual Nexus theme selection

Initially implemented on August 29, 2026 in commit
`25a33eebc2d6c1af06b86f74590bc022797a43d6`, documented in commit
`c974d7fa9996c726d18bd0b4dc9fee54996a481b`, and completed with the
wallpaper-persistence correction in commit
`74dcc84dbd43fad53284e4004379efcadd63671e`:

- Added manual Theme Pack selection to CryoForge Nexus with exactly
  **CryoForge Neutral** and **CryoForge Denia**.
- Made preview reversible through **Cancel**, Escape, and back navigation.
- Neutral changes the palette while preserving the current wallpaper.
- Denia applies its curated palette and wallpaper. The wallpaper SHA-256 is
  `34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb`.
- Apply is explicit and transactional; there is no automatic switching.
- The canonical applied Caelestia scheme identity is:
  - `name = cryoforge-pack`
  - `flavour = cryoforge-denia`
  - `mode = dark`
  - `variant = tonalspot`
- Runtime metadata is not part of the accepted identity and may remain null.
  Canonical identity is represented by `name`, `flavour`, `mode`, and
  `variant`; no populated runtime metadata is claimed.
- The guarded Caelestia CLI and shell use the same packaged scheme data.
- All CLI tests isolate HOME and XDG state, disable all adapters, and prohibit
  numbered PTY access and terminal escape output.
- Added no daemon, timer, watcher, network route, automatic theme switching,
  or application adapter.
- Kept the real-greeter boundary isolated from Phase 19C and retained its
  accepted R3 session, TOML, unit, restart, and stop policies.
- Corrected the runtime QML defect caused by placing `Connections`,
  `FileView`, and `Process` directly under `PageBase` by using explicitly
  typed object properties while retaining one direct visual `ColumnLayout`.
- Added runtime-engine regression coverage for the structural QML defect that
  `qmllint` and `qmlcachegen` did not catch.
- Preview/Cancel passed for Neutral and Denia. Apply passed for Denia.
- Denia remained selected after closing and reopening Nexus and after a
  controlled `caelestia.service` restart.
- The Caelestia bar, notification ownership, session targets, and `greetd`
  remained healthy.

The first cold reboot into the historical
`/nix/store/9jch06zb0vczkbymw6321cfi02rl2azj-nixos-system-nixos-26.05.6282.2f5a153c270b`
generation passed the system and service gate. Subsequent logged-in visual
review then exposed a real persistence defect: the Denia scheme identity had
survived, but the wallpaper had returned to Chisa. The earlier `9jch…` reboot
therefore did not visually preserve Denia.

Root cause and correction:

- Home Manager's Chisa initializer unconditionally rewrote
  `wallpaper/path.txt` during startup.
- Denia Apply updated `scheme.json` and `wallpaper/path.txt`, but did not
  update Caelestia's canonical `wallpaper/current` link.
- Hotfix `74dcc84dbd43fad53284e4004379efcadd63671e` changed only:
  - `desktop/profiles.nix`
  - `desktop/themes/apply-theme-pack.sh`
  - `flake.nix`
  - `tests/phase19c/test_manual_theme_selection_contract.sh`
- The startup initializer now preserves valid persisted wallpapers, seeds
  Chisa only for missing or invalid state, and repairs `wallpaper/current`
  from validated `path.txt`.
- Denia Apply now transactionally updates and rolls back both `path.txt` and
  `wallpaper/current`.
- Neutral continues to preserve the current wallpaper.
- Traversal, unsafe symlinks, unavailable files, malformed state, and invalid
  Denia hashes fail closed.

Focused and historical contracts, offline flake checks, all four NixOS
evaluations, real-greeter preservation, dry activation, test activation,
Neutral Apply, Denia Apply, a controlled Caelestia restart, boot persistence,
and a real cold reboot completed successfully. On August 30, 2026, the real
cold reboot proved:

- current, booted, and system-profile paths all equal
  `/nix/store/7k1qr9db019m201gpq9phvhs1a9arp8c-nixos-system-nixos-26.05.6282.2f5a153c270b`;
- the Denia scheme identity survived;
- `wallpaper/path.txt` and `wallpaper/current` both remained on
  `/home/accelra/.local/share/cryoforge/theme-packs/cryoforge-denia/wallpaper.jpg`;
- the materialized regular, non-symlink Denia wallpaper retained mode `0600`,
  the approved SHA-256
  `34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb`,
  and remained visible after login;
- `greetd.service`, `caelestia.service`, `hyprland-session.target`, and
  `nixos-cryoforge-caelestia-cryoforge.target` were active;
- system and user failed-unit counts were zero and Hyprland reported no
  configuration errors; and
- Caelestia retained ownership of `org.freedesktop.Notifications`.

As of commit `74dcc84dbd43fad53284e4004379efcadd63671e`, the real
`greetd` password-entry screen uses its accepted static Chisa presentation.
After authentication, the logged-in `accelra` session restores persisted
Denia. This current Chisa-to-Denia transition was observed during the
successful August 30, 2026 cold reboot. “Boot screen” in this context means
the real `greetd` password-entry screen, not the bootloader or Plymouth.

Phase 19C fixed logged-in wallpaper persistence, but it did not implement
cross-surface theme continuity. The current static-Chisa greeter is a known
visual-continuity limitation, not a persistence regression or the permanent
desired UX.

The security invariant remains separate: the pre-authentication greeter must
never read mutable theme or wallpaper state directly from `accelra`'s HOME.
Future continuity must retain greeter/session/authentication isolation. A
future greeter may consume only a sanitized, validated system-level active
theme selection and map it to immutable, approved assets. No such
system-visible active-theme mechanism exists yet.

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

### R2 — Stable-base freeze (completed)

This maintenance checkpoint was completed without changing visual or
behavioral features or introducing theme machinery.

#### R2A — Documentation/build freeze

Completed:

- Updated README and this plan to reflect completed Phase 16D and Phase 16E
  work, the historical merge baseline, and the current freeze checkpoint.
- Preserved the accepted Phase 16E system and pinned Caelestia revision.
- Re-ran the existing offline contracts, evaluations, and exact
  real-greeter build.
- Introduced no new contract and changed no source, package, test, asset,
  lockfile, or runtime behavior.

#### R2B — User-controlled cold-reboot smoke test

Completed against repository baseline
`71e3e88c3bc2a560afec59b55af9d67edba02478` and system
`/nix/store/f62gina1wffrf2r5hfiw5prmxqavgxbh-nixos-system-nixos-26.05.6282.2f5a153c270b`:

- Cold reboot reached the real greeter and login completed normally.
- The runtime and next-boot profile remained on the accepted system.
- System and user unit health was clean, all required Caelestia/Hyprland
  targets were active, and Hyprland reported no configuration errors.
- Lock/unlock, Nexus Focus Hub, Nexus Media Workspace, and screenshot behavior
  passed manual smoke testing.
- The real-greeter recovery action returned to the recovery login as designed.
- `main` remained clean and synchronized with `origin/main`.

R2, Phase 19A, Phase 19B, and Phase 19C are complete.

### Phase 19C — Manual Nexus theme selection (completed)

The manual, preview-first, explicit-Apply, rollback-safe Nexus selector is
accepted. Its implementation and runtime verification are recorded in the
completed-phases section above.

### Operational checkpoint — Phase 19C cold reboot (completed)

The August 30, 2026 real cold reboot completed against the accepted `7k1…`
system. Denia identity, `wallpaper/path.txt`, `wallpaper/current`, the
materialized wallpaper hash and mode, the visible logged-in wallpaper,
required services and targets, failed-unit health, Hyprland configuration,
and notification ownership all passed.

### Phase 19D — Persistent cross-surface theme continuity

Status: next planned phase; implementation has not begun.

The product requirement is that the last successfully Applied approved theme
pack remains visually consistent across:

- the logged-in Caelestia shell;
- wallpaper;
- the Caelestia `WlSessionLock` entered by Super+L;
- suspend and resume through the same session-lock path;
- logout and the next real `greetd` password screen;
- shutdown and the next cold-boot real `greetd` password screen; and
- the subsequent logged-in session.

Expected examples:

- Apply Chisa: shell, lock, suspend/resume, next greeter, and next login remain
  Chisa.
- Apply CryoForge Denia: those same surfaces remain Denia.
- Apply another approved pack: those surfaces consistently use that pack.
- Preview, Cancel, Escape, and Back never publish or persist a cross-surface
  selection.
- A failed Apply must not partially publish a new system-visible selection.

The system is intended to support many curated wallpaper-backed theme packs,
not only Chisa and Denia. Candidate wallpapers become eligible only after
promotion into explicit approved theme packs with stable IDs, curated
palettes, immutable packaged assets, and pinned hashes. Candidate-board
wallpapers are not already packaged theme packs.

Architectural and safety requirements:

- Represent Chisa as an explicit approved theme pack, not only an implicit
  fallback.
- A successful Apply must publish a minimal system-visible active theme
  identity, such as schema version, pack ID, and generation.
- The public identity must contain no arbitrary user-controlled filesystem
  path.
- The normal real greeter must map only allowlisted pack IDs to immutable
  packaged assets.
- The greeter must never read `accelra`'s HOME.
- Unknown IDs, malformed state, hash failures, traversal, symlinks,
  unavailable assets, and unsupported versions must fail closed to the
  accepted Chisa fallback.
- Publication must be atomic and bounded.
- Preview state must never reach the public selection.
- Apply rollback and injected-failure behavior must cover both logged-in state
  and the system-visible identity.
- Add no daemon, timer, watcher, network route, or dynamic wallpaper download.
- Preserve the independently audited `greetd`, PAM, `WlSessionLock`, and
  ReGreet recovery boundaries.
- ReGreet recovery may remain on a static, known-safe presentation.
- Treat the current machine as a single-user active-theme policy; do not
  invent an unrequested multi-user design.

Neutral semantics remain explicit:

- Neutral changes the semantic palette.
- Neutral preserves the currently selected wallpaper.
- The preserved wallpaper identity remains available to the lock and future
  greeter continuity mechanism.
- Neutral is not Chisa.

### Phase 19E — Bounded application integration

Application integration remains separate and follows only after Phase 19D is
accepted:

- Add opt-in Kitty and Fastfetch theme adapters.
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

R2, Phase 19A, Phase 19B, and Phase 19C, including the wallpaper-persistence
correction and real cold-reboot checkpoint, are complete. Phase 19D persistent
cross-surface theme continuity is next planned but has not begun and requires
its own fresh Gate 0. Phase 19E bounded application integration follows only
after Phase 19D is accepted.
