{
  caelestia-shell,
  caelestiaShellCryoforge,
  coreutils,
  lib,
  qt6,
  stdenvNoCC,
}:

let
  lockRoot = "${caelestiaShellCryoforge}/share/caelestia-shell";
  quickshell = caelestia-shell.inputs.quickshell;

  expectedHashes = {
    "shell.qml" = "a0323a3aa8166fbb62be0aa4d9bd4944b6cf89017062aaf67b608065af6c532c";
    "modules/IdleMonitors.qml" = "b80bd9a508edb2bfd9b53c5a0432b64c13705c1093c17811d49ae686f178e4d2";
    "modules/lock/Lock.qml" = "53780d8e5545007b2f546c4822567b4c7717b3e54235a7e3c67beb33e80c9178";
    "modules/lock/LockSurface.qml" = "c52ee7f235592984f1837296c570c2424074083578a2e4e5c967939a9c8f4237";
    "modules/lock/Pam.qml" = "097230876dae0ea21921952ac1b081d8b1e4733fa11fe23d01065f9d309c771a";
  };

  verifyHashes = lib.concatStringsSep "\n" (lib.mapAttrsToList (path: hash: ''
    test "$(sha256sum "${lockRoot}/${path}" | cut -d ' ' -f 1)" = "${hash}"
  '') expectedHashes);
in
stdenvNoCC.mkDerivation {
  pname = "caelestia-real-lock";
  version = "1.0.0-phase13c";
  dontUnpack = true;
  dontWrapQtApps = true;

  nativeBuildInputs = [
    coreutils
    qt6.qtdeclarative
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck

    lockRoot="${lockRoot}"

    ${verifyHashes}

    for file in \
      "$lockRoot/shell.qml" \
      "$lockRoot/modules/IdleMonitors.qml" \
      "$lockRoot/modules/lock/Lock.qml" \
      "$lockRoot/modules/lock/LockSurface.qml" \
      "$lockRoot/modules/lock/Pam.qml"; do
      qmlformat --dry-run "$file" >/dev/null
      qmllint --bare --max-warnings 9999 \
        -I ${qt6.qtdeclarative}/lib/qt-6/qml \
        -I ${caelestiaShellCryoforge}/share/caelestia-shell \
        "$file" >/dev/null
    done

    grep -Fq 'WlSessionLock {' "$lockRoot/modules/lock/Lock.qml"
    grep -Fq 'LockSurface {' "$lockRoot/modules/lock/Lock.qml"
    grep -Fq 'IpcHandler {' "$lockRoot/modules/lock/Lock.qml"
    grep -Fq 'target: "lock"' "$lockRoot/modules/lock/Lock.qml"
    grep -Fq 'import Quickshell.Services.Pam' "$lockRoot/modules/lock/Pam.qml"
    ! grep -R -q -E 'Quickshell\.Services\.Greetd|\bGreetd\.' \
      "$lockRoot/modules/lock" --include='*.qml'
    ! grep -R -q -i 'regreet' "$lockRoot/modules/lock" --include='*.qml'

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    lockOutput="$out/share/caelestia-real-lock"
    install -d \
      "$lockOutput/modules/lock" \
      "$lockOutput/modules" \
      "$lockOutput/assets/pam.d"
    cp -R --no-preserve=mode,ownership \
      "$lockRoot/modules/lock/." \
      "$lockOutput/modules/lock/"
    install -m 0444 "$lockRoot/shell.qml" "$lockOutput/shell.qml"
    install -m 0444 \
      "$lockRoot/modules/IdleMonitors.qml" \
      "$lockOutput/modules/IdleMonitors.qml"
    cp -R --no-preserve=mode,ownership \
      "$lockRoot/assets/pam.d/." \
      "$lockOutput/assets/pam.d/"
    printf '%s\n' \
      'The session lock backend is the pinned Caelestia WlSessionLock/PAM tree.' \
      > "$lockOutput/README"

    runHook postInstall
  '';

  passthru = {
    backend = caelestiaShellCryoforge;
    inherit quickshell;
    upstreamRoot = lockRoot;
  };

  meta = {
    description = "Build-only contract for the pinned Caelestia WlSessionLock/PAM backend";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
