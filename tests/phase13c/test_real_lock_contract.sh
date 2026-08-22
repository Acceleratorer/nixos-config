#!/usr/bin/env bash

set -euo pipefail

lock_root=${1:?missing packaged lock backend root}
caelestia_source=${2:?missing pinned Caelestia source}
quickshell_source=${3:?missing pinned Quickshell source}
greeter_root=${4:?missing rebuilt real-greeter payload}
keybinds=${5:?missing CryoForge keybinds}

lock_qml="$lock_root/modules/lock/Lock.qml"
surface_qml="$lock_root/modules/lock/LockSurface.qml"
pam_qml="$lock_root/modules/lock/Pam.qml"
idle_qml="$lock_root/modules/IdleMonitors.qml"
shell_qml="$lock_root/shell.qml"
session_manager="$caelestia_source/plugin/src/Caelestia/Services/sessionmanager.cpp"
session_lock_cpp="$quickshell_source/src/wayland/session_lock.cpp"
session_lock_hpp="$quickshell_source/src/wayland/session_lock.hpp"

for file in \
  "$lock_qml" \
  "$surface_qml" \
  "$pam_qml" \
  "$idle_qml" \
  "$shell_qml" \
  "$session_manager" \
  "$session_lock_cpp" \
  "$session_lock_hpp" \
  "$keybinds"; do
  test -r "$file"
done

# The lock backend is separately packaged. It contains neither greetd nor
# ReGreet, and the cold-greeter payload contains neither session-lock API.
test -r "$lock_root/README"
test -r "$lock_root/modules/lock/Lock.qml"
test -r "$lock_root/modules/lock/Pam.qml"
test -r "$lock_root/assets/pam.d/passwd"
! grep -R -q -i -E 'greetd|regreet' "$lock_root"
! grep -R -q -E 'WlSessionLock|Quickshell\.Services\.Pam' "$greeter_root" --include='*.qml'

# The live session backend owns WlSessionLock/PAM and does not call greetd.
grep -Fq 'WlSessionLock {' "$lock_qml"
grep -Fq 'LockSurface {' "$lock_qml"
grep -Fq 'IpcHandler {' "$lock_qml"
grep -Fq 'target: "lock"' "$lock_qml"
grep -Fq 'import Quickshell.Services.Pam' "$pam_qml"
! grep -R -q -E 'Quickshell\.Services\.Greetd|\bGreetd\.' "$lock_root/modules/lock" --include='*.qml'

# The global SUPER+L bind enters the session-lock IPC target directly; it
# must not route through logind/Hyprlock for the Caelestia-derived profile.
grep -Fq 'create_bind(vars.kbLock, hl.dsp.global("caelestia:lock"))' "$keybinds"
! grep -q -E 'loginctl lock-session|hyprlock' "$keybinds"

# A WlSessionLock creates a LockSurface, and Quickshell creates one surface
# for every valid Wayland output before showing any of them.
grep -Fq 'WlSessionLockSurface {' "$surface_qml"
grep -Fq 'for (auto* screen: screens)' "$session_lock_cpp"
grep -Fq 'this->mSurfaceComponent->create' "$session_lock_cpp"
grep -Fq 'surface->show();' "$session_lock_cpp"
grep -Fq 'WlSessionLock will create an instance of its `surface` component for every screen' "$session_lock_hpp"

# Password data goes only from the in-memory buffer into PamContext, then is
# cleared. The lock tree contains no logging call that could expose it.
grep -Fq 'respond(root.buffer);' "$pam_qml"
grep -A 1 -F 'respond(root.buffer);' "$pam_qml" | grep -Fq 'root.buffer = "";'
! grep -E -q '(console\.|print\(|qDebug|qInfo|qWarning).*buffer|buffer.*(console\.|print\(|qDebug|qInfo|qWarning)' \
  "$pam_qml" "$lock_root/modules/lock/center/InputField.qml" "$lock_root/modules/lock/center/PasswordInput.qml"

# PAM is the only success path to unlock. Failure clears transient state and
# returns to retry state without calling unlock.
grep -A 2 -F 'if (res === PamResult.Success)' "$pam_qml" | grep -Fq 'return root.lock.unlock();'
grep -Fq 'root.clearTransientState();' "$pam_qml"
grep -Fq 'else if (res === PamResult.Failed)' "$pam_qml"
grep -Fq 'pwdStateReset.restart();' "$pam_qml"
test "$(grep -c 'root.lock.unlock();' "$pam_qml")" -eq 2

# Stock idle wiring locks as logind announces sleep, locks on session Lock,
# and intentionally has no resume auto-unlock. A wake stays locked until the
# successful PAM path above calls WlSessionLock.unlock().
grep -Fq 'onAboutToSleep' "$idle_qml"
grep -A 3 -F 'function onAboutToSleep()' "$idle_qml" | grep -Fq 'root.lock.lock.locked = true;'
grep -A 2 -F 'function onLockRequested()' "$idle_qml" | grep -Fq 'root.lock.lock.locked = true;'
grep -A 2 -F 'function onUnlockRequested()' "$idle_qml" | grep -Fq 'root.lock.lock.unlock();'
grep -Fq 'emit aboutToSleep();' "$session_manager"
grep -Fq 'emit resumed();' "$session_manager"
! grep -q -F 'onResumed()' "$idle_qml"

# The logged-in shell is the presentation owner. ReGreet is cold-login-only
# and must not be present in either session-lock output.
grep -Fq 'Lock {' "$shell_qml"
grep -Fq 'IdleMonitors {' "$shell_qml"
! grep -R -q -i 'regreet' "$lock_root" --include='*.qml'
! grep -R -q -i 'regreet' "$greeter_root" --include='*.qml'

printf '%s\n' 'phase13c real lock contract tests: pass'
