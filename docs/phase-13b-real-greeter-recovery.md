# Phase 13B real-greeter audition and recovery

The `nixos-caelestia-cryoforge-real-greeter` output is build-only until a
separate live-audition phase explicitly activates it. The unchanged default
system and boot profile continue to use the accepted CryoForge ReGreet
generation.

## Activation command rules

`nixos-rebuild` has no option for activating an already-built toplevel by
passing its store path. An invented store-path flag discards the intended
candidate and falls back to evaluation through the caller's Nix search path.

For a prebuilt NixOS system, the valid primitive is:

```console
sudo /nix/store/<candidate-system>/bin/switch-to-configuration test
```

Phase 13B-R2 must not invoke that primitive directly. From TTY2, run the
candidate's guarded wrapper as one command:

```console
sudo /nix/store/<candidate-system>/sw/bin/phase13b-real-greeter-audition
```

The wrapper records a root-only log under
`/var/log/phase13b-real-greeter-audition-*.log`, verifies the accepted profile
before activation, reconciles operation lists from any interrupted prior test,
uses only `switch-to-configuration test`, and checks candidate activation,
greetd activity, unit identity, and the fresh `ready-v1` marker. It never
changes the boot profile.

Any activation timeout/failure, inactive or wrong greetd unit, profile drift,
or readiness timeout triggers automatic rollback. Rollback activates the
unchanged `/nix/var/nix/profiles/system` with `test`, explicitly restarts
accepted ReGreet, retries an idempotent start if needed, and verifies accepted
unit identity plus profile invariants before exiting.

## Manual recovery fallback

If the wrapper itself cannot complete automatic rollback:

1. Stay on TTY2.
2. Activate the unchanged accepted generation without changing the boot
   profile:

   ```console
   sudo /nix/var/nix/profiles/system/bin/switch-to-configuration test
   ```

3. Ensure greetd is active:

   ```console
   sudo systemctl start greetd
   ```

4. Confirm `/run/current-system` and `/nix/var/nix/profiles/system` resolve to
   the accepted generation before returning to ReGreet.

No reboot or boot-profile operation belongs in the Phase 13B-R2 audition.
