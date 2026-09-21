# CryoForge NixOS Installation Guide

This is a personal NixOS setup for an ASUS laptop: Caelestia CryoForge,
Hyprland, developer tools, document tools, Blender, Android, containers, and
machine-learning tooling. It is reproducible but not hardware-generic.

## Normal desktop target

Always use this output for the normal desktop:

```text
nixos-caelestia-cryoforge-real-greeter
```

The bare `nixos` output is the Classic recovery desktop. Do not use it for the
normal Caelestia desktop, because Home Manager may try to replace existing
Caelestia, Hyprland, and Kitty configuration paths.

## New machine preparation

Clone the repository:

```bash
mkdir -p ~/Github
cd ~/Github
git clone git@github.com:Acceleratorer/nixos-config.git
cd nixos-config
```

Use the HTTPS clone URL if SSH authentication is not set up.

Before building, generate a hardware declaration on the target machine:

```bash
sudo nixos-generate-config --show-hardware-config > hardware-configuration.new.nix
```

Review and merge it into `hardware-configuration.nix`. Also adapt these
machine-specific settings in `configuration.nix` before building:

- `/mnt/data` filesystem UUID and NTFS options;
- NVIDIA PRIME AMD/NVIDIA PCI bus IDs;
- ASUS Aura product ID;
- username, hostname, timezone, and locale;
- Docker, KVM, CUDA, Android, and NVIDIA settings that do not apply to the new hardware.

For a non-ASUS or non-hybrid-GPU machine, remove or adapt the ASUS/NVIDIA
sections. Remove the `/mnt/data` declaration if that disk is absent.

## Check and activate safely

From the repository root, evaluate and build without changing the running
system:

```bash
nix flake check --no-build
nix build --no-link --print-out-paths \
  .#nixosConfigurations.nixos-caelestia-cryoforge-real-greeter.config.system.build.toplevel
```

Test a candidate configuration without changing the boot default:

```bash
sudo nixos-rebuild test \
  --flake .#nixos-caelestia-cryoforge-real-greeter
```

After visual testing succeeds, apply it persistently:

```bash
sudo nixos-rebuild switch \
  --flake .#nixos-caelestia-cryoforge-real-greeter
```

For a fresh installer environment, mount the target system at `/mnt`, place
the repository inside it, then use the same full target with `nixos-install`.

## Verify core tooling

Open a new terminal after activation:

```bash
python3 --version
py310 --version
dotnet --version
blender --version
libreoffice --version
codex --version
docker --version
kubectl version --client
kaggle --version
```

Expected compatibility interpreters:

```text
Python 3.13.x  main CUDA/ML environment
Python 3.10.16 py310 compatibility interpreter
.NET 9.x       VS Code Polyglot Notebooks SDK
```

Create an isolated Python 3.10 environment for legacy projects:

```bash
cd /path/to/project
py310 -m venv venv
source venv/bin/activate
python --version
python -m pip install --upgrade pip
deactivate
```

## Codex

The Nix configuration includes a pinned Codex package. To use the newest
official standalone release instead:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh \
  | CODEX_NON_INTERACTIVE=1 sh
codex --version
```

Never commit passwords, API keys, Kaggle tokens, or private keys to this
repository.

## Home Manager collisions

If activation reports that a file would be clobbered, inspect the actual error:

```bash
sudo systemctl status home-manager-accelra.service --no-pager -l
sudo journalctl -u home-manager-accelra.service -b --no-pager
```

Common paths are:

```text
~/.config/caelestia/cli.json
~/.config/hypr
~/.config/kitty
```

Back up user-owned paths before moving them:

```bash
mkdir -p ~/.config/hm-backup
cp -a ~/.config/caelestia/cli.json ~/.config/hm-backup/ 2>/dev/null || true
cp -a ~/.config/hypr ~/.config/hm-backup/ 2>/dev/null || true
cp -a ~/.config/kitty ~/.config/hm-backup/ 2>/dev/null || true
```

## Rollback

List NixOS generations:

```bash
sudo nix-env -p /nix/var/nix/profiles/system --list-generations
```

Switch to a known-good generation and set it as the next boot:

```bash
sudo nix-env -p /nix/var/nix/profiles/system --switch-generation <NUMBER>
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
readlink -f /nix/var/nix/profiles/system
```

Do not delete the previous working generation until the new one has passed
login, desktop startup, Home Manager activation, and reboot. Afterward, remove
only the known-bad generation:

```bash
sudo nix-env -p /nix/var/nix/profiles/system --delete-generations <NUMBER>
```

## Updating the repository

```bash
git status
git pull --ff-only
git log --oneline -8
```

Review all configuration changes and follow the check → build → test → switch
sequence above. Keep a working terminal or TTY open during test activation.
