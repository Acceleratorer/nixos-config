{
  caelestia-shell,
  cage,
  coreutils,
  greetd,
  hyprland,
  lib,
  librsvg,
  makeFontsConf,
  makeWrapper,
  material-symbols,
  nerd-fonts,
  nixos-icons,
  qt6,
  rubik,
  stdenvNoCC,
  wlr-randr,
}:

let
  system = stdenvNoCC.hostPlatform.system;
  upstreamPackage = caelestia-shell.packages.${system}.with-cli;
  upstreamRoot = "${upstreamPackage}/share/caelestia-shell";
  quickshell = builtins.elemAt upstreamPackage.buildInputs 0;
  plugin = upstreamPackage.plugin;
  m3shapes = upstreamPackage.m3shapesModule;
  extras = upstreamPackage.extras;

  qmlImportPath = lib.makeSearchPath "lib/qt-6/qml" [
    quickshell
    plugin
    m3shapes
    qt6.qtdeclarative
    qt6.qtwayland
  ];

  fontconfig = makeFontsConf {
    fontDirectories = [
      material-symbols
      rubik
      nerd-fonts.caskaydia-cove
    ];
  };

  expectedHashes = {
    "modules/lock/Lock.qml" = "53780d8e5545007b2f546c4822567b4c7717b3e54235a7e3c67beb33e80c9178";
    "modules/lock/LockSurface.qml" = "c52ee7f235592984f1837296c570c2424074083578a2e4e5c967939a9c8f4237";
    "modules/lock/Content.qml" = "79f3f560a9345c8611f1331ad781edda2d3ad117dd046440d514e1492e1d9aff";
    "modules/lock/Center.qml" = "817b15a25e2ffd2ac2b5404c903c9d66c6ab540df3c056b31418b5f8b1a02078";
    "modules/lock/center/Clock.qml" = "87926b642e0b812d39c40b9a8fdb616b2619bbbdad79f521f1d4e088c0bc3c43";
    "modules/lock/center/ProfilePic.qml" = "b38f25dd2604223bbf2dae1f2046399bd80182c17742710893a06dad64fe90a9";
    "modules/lock/center/PasswordInput.qml" = "4177b7c2ebe9e8d96633a6fbc258e18dcfe6eecbbc0457a9efb783bb61703e17";
    "modules/lock/center/InputField.qml" = "8f4604bf03857fdcbfa118af8b5fa229107520bfaa59db9c52d7fa3fcaa9be71";
    "modules/lock/center/StateMessage.qml" = "3756a8790903a5bf738d0e0f925644e50b055f9d5a358172ede74b36eab7fcc7";
    "modules/lock/WeatherInfo.qml" = "37d81e6e10c11616d9cf98bb799a56f304403ca4f0a1160cc6e13dc1168e26f3";
    "modules/lock/Resources.qml" = "10aa9197cfcd77665eccf6f5e1f7a970c7903c20777c97e3d80508d0c3886c01";
    "modules/lock/Media.qml" = "8ea11f92150d179fdf70b219d581bb76c3cb7985f6257d347ea8dae86a351bdd";
    "modules/lock/NotifDock.qml" = "e244fc453c2e81804fed6740deef2ea935a6906fbdb0fca4d1b2e8b861fe7fa7";
    "modules/lock/Fetch.qml" = "9fdd64ab84b6b608e7d303c10bbccfef2bb102e3a6e4e0376667fa1227e4e78e";
    "modules/lock/NotifGroup.qml" = "921b690e5a9363f84fa79e19104c98087536891d28f239328ee9d582f3b7387a";
    "modules/lock/weather/BriefInfo.qml" = "e4c89545166a53ee8360978ce3fbd5bd8b89cfc42b064cf6fb5ee672b9872da0";
    "modules/lock/weather/Forecast.qml" = "04d8ea0e77d11c66ae26c2609c428cfeaa7bbe7fb7a4650eafb2a3cdb81dec30";
    "services/Colours.qml" = "0e8834bde99311715b1d4c888eac4526a6dc1aa918d33024305993e1fcc57f5c";
    "services/Time.qml" = "9604efd7166e73c2c9b6672e43c433f0d39cd7ed4531731b741751090739235e";
    "utils/SysInfo.qml" = "16fb7d0e01a050ab5d69ff1eaaa6f10fa602119e99bebea0e3af7d7b39d699f6";
  };

  verifyHashes = lib.concatStringsSep "\n" (lib.mapAttrsToList (path: hash: ''
    test "$(${coreutils}/bin/sha256sum "${upstreamRoot}/${path}" | ${coreutils}/bin/cut -d ' ' -f 1)" = "${hash}"
  '') expectedHashes);
