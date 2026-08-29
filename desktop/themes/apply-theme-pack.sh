#!/usr/bin/env bash

set -euo pipefail

readonly approved_denia_sha256=34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb
readonly neutral_scheme=@NEUTRAL_SCHEME@
readonly denia_scheme=@DENIA_SCHEME@
readonly denia_wallpaper=@DENIA_WALLPAPER@

declare -a snapshot_targets=()
declare -a snapshot_backups=()
declare -a snapshot_existed=()
declare -a snapshot_link_targets=()
declare -a snapshot_link_values=()
declare -a snapshot_link_existed=()
declare -a temporary_files=()
declare -a created_directories=()
transaction_committed=false
transaction_lock_directory=
transaction_lock_acquired=false

fail() {
  printf 'cryoforge-theme-error: %s\n' "$*" >&2
  exit 1
}

assert_absolute() {
  case "$1" in
    /*) ;;
    *) fail "XDG paths must be absolute" ;;
  esac
  case "/${1#/}/" in
    */../* | */./*) fail "XDG paths must not contain traversal components" ;;
  esac
}

assert_no_symlink_components() {
  local path=$1
  local current=/
  local component
  local -a components=()

  IFS=/ read -r -a components <<< "${path#/}"
  for component in "${components[@]}"; do
    [[ -n "$component" ]] || continue
    if [[ "$current" == / ]]; then
      current="/$component"
    else
      current="$current/$component"
    fi
    [[ ! -L "$current" ]] || fail "refusing symlink path: $current"
  done
}

ensure_directory() {
  local path=$1
  local parent

  assert_no_symlink_components "$path"
  if [[ -e "$path" ]]; then
    [[ -d "$path" ]] || fail "expected directory: $path"
    return
  fi

  parent=$(dirname -- "$path")
  if [[ "$parent" != "$path" && ! -e "$parent" ]]; then
    ensure_directory "$parent"
  fi

  install -d -m 0700 -- "$path"
  created_directories+=("$path")
}

snapshot_file() {
  local target=$1
  local parent
  local backup=
  local existed=false

  assert_no_symlink_components "$target"
  parent=$(dirname -- "$target")
  ensure_directory "$parent"

  if [[ -e "$target" ]]; then
    [[ -f "$target" ]] || fail "expected regular file: $target"
    backup=$(mktemp "$parent/.$(basename -- "$target").cryoforge-backup.XXXXXX")
    cp -p -- "$target" "$backup"
    existed=true
  fi

  snapshot_targets+=("$target")
  snapshot_backups+=("$backup")
  snapshot_existed+=("$existed")
}

snapshot_link() {
  local target=$1
  local parent
  local value=
  local existed=false

  parent=$(dirname -- "$target")
  assert_no_symlink_components "$parent"
  ensure_directory "$parent"

  if [[ -L "$target" ]]; then
    value=$(readlink -- "$target")
    existed=true
  elif [[ -e "$target" ]]; then
    fail "expected symbolic link: $target"
  fi

  snapshot_link_targets+=("$target")
  snapshot_link_values+=("$value")
  snapshot_link_existed+=("$existed")
}

register_temporary() {
  temporary_files+=("$1")
}

atomic_install() {
  local source=$1
  local target=$2
  local parent
  local temporary

  parent=$(dirname -- "$target")
  temporary=$(mktemp "$parent/.$(basename -- "$target").cryoforge-write.XXXXXX")
  register_temporary "$temporary"
  install -m 0600 -- "$source" "$temporary"
  mv -fT -- "$temporary" "$target"
}

atomic_write_line() {
  local value=$1
  local target=$2
  local parent
  local temporary

  parent=$(dirname -- "$target")
  temporary=$(mktemp "$parent/.$(basename -- "$target").cryoforge-write.XXXXXX")
  register_temporary "$temporary"
  printf '%s\n' "$value" > "$temporary"
  chmod 0600 -- "$temporary"
  mv -fT -- "$temporary" "$target"
}

atomic_link() {
  local value=$1
  local target=$2
  local parent
  local temporary

  parent=$(dirname -- "$target")
  temporary=$(mktemp "$parent/.$(basename -- "$target").cryoforge-write.XXXXXX")
  register_temporary "$temporary"
  ln -sfn -- "$value" "$temporary"
  mv -fT -- "$temporary" "$target"
}

maybe_fail() {
  if [[ "${CRYOFORGE_THEME_TEST_FAIL_STEP:-}" == "$1" ]]; then
    fail "injected failure at $1"
  fi
}

rollback_files() {
  local index
  local target
  local backup

  set +e
  for ((index = ${#snapshot_targets[@]} - 1; index >= 0; index--)); do
    target=${snapshot_targets[index]}
    backup=${snapshot_backups[index]}
    if [[ "${snapshot_existed[index]}" == true ]]; then
      rm -f -- "$target"
      mv -fT -- "$backup" "$target"
    else
      rm -f -- "$target"
    fi
  done

}

rollback_links() {
  local index
  local target
  local value

  set +e
  for ((index = ${#snapshot_link_targets[@]} - 1; index >= 0; index--)); do
    target=${snapshot_link_targets[index]}
    value=${snapshot_link_values[index]}
    rm -f -- "$target"
    if [[ "${snapshot_link_existed[index]}" == true ]]; then
      ln -s -- "$value" "$target"
    fi
  done
}

cleanup_created_directories() {
  local index

  set +e
  for ((index = ${#created_directories[@]} - 1; index >= 0; index--)); do
    rmdir -- "${created_directories[index]}" 2>/dev/null || true
  done
}

cleanup_transaction_files() {
  local path

  set +e
  for path in "${temporary_files[@]}" "${snapshot_backups[@]}"; do
    [[ -n "$path" ]] || continue
    rm -f -- "$path"
  done
}

release_transaction_lock() {
  if [[ "$transaction_lock_acquired" == true ]]; then
    rmdir -- "$transaction_lock_directory" 2>/dev/null || true
    transaction_lock_acquired=false
  fi
}

finish_transaction() {
  local status=$?

  trap - EXIT
  if [[ "$transaction_committed" != true ]]; then
    rollback_links
    rollback_files
  fi
  cleanup_transaction_files
  release_transaction_lock
  if [[ "$transaction_committed" != true ]]; then
    cleanup_created_directories
  fi
  exit "$status"
}

trap finish_transaction EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

[[ $# -eq 1 ]] || fail "usage: cryoforge-apply-theme-pack neutral|cryoforge-denia"
readonly pack_id=$1

case "$pack_id" in
  neutral | cryoforge-denia) ;;
  *) fail "unsupported pack id: $pack_id" ;;
esac

readonly home=${HOME:?HOME is required}
readonly state_home=${XDG_STATE_HOME:-"$home/.local/state"}
readonly data_home=${XDG_DATA_HOME:-"$home/.local/share"}
assert_absolute "$state_home"
assert_absolute "$data_home"

readonly caelestia_state_dir="$state_home/caelestia"
readonly scheme_target="$caelestia_state_dir/scheme.json"
readonly wallpaper_state_dir="$caelestia_state_dir/wallpaper"
readonly wallpaper_state_target="$wallpaper_state_dir/path.txt"
readonly wallpaper_link_target="$wallpaper_state_dir/current"
readonly denia_data_dir="$data_home/cryoforge/theme-packs/cryoforge-denia"
readonly denia_wallpaper_target="$denia_data_dir/wallpaper.jpg"

umask 077

ensure_directory "$caelestia_state_dir"
transaction_lock_directory="$caelestia_state_dir/.cryoforge-theme-apply.lock"
assert_no_symlink_components "$transaction_lock_directory"
if ! mkdir -m 0700 -- "$transaction_lock_directory"; then
  fail "another theme apply is already running"
fi
transaction_lock_acquired=true

if [[ "$pack_id" == neutral ]]; then
  snapshot_file "$scheme_target"
  atomic_install "$neutral_scheme" "$scheme_target"
  maybe_fail after-scheme
else
  actual_sha256=$(sha256sum -- "$denia_wallpaper")
  actual_sha256=${actual_sha256%% *}
  [[ "$actual_sha256" == "$approved_denia_sha256" ]] \
    || fail "approved Denia wallpaper hash mismatch"

  snapshot_file "$denia_wallpaper_target"
  snapshot_file "$scheme_target"
  snapshot_file "$wallpaper_state_target"
  snapshot_link "$wallpaper_link_target"

  atomic_install "$denia_wallpaper" "$denia_wallpaper_target"
  copied_sha256=$(sha256sum -- "$denia_wallpaper_target")
  copied_sha256=${copied_sha256%% *}
  [[ "$copied_sha256" == "$approved_denia_sha256" ]] \
    || fail "copied Denia wallpaper hash mismatch"
  maybe_fail after-wallpaper-copy

  atomic_install "$denia_scheme" "$scheme_target"
  maybe_fail after-scheme

  atomic_write_line "$denia_wallpaper_target" "$wallpaper_state_target"
  maybe_fail after-wallpaper-state

  atomic_link "$denia_wallpaper_target" "$wallpaper_link_target"
  maybe_fail after-wallpaper-link
fi

transaction_committed=true
printf '{"ok":true,"packId":"%s"}\n' "$pack_id"
