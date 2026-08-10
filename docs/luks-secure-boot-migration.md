# LUKS and Secure Boot migration

Repair 4 separates two security boundaries:

1. Encrypt the operating-system disk with LUKS2.
2. Enable Secure Boot only after the encrypted installation boots reliably.

These steps require an offline maintenance window. Do not attempt to encrypt the
mounted root filesystem from the running system.

## Verified baseline

Recorded on August 10, 2026:

- `/dev/nvme0n1p1`: 1 GiB FAT32 EFI System Partition mounted at `/boot`.
- `/dev/nvme0n1p2`: plain ext4 root filesystem.
- `/dev/nvme0n1p3`: plain 16 GiB swap.
- Secure Boot: disabled.
- TPM2: available.
- Boot loader: systemd-boot.
- Memory: 16 GiB.
- No LUKS device is declared in `hardware-configuration.nix`.

The ReGreet label says `SECURE SESSION`, not `SECURE BOOT`, until Secure Boot is
actually enabled and verified.

## Recommended target

- Keep a 1 GiB FAT32 EFI System Partition.
- Use the remaining system disk as one LUKS2 container named `cryptroot`.
- Create root and 16 GiB swap logical volumes inside `cryptroot`.
- Keep discard passthrough disabled initially.
- Unlock with a strong passphrase first.
- Add TPM2-based unlocking only as a later, separately tested change.
- Use a pinned Lanzaboote input for signed boot artifacts.
- Keep Microsoft firmware certificates when enrolling custom Secure Boot keys.

Using one encrypted container prevents the current swap partition from leaking
memory contents and requires only one early-boot unlock.

## Phase 0: recovery prerequisites

Do not begin the destructive phase until all of these are true:

- The Git repository and all non-declarative user data have an off-machine,
  encrypted backup.
- The backup has been restored into a temporary location and checked.
- A NixOS installer USB boots successfully on this laptop.
- The installer can reach the network and access this exact configuration.
- The current partition table and important EFI files have been copied to the
  backup.
- The LUKS recovery passphrase will be stored separately from the laptop.

The internal NTFS data disk is not an adequate sole backup because it is in the
same laptop and is not known to be encrypted.

## Phase 1: offline LUKS2 installation

1. Boot the NixOS installer USB with Secure Boot still disabled.
2. Confirm the target disk is `/dev/nvme0n1`; do not identify it by position
   alone when other storage is attached.
3. Recreate the system-disk layout:
   - EFI System Partition: 1 GiB FAT32.
   - LUKS2 partition: all remaining space.
4. Open the LUKS2 partition as `cryptroot`.
5. Inside `cryptroot`, create:
   - an ext4 root logical volume;
   - a 16 GiB swap logical volume.
6. Mount root at `/mnt` and the EFI System Partition at `/mnt/boot`.
7. Restore user data and install from this repository.
8. Regenerate `hardware-configuration.nix` from the mounted encrypted layout.
9. Confirm the generated configuration includes the new root and swap devices.
10. Declare the LUKS container using its new LUKS UUID:

```nix
boot.initrd.luks.devices."cryptroot" = {
  device = "/dev/disk/by-uuid/<LUKS-UUID>";
  allowDiscards = false;
};
```

11. Build and install the generation from the pinned flake.
12. Reboot and verify passphrase unlocking before making any Secure Boot change.

### LUKS acceptance checks

- `lsblk -f` shows `crypto_LUKS` above the root and swap logical volumes.
- `/` is mounted from storage inside `cryptroot`.
- Active swap is inside `cryptroot`; no plain swap partition remains.
- A cold boot succeeds using the recovery passphrase.
- The NixOS configuration builds from a clean Git checkout.
- The recovery USB can open the LUKS container.

There is no reliable rollback for a reformatted root partition other than the
verified backup. That is why backup restoration is a hard prerequisite.

## Phase 2: signed boot and Secure Boot

Begin this phase only after multiple successful encrypted cold boots.

1. Pin a reviewed Lanzaboote release or immutable revision in `flake.nix`.
2. Add its NixOS module to the `nixos` configuration.
3. Install `sbctl` declaratively.
4. Create the signing keys under `/var/lib/sbctl`.
5. Store an encrypted off-machine backup of the signing keys.
6. Disable the direct `systemd-boot` module and enable Lanzaboote with
   `/var/lib/sbctl` as its PKI bundle.
7. Build and activate the signed generation while firmware Secure Boot remains
   disabled.
8. Verify every boot artifact is signed before changing firmware settings.
9. Put the firmware into Secure Boot setup mode.
10. Enroll the owner keys while retaining Microsoft certificates.
11. Enable Secure Boot in firmware and boot the signed generation.

### Secure Boot acceptance checks

- `bootctl status` reports `Secure Boot: enabled`.
- `sbctl status` reports Secure Boot enabled and setup mode disabled.
- `sbctl verify` reports the active boot artifacts as signed.
- The machine can still boot after a full power-off.
- The NixOS installer USB remains available as recovery media.

If signed boot fails, disable Secure Boot in firmware and boot the last known
working generation. Do not delete the working systemd-boot files or recovery
media until signed boot has passed repeated cold-boot tests.

## Deferred hardening

Only after LUKS and Secure Boot are stable:

- Add a second LUKS key slot or an offline recovery key.
- Evaluate TPM2 unlocking with a retained passphrase fallback.
- Decide whether SSD discard passthrough is worth its allocation-pattern leak.
- Add measured-boot or remote-attestation policy only if there is a real need.

These are separate changes and must not be bundled into the initial migration.
