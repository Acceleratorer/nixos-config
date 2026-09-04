#!/usr/bin/env bash

set -euo pipefail

readonly phase19d_publication_enabled=@PUBLICATION_ENABLED@

phase19c_apply_theme_pack() {
readonly approved_denia_sha256=34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb
readonly neutral_scheme=@NEUTRAL_SCHEME@
readonly denia_scheme=@DENIA_SCHEME@
readonly denia_wallpaper=@DENIA_WALLPAPER@

declare -a snapshot_targets=()
declare -a snapshot_backups=()
declare -a snapshot_existed=()
declare -a snapshot_backup_modes=()
declare -a snapshot_backup_sha256=()
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
    snapshot_backup_modes+=("$(stat -c '%a' -- "$backup")")
    snapshot_backup_sha256+=("$(sha256sum -- "$backup")")
    snapshot_backup_sha256[-1]=${snapshot_backup_sha256[-1]%% *}
  else
    snapshot_backup_modes+=("")
    snapshot_backup_sha256+=("")
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

# Reached through the EXIT transaction trap cleanup chain.
# shellcheck disable=SC2329
atomic_restore_file() {
  local target=$1
  local backup=$2
  local expected_mode=$3
  local expected_sha256=$4
  local parent
  local actual_sha256

  parent=$(dirname -- "$target") || return 1
  if ! (assert_no_symlink_components "$parent"); then
    return 1
  fi
  [[ -d "$parent" && ! -L "$parent" ]] || return 1
  [[ "$(dirname -- "$backup")" == "$parent" ]] || return 1
  [[ -f "$backup" && ! -L "$backup" ]] || return 1
  [[ "$(stat -c '%h:%a' -- "$backup")" == "1:$expected_mode" ]] || return 1
  actual_sha256=$(sha256sum -- "$backup") || return 1
  [[ ${actual_sha256%% *} == "$expected_sha256" ]] || return 1
  [[ -f "$target" && ! -L "$target" ]] || return 1
  mv -fT -- "$backup" "$target"
}

# Reached through the EXIT transaction trap cleanup chain.
# shellcheck disable=SC2329
atomic_restore_link() {
  local target=$1
  local value=$2
  local parent
  local temporary

  parent=$(dirname -- "$target") || return 1
  if ! (assert_no_symlink_components "$parent"); then
    return 1
  fi
  [[ -d "$parent" && ! -L "$parent" ]] || return 1
  [[ -L "$target" ]] || return 1
  temporary=$(mktemp "$parent/.$(basename -- "$target").cryoforge-rollback.XXXXXX") ||
    return 1
  register_temporary "$temporary"
  rm -f -- "$temporary" || return 1
  ln -s -- "$value" "$temporary" || return 1
  mv -fT -- "$temporary" "$target"
}

# Reached through the EXIT transaction trap cleanup chain.
# shellcheck disable=SC2329
remove_created_file() {
  local target=$1
  local parent

  parent=$(dirname -- "$target") || return 1
  if ! (assert_no_symlink_components "$parent"); then
    return 1
  fi
  [[ -d "$parent" && ! -L "$parent" ]] || return 1
  if [[ -e "$target" || -L "$target" ]]; then
    [[ -f "$target" && ! -L "$target" ]] || return 1
    rm -f -- "$target"
  fi
}

# Reached through the EXIT transaction trap cleanup chain.
# shellcheck disable=SC2329
remove_created_link() {
  local target=$1
  local parent

  parent=$(dirname -- "$target") || return 1
  if ! (assert_no_symlink_components "$parent"); then
    return 1
  fi
  [[ -d "$parent" && ! -L "$parent" ]] || return 1
  if [[ -e "$target" || -L "$target" ]]; then
    [[ -L "$target" ]] || return 1
    rm -f -- "$target"
  fi
}

# Reached through the EXIT transaction trap cleanup chain.
# shellcheck disable=SC2329
rollback_files() {
  local index
  local target
  local backup

  set +e
  for ((index = ${#snapshot_targets[@]} - 1; index >= 0; index--)); do
    target=${snapshot_targets[index]}
    backup=${snapshot_backups[index]}
    if [[ "${snapshot_existed[index]}" == true ]]; then
      atomic_restore_file \
        "$target" \
        "$backup" \
        "${snapshot_backup_modes[index]}" \
        "${snapshot_backup_sha256[index]}" || true
    else
      remove_created_file "$target" || true
    fi
  done

}

# Reached through the EXIT transaction trap cleanup chain.
# shellcheck disable=SC2329
rollback_links() {
  local index
  local target
  local value

  set +e
  for ((index = ${#snapshot_link_targets[@]} - 1; index >= 0; index--)); do
    target=${snapshot_link_targets[index]}
    value=${snapshot_link_values[index]}
    if [[ "${snapshot_link_existed[index]}" == true ]]; then
      atomic_restore_link "$target" "$value" || true
    else
      remove_created_link "$target" || true
    fi
  done
}

# Reached through the EXIT transaction trap cleanup chain.
# shellcheck disable=SC2329
cleanup_created_directories() {
  local index

  set +e
  for ((index = ${#created_directories[@]} - 1; index >= 0; index--)); do
    rmdir -- "${created_directories[index]}" 2>/dev/null || true
  done
}

# Reached through the EXIT transaction trap cleanup chain.
# shellcheck disable=SC2329
cleanup_transaction_files() {
  local path

  set +e
  for path in "${temporary_files[@]}" "${snapshot_backups[@]}"; do
    [[ -n "$path" ]] || continue
    rm -f -- "$path"
  done
}

# Reached through the EXIT transaction trap cleanup chain.
# shellcheck disable=SC2329
release_transaction_lock() {
  if [[ "$transaction_lock_acquired" == true ]]; then
    rmdir -- "$transaction_lock_directory" 2>/dev/null || true
    transaction_lock_acquired=false
  fi
}

# Registered below as the EXIT transaction trap handler.
# shellcheck disable=SC2329
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
}

if [[ "$phase19d_publication_enabled" == 0 ]]; then
  phase19c_apply_theme_pack "$@"
  exit
fi

readonly phase19d_chisa_scheme=@CHISA_SCHEME@
readonly phase19d_neutral_scheme=@NEUTRAL_SCHEME@
readonly phase19d_denia_scheme=@DENIA_SCHEME@
readonly phase19d_resolver=@RESOLVER@
readonly phase19d_publisher_invoker=@PUBLISHER_INVOKER@
readonly phase19d_python=@PYTHON@
readonly phase19d_test_failures_enabled=@TEST_FAILURES_ENABLED@

declare -a phase19d_snapshot_targets=()
declare -a phase19d_snapshot_backups=()
declare -a phase19d_snapshot_existed=()
declare -a phase19d_snapshot_backup_modes=()
declare -a phase19d_snapshot_backup_sha256=()
declare -a phase19d_snapshot_link_targets=()
declare -a phase19d_snapshot_link_values=()
declare -a phase19d_snapshot_link_existed=()
declare -a phase19d_temporary_paths=()
declare -a phase19d_created_directories=()
phase19d_transaction_complete=false
phase19d_public_committed=false
phase19d_interrupted=false
phase19d_lock_acquired=false
phase19d_lock_directory=
phase19d_prior_pack_id=
phase19d_prior_wallpaper_pack_id=
phase19d_committed_generation=

phase19d_fail() {
  printf 'cryoforge-theme-error: %s\n' "$*" >&2
  exit 1
}

phase19d_assert_absolute() {
  case "$1" in
    /*) ;;
    *) phase19d_fail "XDG paths must be absolute" ;;
  esac
  case "/${1#/}/" in
    */../* | */./*) phase19d_fail "XDG paths must not contain traversal components" ;;
  esac
}

phase19d_assert_no_symlink_components() {
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
    [[ ! -L "$current" ]] || phase19d_fail "refusing symlink path: $current"
  done
}

phase19d_ensure_directory() {
  local path=$1
  local parent

  phase19d_assert_no_symlink_components "$path"
  if [[ -e "$path" ]]; then
    [[ -d "$path" ]] || phase19d_fail "expected directory: $path"
    return
  fi

  parent=$(dirname -- "$path")
  if [[ "$parent" != "$path" && ! -e "$parent" ]]; then
    phase19d_ensure_directory "$parent"
  fi
  install -d -m 0700 -- "$path"
  phase19d_created_directories+=("$path")
}

phase19d_snapshot_file() {
  local target=$1
  local parent
  local backup=
  local existed=false

  phase19d_assert_no_symlink_components "$target"
  parent=$(dirname -- "$target")
  phase19d_ensure_directory "$parent"
  if [[ -e "$target" ]]; then
    [[ -f "$target" ]] || phase19d_fail "expected regular file: $target"
    backup=$(mktemp "$parent/.$(basename -- "$target").cryoforge-backup.XXXXXX")
    cp -p -- "$target" "$backup"
    existed=true
    phase19d_snapshot_backup_modes+=("$(stat -c '%a' -- "$backup")")
    phase19d_snapshot_backup_sha256+=("$(sha256sum -- "$backup")")
    phase19d_snapshot_backup_sha256[-1]=${phase19d_snapshot_backup_sha256[-1]%% *}
  else
    phase19d_snapshot_backup_modes+=("")
    phase19d_snapshot_backup_sha256+=("")
  fi
  phase19d_snapshot_targets+=("$target")
  phase19d_snapshot_backups+=("$backup")
  phase19d_snapshot_existed+=("$existed")
}

phase19d_snapshot_link() {
  local target=$1
  local parent
  local value=
  local existed=false

  parent=$(dirname -- "$target")
  phase19d_assert_no_symlink_components "$parent"
  phase19d_ensure_directory "$parent"
  if [[ -L "$target" ]]; then
    value=$(readlink -- "$target")
    existed=true
  elif [[ -e "$target" ]]; then
    phase19d_fail "expected symbolic link: $target"
  fi
  phase19d_snapshot_link_targets+=("$target")
  phase19d_snapshot_link_values+=("$value")
  phase19d_snapshot_link_existed+=("$existed")
}

phase19d_register_temporary() {
  phase19d_temporary_paths+=("$1")
}

phase19d_stage_file() {
  local source=$1
  local target=$2
  local parent
  local temporary

  parent=$(dirname -- "$target")
  temporary=$(mktemp "$parent/.$(basename -- "$target").cryoforge-stage.XXXXXX")
  phase19d_register_temporary "$temporary"
  install -m 0600 -- "$source" "$temporary"
  printf '%s\n' "$temporary"
}

phase19d_stage_line() {
  local value=$1
  local target=$2
  local parent
  local temporary

  parent=$(dirname -- "$target")
  temporary=$(mktemp "$parent/.$(basename -- "$target").cryoforge-stage.XXXXXX")
  phase19d_register_temporary "$temporary"
  printf '%s\n' "$value" > "$temporary"
  chmod 0600 -- "$temporary"
  printf '%s\n' "$temporary"
}

phase19d_stage_link() {
  local value=$1
  local target=$2
  local parent
  local temporary

  parent=$(dirname -- "$target")
  temporary=$(mktemp "$parent/.$(basename -- "$target").cryoforge-stage.XXXXXX")
  phase19d_register_temporary "$temporary"
  rm -f -- "$temporary"
  ln -s -- "$value" "$temporary"
  printf '%s\n' "$temporary"
}

phase19d_maybe_fail() {
  local step=$1

  if [[ "$phase19d_test_failures_enabled" == 1 \
    && "${CRYOFORGE_THEME_TEST_FAIL_STEP:-}" == "$step" ]]; then
    phase19d_fail "injected failure at $step"
  fi
}

phase19d_maybe_pause() {
  local step=$1
  local release_file=${CRYOFORGE_THEME_TEST_RELEASE_FILE:-}

  if [[ "$phase19d_test_failures_enabled" != 1 \
    || "${CRYOFORGE_THEME_TEST_PAUSE_STEP:-}" != "$step" ]]; then
    return
  fi
  [[ "$release_file" == /* ]] \
    || phase19d_fail "test release file must be absolute"
  if [[ -n "${CRYOFORGE_THEME_TEST_READY_FILE:-}" ]]; then
    [[ "$CRYOFORGE_THEME_TEST_READY_FILE" == /* ]] \
      || phase19d_fail "test ready file must be absolute"
    : > "$CRYOFORGE_THEME_TEST_READY_FILE"
  fi
  while [[ ! -e "$release_file" ]]; do
    sleep 0.01
  done
}

phase19d_parse_resolution() {
  "$phase19d_python" -c '
import json
import sys

value = json.load(sys.stdin)
required = {
    "schemaVersion", "packId", "wallpaperPackId", "generation", "source",
    "schemePath", "schemeSha256", "wallpaperPath", "wallpaperSha256",
    "thumbnailPath", "thumbnailSha256",
}
if set(value) != required or value["schemaVersion"] != 1:
    raise SystemExit(1)
fields = (
    value["packId"],
    value["wallpaperPackId"],
    value["generation"],
    value["source"],
    value["schemePath"],
    value["schemeSha256"],
    value["wallpaperPath"],
    value["wallpaperSha256"],
)
if any("\t" in str(field) or "\n" in str(field) for field in fields):
    raise SystemExit(1)
print("\t".join(str(field) for field in fields))
'
}

phase19d_parse_publication() {
  "$phase19d_python" -c '
import json
import sys

value = json.load(sys.stdin)
if set(value) != {
    "ok", "packId", "wallpaperPackId", "generation",
} or value["ok"] is not True:
    raise SystemExit(1)
fields = (value["packId"], value["wallpaperPackId"], value["generation"])
if any("\t" in str(field) or "\n" in str(field) for field in fields):
    raise SystemExit(1)
print("\t".join(str(field) for field in fields))
'
}

phase19d_resolve() {
  local raw

  raw=$("$phase19d_resolver") || phase19d_fail "canonical theme resolution failed"
  [[ ${#raw} -le 2048 ]] || phase19d_fail "canonical theme resolution was oversized"
  printf '%s' "$raw" | phase19d_parse_resolution \
    || phase19d_fail "canonical theme resolution was malformed"
}

# Reached through the EXIT transaction trap cleanup chain.
# shellcheck disable=SC2329
phase19d_atomic_restore_file() {
  local target=$1
  local backup=$2
  local expected_mode=$3
  local expected_sha256=$4
  local parent
  local actual_sha256

  parent=$(dirname -- "$target") || return 1
  if ! (phase19d_assert_no_symlink_components "$parent"); then
    return 1
  fi
  [[ -d "$parent" && ! -L "$parent" ]] || return 1
  [[ "$(dirname -- "$backup")" == "$parent" ]] || return 1
  [[ -f "$backup" && ! -L "$backup" ]] || return 1
  [[ "$(stat -c '%h:%a' -- "$backup")" == "1:$expected_mode" ]] || return 1
  actual_sha256=$(sha256sum -- "$backup") || return 1
  [[ ${actual_sha256%% *} == "$expected_sha256" ]] || return 1
  [[ -f "$target" && ! -L "$target" ]] || return 1
  phase19d_maybe_pause "rollback-before-file-replace-$(basename -- "$target")"
  mv -fT -- "$backup" "$target"
}

# Reached through the EXIT transaction trap cleanup chain.
# shellcheck disable=SC2329
phase19d_atomic_restore_link() {
  local target=$1
  local value=$2
  local parent
  local temporary

  parent=$(dirname -- "$target") || return 1
  if ! (phase19d_assert_no_symlink_components "$parent"); then
    return 1
  fi
  [[ -d "$parent" && ! -L "$parent" ]] || return 1
  [[ -L "$target" ]] || return 1
  temporary=$(mktemp "$parent/.$(basename -- "$target").cryoforge-rollback.XXXXXX") ||
    return 1
  phase19d_register_temporary "$temporary"
  rm -f -- "$temporary" || return 1
  ln -s -- "$value" "$temporary" || return 1
  phase19d_maybe_pause \
    "rollback-before-link-replace-$(basename -- "$target")"
  mv -fT -- "$temporary" "$target"
}

# Reached through the EXIT transaction trap cleanup chain.
# shellcheck disable=SC2329
phase19d_remove_created_file() {
  local target=$1
  local parent

  parent=$(dirname -- "$target") || return 1
  if ! (phase19d_assert_no_symlink_components "$parent"); then
    return 1
  fi
  [[ -d "$parent" && ! -L "$parent" ]] || return 1
  if [[ -e "$target" || -L "$target" ]]; then
    [[ -f "$target" && ! -L "$target" ]] || return 1
    rm -f -- "$target"
  fi
}

# Reached through the EXIT transaction trap cleanup chain.
# shellcheck disable=SC2329
phase19d_remove_created_link() {
  local target=$1
  local parent

  parent=$(dirname -- "$target") || return 1
  if ! (phase19d_assert_no_symlink_components "$parent"); then
    return 1
  fi
  [[ -d "$parent" && ! -L "$parent" ]] || return 1
  if [[ -e "$target" || -L "$target" ]]; then
    [[ -L "$target" ]] || return 1
    rm -f -- "$target"
  fi
}

phase19d_rollback_files() {
  local index
  local target
  local backup

  set +e
  for ((index = ${#phase19d_snapshot_targets[@]} - 1; index >= 0; index--)); do
    target=${phase19d_snapshot_targets[index]}
    backup=${phase19d_snapshot_backups[index]}
    if [[ "${phase19d_snapshot_existed[index]}" == true ]]; then
      phase19d_atomic_restore_file \
        "$target" \
        "$backup" \
        "${phase19d_snapshot_backup_modes[index]}" \
        "${phase19d_snapshot_backup_sha256[index]}" || true
    else
      phase19d_remove_created_file "$target" || true
    fi
  done
}

phase19d_rollback_links() {
  local index
  local target
  local value

  set +e
  for ((index = ${#phase19d_snapshot_link_targets[@]} - 1; index >= 0; index--)); do
    target=${phase19d_snapshot_link_targets[index]}
    value=${phase19d_snapshot_link_values[index]}
    if [[ "${phase19d_snapshot_link_existed[index]}" == true ]]; then
      phase19d_atomic_restore_link "$target" "$value" || true
    else
      phase19d_remove_created_link "$target" || true
    fi
  done
}

phase19d_cleanup() {
  local path
  local index

  set +e
  for path in "${phase19d_temporary_paths[@]}" "${phase19d_snapshot_backups[@]}"; do
    [[ -n "$path" ]] || continue
    rm -f -- "$path"
  done
  if [[ "$phase19d_lock_acquired" == true ]]; then
    rmdir -- "$phase19d_lock_directory" 2>/dev/null || true
    phase19d_lock_acquired=false
  fi
  if [[ "$phase19d_transaction_complete" != true ]]; then
    for ((index = ${#phase19d_created_directories[@]} - 1; index >= 0; index--)); do
      rmdir -- "${phase19d_created_directories[index]}" 2>/dev/null || true
    done
  fi
}

phase19d_compensate() {
  local output
  local parsed
  local compensated_pack
  local compensated_wallpaper
  local compensated_generation
  local expected_generation
  local resolved
  local resolved_pack
  local resolved_wallpaper
  local resolved_generation
  local resolved_source
  local _resolved_scheme
  local _resolved_scheme_sha256
  local _resolved_wallpaper_path
  local _resolved_wallpaper_sha256

  output=$(
    "$phase19d_publisher_invoker" \
      "$phase19d_prior_pack_id" \
      "$phase19d_prior_wallpaper_pack_id" \
      "$phase19d_committed_generation"
  ) || return 1
  parsed=$(printf '%s' "$output" | phase19d_parse_publication) || return 1
  IFS=$'\t' read -r \
    compensated_pack \
    compensated_wallpaper \
    compensated_generation <<< "$parsed"
  expected_generation=$((phase19d_committed_generation + 1))
  [[ "$compensated_pack" == "$phase19d_prior_pack_id" ]]
  [[ "$compensated_wallpaper" == "$phase19d_prior_wallpaper_pack_id" ]]
  [[ "$compensated_generation" == "$expected_generation" ]]

  resolved=$("$phase19d_resolver" 2>/dev/null) || return 1
  [[ ${#resolved} -le 2048 ]] || return 1
  parsed=$(printf '%s' "$resolved" | phase19d_parse_resolution) || return 1
  IFS=$'\t' read -r \
    resolved_pack \
    resolved_wallpaper \
    resolved_generation \
    resolved_source \
    _resolved_scheme \
    _resolved_scheme_sha256 \
    _resolved_wallpaper_path \
    _resolved_wallpaper_sha256 <<< "$parsed"
  [[ "$resolved_pack" == "$phase19d_prior_pack_id" ]]
  [[ "$resolved_wallpaper" == "$phase19d_prior_wallpaper_pack_id" ]]
  [[ "$resolved_generation" == "$expected_generation" ]]
  [[ "$resolved_source" == public ]]
}

phase19d_report_reconciliation_required() {
  local output
  local parsed
  local current_pack
  local current_wallpaper
  local current_generation
  local _current_source
  local _current_scheme
  local _current_scheme_sha256
  local _current_wallpaper_path
  local _current_wallpaper_sha256

  output=$("$phase19d_resolver" 2>/dev/null) || output=
  if [[ -n "$output" && ${#output} -le 2048 ]]; then
    parsed=$(printf '%s' "$output" | phase19d_parse_resolution) || parsed=
  else
    parsed=
  fi
  if [[ -n "$parsed" ]]; then
    IFS=$'\t' read -r \
      current_pack \
      current_wallpaper \
      current_generation \
      _current_source \
      _current_scheme \
      _current_scheme_sha256 \
      _current_wallpaper_path \
      _current_wallpaper_sha256 <<< "$parsed"
    printf '%s\n' \
      "cryoforge-theme-error: public theme committed; reconciliation required; canonical=$current_pack/$current_wallpaper generation=$current_generation" \
      >&2
  else
    printf '%s\n' \
      'cryoforge-theme-error: public theme committed; reconciliation required; canonical resolution unavailable' \
      >&2
  fi
}

phase19d_finish() {
  local status=$?

  trap - EXIT HUP INT TERM
  if [[ "$phase19d_transaction_complete" != true ]]; then
    if [[ "$phase19d_public_committed" == true \
      && "$phase19d_interrupted" != true ]]; then
      phase19d_maybe_pause before-compensation
      if phase19d_compensate; then
        :
      else
        phase19d_report_reconciliation_required
      fi
    fi
    phase19d_rollback_links
    phase19d_rollback_files
  fi
  phase19d_cleanup
  exit "$status"
}

phase19d_interrupt() {
  phase19d_interrupted=true
  exit "$1"
}

trap phase19d_finish EXIT
trap 'phase19d_interrupt 129' HUP
trap 'phase19d_interrupt 130' INT
trap 'phase19d_interrupt 143' TERM

[[ $# -eq 1 ]] || phase19d_fail \
  "usage: cryoforge-apply-theme-pack --reconcile|neutral|chisa-pool|cryoforge-denia"
readonly phase19d_request=$1
case "$phase19d_request" in
  --reconcile | neutral | chisa-pool | cryoforge-denia) ;;
  *) phase19d_fail "unsupported pack id: $phase19d_request" ;;
esac

readonly phase19d_home=${HOME:?HOME is required}
readonly phase19d_state_home=${XDG_STATE_HOME:-"$phase19d_home/.local/state"}
readonly phase19d_state_dir="$phase19d_state_home/caelestia"
readonly phase19d_wallpaper_dir="$phase19d_state_dir/wallpaper"
readonly phase19d_scheme_target="$phase19d_state_dir/scheme.json"
readonly phase19d_wallpaper_state_target="$phase19d_wallpaper_dir/path.txt"
readonly phase19d_wallpaper_link_target="$phase19d_wallpaper_dir/current"

phase19d_assert_absolute "$phase19d_home"
phase19d_assert_absolute "$phase19d_state_home"
umask 077
phase19d_ensure_directory "$phase19d_home"
phase19d_ensure_directory "$phase19d_state_dir"
phase19d_ensure_directory "$phase19d_wallpaper_dir"

phase19d_lock_directory="$phase19d_state_dir/.cryoforge-theme-apply.lock"
phase19d_assert_no_symlink_components "$phase19d_lock_directory"
if ! mkdir -m 0700 -- "$phase19d_lock_directory"; then
  phase19d_fail "another theme apply is already running"
fi
phase19d_lock_acquired=true

phase19d_current=$(
  phase19d_resolve
)
IFS=$'\t' read -r \
  phase19d_current_pack \
  phase19d_current_wallpaper_pack \
  phase19d_current_generation \
  phase19d_current_source \
  phase19d_current_scheme_path \
  phase19d_current_scheme_sha256 \
  phase19d_current_wallpaper_path \
  phase19d_current_wallpaper_sha256 <<< "$phase19d_current"

phase19d_prior_pack_id=$phase19d_current_pack
phase19d_prior_wallpaper_pack_id=$phase19d_current_wallpaper_pack

[[ "$phase19d_current_source" == public \
  || "$phase19d_current_source" == fallback ]]

case "$phase19d_request" in
  --reconcile)
    phase19d_target_pack=$phase19d_current_pack
    phase19d_target_wallpaper_pack=$phase19d_current_wallpaper_pack
    phase19d_target_scheme_path=$phase19d_current_scheme_path
    phase19d_target_scheme_sha256=$phase19d_current_scheme_sha256
    phase19d_target_wallpaper_path=$phase19d_current_wallpaper_path
    phase19d_target_wallpaper_sha256=$phase19d_current_wallpaper_sha256
    ;;
  neutral)
    phase19d_target_pack=neutral
    phase19d_target_wallpaper_pack=$phase19d_current_wallpaper_pack
    phase19d_target_scheme_path=$phase19d_neutral_scheme
    phase19d_target_scheme_sha256=$(sha256sum -- "$phase19d_target_scheme_path")
    phase19d_target_scheme_sha256=${phase19d_target_scheme_sha256%% *}
    phase19d_target_wallpaper_path=$phase19d_current_wallpaper_path
    phase19d_target_wallpaper_sha256=$phase19d_current_wallpaper_sha256
    ;;
  chisa-pool)
    phase19d_target_pack=chisa-pool
    phase19d_target_wallpaper_pack=chisa-pool
    phase19d_target_scheme_path=$phase19d_chisa_scheme
    phase19d_target_scheme_sha256=$(sha256sum -- "$phase19d_target_scheme_path")
    phase19d_target_scheme_sha256=${phase19d_target_scheme_sha256%% *}
    phase19d_target_wallpaper_path=@CHISA_WALLPAPER@
    phase19d_target_wallpaper_sha256=a4dfcf92c4170405ac37102b27c606c5e9b1bb6cd77c9f04d530fa752aab604c
    ;;
  cryoforge-denia)
    phase19d_target_pack=cryoforge-denia
    phase19d_target_wallpaper_pack=cryoforge-denia
    phase19d_target_scheme_path=$phase19d_denia_scheme
    phase19d_target_scheme_sha256=$(sha256sum -- "$phase19d_target_scheme_path")
    phase19d_target_scheme_sha256=${phase19d_target_scheme_sha256%% *}
    phase19d_target_wallpaper_path=@DENIA_WALLPAPER@
    phase19d_target_wallpaper_sha256=34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb
    ;;
esac

[[ -f "$phase19d_target_scheme_path" && ! -L "$phase19d_target_scheme_path" ]] \
  || phase19d_fail "approved scheme is unavailable"
[[ -f "$phase19d_target_wallpaper_path" && ! -L "$phase19d_target_wallpaper_path" ]] \
  || phase19d_fail "approved wallpaper is unavailable"
phase19d_actual_scheme_sha256=$(sha256sum -- "$phase19d_target_scheme_path")
phase19d_actual_scheme_sha256=${phase19d_actual_scheme_sha256%% *}
[[ "$phase19d_actual_scheme_sha256" == "$phase19d_target_scheme_sha256" ]] \
  || phase19d_fail "approved scheme hash mismatch"
phase19d_actual_wallpaper_sha256=$(sha256sum -- "$phase19d_target_wallpaper_path")
phase19d_actual_wallpaper_sha256=${phase19d_actual_wallpaper_sha256%% *}
[[ "$phase19d_actual_wallpaper_sha256" == "$phase19d_target_wallpaper_sha256" ]] \
  || phase19d_fail "approved wallpaper hash mismatch"

phase19d_snapshot_file "$phase19d_scheme_target"
phase19d_snapshot_file "$phase19d_wallpaper_state_target"
phase19d_snapshot_link "$phase19d_wallpaper_link_target"

phase19d_scheme_stage=$(
  phase19d_stage_file "$phase19d_target_scheme_path" "$phase19d_scheme_target"
)
phase19d_register_temporary "$phase19d_scheme_stage"
phase19d_wallpaper_state_stage=$(
  phase19d_stage_line "$phase19d_target_wallpaper_path" "$phase19d_wallpaper_state_target"
)
phase19d_register_temporary "$phase19d_wallpaper_state_stage"
phase19d_wallpaper_link_stage=$(
  phase19d_stage_link "$phase19d_target_wallpaper_path" "$phase19d_wallpaper_link_target"
)
phase19d_register_temporary "$phase19d_wallpaper_link_stage"
phase19d_maybe_pause after-stage
phase19d_maybe_fail after-stage

if [[ "$phase19d_request" != --reconcile ]]; then
  phase19d_maybe_pause before-publication
  phase19d_publication_output=$(
    "$phase19d_publisher_invoker" \
      "$phase19d_target_pack" \
      "$phase19d_target_wallpaper_pack" \
      "$phase19d_current_generation"
  ) || phase19d_fail "canonical publication was refused"
  phase19d_committed_generation=$((phase19d_current_generation + 1))
  phase19d_public_committed=true
  [[ ${#phase19d_publication_output} -le 256 ]] \
    || phase19d_fail "canonical publication output was oversized"
  phase19d_publication_parsed=$(
    printf '%s' "$phase19d_publication_output" | phase19d_parse_publication
  ) || phase19d_fail "canonical publication output was malformed"
  IFS=$'\t' read -r \
    phase19d_published_pack \
    phase19d_published_wallpaper_pack \
    phase19d_reported_generation <<< "$phase19d_publication_parsed"
  [[ "$phase19d_published_pack" == "$phase19d_target_pack" ]]
  [[ "$phase19d_published_wallpaper_pack" == "$phase19d_target_wallpaper_pack" ]]
  [[ "$phase19d_reported_generation" == "$phase19d_committed_generation" ]]
  phase19d_maybe_pause after-publication
  phase19d_maybe_fail after-publication
fi

mv -fT -- "$phase19d_scheme_stage" "$phase19d_scheme_target"
phase19d_maybe_fail after-scheme-promotion
mv -fT -- "$phase19d_wallpaper_state_stage" "$phase19d_wallpaper_state_target"
phase19d_maybe_fail after-wallpaper-state-promotion
mv -fT -- "$phase19d_wallpaper_link_stage" "$phase19d_wallpaper_link_target"
phase19d_maybe_fail after-wallpaper-link-promotion

phase19d_verified=$(
  phase19d_resolve
)
IFS=$'\t' read -r \
  phase19d_verified_pack \
  phase19d_verified_wallpaper_pack \
  phase19d_verified_generation \
  phase19d_verified_source \
  _phase19d_verified_scheme_path \
  phase19d_verified_scheme_sha256 \
  phase19d_verified_wallpaper_path \
  phase19d_verified_wallpaper_sha256 <<< "$phase19d_verified"

[[ "$phase19d_verified_pack" == "$phase19d_target_pack" ]]
[[ "$phase19d_verified_wallpaper_pack" == "$phase19d_target_wallpaper_pack" ]]
if [[ "$phase19d_request" != --reconcile ]]; then
  [[ "$phase19d_verified_source" == public ]]
  [[ "$phase19d_verified_generation" == "$phase19d_committed_generation" ]]
fi
# The resolver and coordinator package independent immutable scheme
# projections; their approved content hash, not store-path identity, must agree.
[[ "$phase19d_verified_scheme_sha256" == "$phase19d_target_scheme_sha256" ]]
[[ "$phase19d_verified_wallpaper_path" == "$phase19d_target_wallpaper_path" ]]
[[ "$phase19d_verified_wallpaper_sha256" == "$phase19d_target_wallpaper_sha256" ]]
[[ "$(sha256sum -- "$phase19d_scheme_target" | cut -d ' ' -f 1)" == \
  "$phase19d_verified_scheme_sha256" ]]
[[ "$(cat -- "$phase19d_wallpaper_state_target")" == \
  "$phase19d_verified_wallpaper_path" ]]
[[ -L "$phase19d_wallpaper_link_target" ]]
[[ "$(readlink -- "$phase19d_wallpaper_link_target")" == \
  "$phase19d_verified_wallpaper_path" ]]
[[ "$(stat -c '%a' "$phase19d_scheme_target")" == 600 ]]
[[ "$(stat -c '%a' "$phase19d_wallpaper_state_target")" == 600 ]]
phase19d_maybe_fail after-verification

phase19d_transaction_complete=true
if [[ "$phase19d_request" == --reconcile ]]; then
  printf '{"ok":true,"reconciled":true,"packId":"%s","wallpaperPackId":"%s","generation":%s}\n' \
    "$phase19d_target_pack" \
    "$phase19d_target_wallpaper_pack" \
    "$phase19d_verified_generation"
else
  printf '{"ok":true,"packId":"%s","wallpaperPackId":"%s","generation":%s}\n' \
    "$phase19d_target_pack" \
    "$phase19d_target_wallpaper_pack" \
    "$phase19d_committed_generation"
fi
