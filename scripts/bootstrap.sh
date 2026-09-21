#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
target="${NIXOS_TARGET:-nixos-caelestia-cryoforge-real-greeter}"
flake_ref="$repo_root#$target"
build_ref="$repo_root#nixosConfigurations.$target.config.system.build.toplevel"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/bootstrap.sh codex
  ./scripts/bootstrap.sh check
  ./scripts/bootstrap.sh all --yes

Commands:
  codex       Install or update the official standalone Codex CLI only.
  check       Dry-run the configured NixOS target without activation.
  all --yes   Build and activate the full target after hardware review.

Environment:
  NIXOS_TARGET   Override the NixOS flake output (default: the CryoForge
                 real-greeter profile).
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  }
}

install_codex() {
  require_command curl
  printf '%s\n' 'Installing the official standalone Codex CLI...'
  curl -fsSL https://chatgpt.com/codex/install.sh \
    | CODEX_NON_INTERACTIVE=1 sh
  command -v codex >/dev/null 2>&1 && codex --version || true
}

check_target() {
  require_command nix
  printf 'Dry-running NixOS target: %s\n' "$build_ref"
  nix build --no-link --dry-run --no-write-lock-file \
    "$build_ref"
}

activate_target() {
  require_command nix
  require_command sudo
  printf 'Activating NixOS target: %s\n' "$flake_ref"
  sudo nixos-rebuild switch \
    --flake "$flake_ref" \
    --no-write-lock-file
}

main() {
  local command="${1:-help}"

  case "$command" in
    codex)
      install_codex
      ;;
    check)
      check_target
      ;;
    all)
      if [[ "${2:-}" != "--yes" ]]; then
        printf '%s\n' \
          'Refusing full activation without explicit confirmation.' \
          'Review hardware-configuration.nix and configuration.nix first, then run:' \
          '  ./scripts/bootstrap.sh all --yes' >&2
        exit 2
      fi
      check_target
      activate_target
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      printf 'Unknown command: %s\n\n' "$command" >&2
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