in
stdenvNoCC.mkDerivation {
  pname = "caelestia-real-greeter";
  version = "1.0.0-phase13a";

  src = ../desktop/caelestia;
  dontUnpack = true;
  nativeBuildInputs = [
    librsvg
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    ${verifyHashes}

    # The pinned user-session package remains the source of truth for the
    # normal lock backend. It must retain WlSessionLock and PAM, and it must
    # never acquire a greetd import.
    grep -q 'WlSessionLock' "${upstreamRoot}/modules/lock/Lock.qml"
    grep -q 'import Quickshell.Services.Pam' "${upstreamRoot}/modules/lock/Pam.qml"
    ! grep -R -q 'Quickshell.Services.Greetd' "${upstreamRoot}/modules/lock"

    root="$out/share/caelestia-real-greeter"
    config="$out/share/caelestia-real-greeter-config"

    mkdir -p "$out/bin" "$root" "$config/caelestia"
    cp -R --no-preserve=mode,ownership "${upstreamRoot}/." "$root/"

    # Quickshell loads every singleton in an implicit module. Keep only the
    # shared visual services used by the lock tree and the safe greeter models.
    for service in Audio Brightness GameMode IdleInhibitor NetworkUsage Nmcli Recorder Screens ShellState VPN; do
      rm "$root/services/$service.qml"
    done

    # The greeter entrypoint uses only the pinned lock presentation and its
    # font loader. Exclude every unrelated logged-in-session module from the
    # immutable pre-login package.
    for module in "$root/modules"/*; do
      case "$module" in
        "$root/modules/GSFLoader.qml"|"$root/modules/lock") ;;
        *) rm -r "$module" ;;
      esac
    done
    rm "$root/components/controls/Menu.qml" "$root/components/controls/SplitButton.qml"

    mkdir -p "$root/real-greeter/adapters" "$root/tests"
    install -m 0444 "$src/real-greeter/Pam.qml" "$root/modules/lock/Pam.qml"
    install -m 0444 "$src/real-greeter/GreeterContent.qml" "$root/real-greeter/GreeterContent.qml"
    install -m 0444 "$src/real-greeter/GreeterLock.qml" "$root/real-greeter/GreeterLock.qml"
    install -m 0444 "$src/real-greeter/GreeterSurface.qml" "$root/real-greeter/GreeterSurface.qml"
    install -m 0444 "$src/real-greeter/greeter.qml" "$root/greeter.qml"
    install -m 0444 "$src/real-greeter/adapters/GreetdController.qml" "$root/real-greeter/adapters/GreetdController.qml"

    for service in Hypr NotifData Notifs Players Wallpapers Weather; do
      install -m 0444 "$src/real-greeter/services/$service.qml" "$root/services/$service.qml"
    done

    install -m 0444 "$src/real-greeter-preview.qml" "$root/real-greeter-preview.qml"
    install -m 0444 "$src/real-lock-preview.qml" "$root/real-lock-preview.qml"
    install -m 0444 "$src/real-greeter-controller-test.qml" "$root/real-greeter-controller-test.qml"
    install -m 0555 "$src/real-greeter/tests/fake_greetd_protocol.py" "$root/tests/fake_greetd_protocol.py"
    install -m 0444 "$src/real-greeter/assets/shell.json" "$config/caelestia/shell.json"
    install -m 0444 "$src/real-greeter/assets/shell-tokens.json" "$config/caelestia/shell-tokens.json"
    install -m 0444 "$src/real-greeter/assets/scheme.json" "$root/assets/greeter-scheme.json"
    substituteInPlace "$config/caelestia/shell.json" \
      --replace-fail '@NIXOS_LOGO@' '${nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg'

    # Use the repository's existing identity wallpaper as an immutable greeter asset.
    rsvg-convert --width 2560 --height 1600 ${../desktop/wallpaper.svg} --output "$root/assets/greeter-wallpaper.png"

    # Keep the exact pinned visual tree intact after the greeter-only overlays.
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (path: hash: ''
      test "$(${coreutils}/bin/sha256sum "$root/${path}" | ${coreutils}/bin/cut -d ' ' -f 1)" = "${hash}"
    '') expectedHashes)}

    # The pre-login output carries the real view but none of the stock lock
    # backend. Its only authentication service import is greetd.
    rm "$root/modules/lock/Lock.qml" "$root/modules/lock/LockSurface.qml" "$root/shell.qml"
    rm -r "$root/assets/pam.d"
    grep -q 'import Quickshell.Services.Greetd' "$root/real-greeter/adapters/GreetdController.qml"
    ! grep -R -q -E 'WlSessionLock|Quickshell.Services.Pam' "$root" --include='*.qml'

    socketConsumers=$(grep -R -l 'GREETD_SOCK' "$root" --include='*.qml')
    test "$socketConsumers" = "$root/real-greeter/adapters/GreetdController.qml"
    greetdConsumers=$(grep -R -l 'Quickshell.Services.Greetd' "$root" --include='*.qml')
    test "$greetdConsumers" = "$root/real-greeter/adapters/GreetdController.qml"
    ! grep -R -q -E 'NotificationServer|Quickshell.Services.(Mpris|Pipewire)|Clipboard' \
      "$root" --include='*.qml'
    ! grep -R -q '/home/accelra' "$root" --include='*.qml'
    ! grep -R -q '^import qs.modules' "$root/components" "$root/services" "$root/utils" \
      --include='*.qml'

    install -m 0555 "$src/real-greeter/launch-runtime.sh" "$out/bin/caelestia-real-greeter-qml"
    substituteInPlace "$out/bin/caelestia-real-greeter-qml" \
      --replace-fail '@SCHEME@' "$root/assets/greeter-scheme.json" \
      --replace-fail '@CONFIG@' "$config" \
      --replace-fail '@QUICKSHELL@' '${quickshell}/bin/qs'
    wrapProgram "$out/bin/caelestia-real-greeter-qml" \
      --set CAELESTIA_LIB_DIR ${extras}/lib \
      --set FONTCONFIG_FILE ${fontconfig} \
      --set NIXPKGS_QT6_QML_IMPORT_PATH ${qmlImportPath} \
      --prefix QT_PLUGIN_PATH : ${qt6.qtbase.qtPluginPrefix} \
      --prefix XDG_DATA_DIRS : ${nixos-icons}/share

    makeWrapper "$out/bin/caelestia-real-greeter-qml" "$out/bin/caelestia-real-greeter" \
      --add-flags "$root/greeter.qml"

    makeWrapper ${cage}/bin/cage "$out/bin/caelestia-real-greeter-session" \
      --add-flags "-- $out/bin/caelestia-real-greeter"

    makeWrapper "$out/bin/caelestia-real-greeter-qml" "$out/bin/caelestia-real-lock-preview" \
      --add-flags "$root/real-lock-preview.qml"

    makeWrapper "$out/bin/caelestia-real-greeter-qml" "$out/bin/caelestia-real-greeter-preview" \
      --add-flags "$root/real-greeter-preview.qml"

    makeWrapper "$out/bin/caelestia-real-greeter-qml" "$out/bin/caelestia-real-greeter-controller-test" \
      --add-flags "$root/real-greeter-controller-test.qml"

    substituteInPlace "$root/real-greeter/adapters/GreetdController.qml" \
      --replace-fail '@GREETER_USER@' 'accelra' \
      --replace-fail '@SESSION_COMMAND@' '${hyprland}/bin/start-hyprland'
    substituteInPlace "$root/tests/fake_greetd_protocol.py" \
      --replace-fail '@SESSION_COMMAND@' '${hyprland}/bin/start-hyprland'

    runHook postInstall
  '';

  passthru = {
    inherit quickshell plugin m3shapes upstreamPackage;
    fakegreet = greetd;
    formatter = qt6.qtdeclarative;
    renderer = cage;
    outputManager = wlr-randr;
    sessionCommand = "${hyprland}/bin/start-hyprland";
    upstreamRevision = "817a220e8e87c4df9f3681033a0d8a8054cdaa30";
  };

  meta = {
    description = "Build-only greetd adapter for the pinned Caelestia lock view";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "caelestia-real-greeter-session";
  };
}
