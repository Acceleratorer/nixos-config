{
  caelestiaCli,
  coreutils,
  cryoforgeThemePacks,
  cryoforgeThemePublisher,
  caelestiaSchemes ? import ../desktop/themes/caelestia-schemes.nix {
    inherit registry;
  },
  lib,
  polkit,
  publicationEnabled ? true,
  python3,
  registry ? import ../desktop/themes/registry.nix { },
  stdenvNoCC,
  testFailuresEnabled ? false,
  usePolkit ? true,
  writeShellApplication,
}:

let
  runtimeRoot = "${cryoforgeThemePacks}/share/cryoforge/theme-packs";
  packIds = map (pack: pack.id) registry.packs;
  renderedSchemes = builtins.mapAttrs (
    id: scheme:
    builtins.toFile "cryoforge-${id}-caelestia-scheme.json" (
      builtins.toJSON scheme + "\n"
    )
  ) caelestiaSchemes;
  renderedCliSchemes = builtins.mapAttrs (
    id: scheme:
    builtins.toFile "cryoforge-${id}-caelestia-cli-scheme.txt" (
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: colour: "${name} ${colour}") scheme.colours
      )
      + "\n"
    )
  ) caelestiaSchemes;
  caelestiaPythonLibDir =
    let
      candidates = lib.filter (name: lib.hasPrefix "python" name) (
        builtins.attrNames (builtins.readDir "${caelestiaCli}/lib")
      );
    in
    assert lib.assertMsg (
      builtins.length candidates == 1
    ) "The pinned Caelestia CLI must contain exactly one Python library tree";
    builtins.head candidates;
  caelestiaSitePackages = "${caelestiaCli}/lib/${caelestiaPythonLibDir}/site-packages";
  guardedSchemeSource = builtins.toFile "caelestia-cryoforge-scheme.py" (
    lib.replaceStrings
      [ "                \"colours\": self.colours,\n" ]
      [
        (
          "                \"colours\": self.colours,\n"
          + "                **(\n"
          + "                    {\"cryoforge\": {\"schemaVersion\": 1, \"packId\": self.flavour}}\n"
          + "                    if self.name == \"cryoforge-pack\"\n"
          + "                    else {}\n"
          + "                ),\n"
        )
      ]
      (builtins.readFile "${caelestiaSitePackages}/caelestia/utils/scheme.py")
  );
  cliSchemeInstallCommands = lib.concatStringsSep "\n" (
    map (id: ''
      install -Dm0444 \
        ${renderedCliSchemes.${id}} \
        "$scheme_data_dir/${id}/dark.txt"
    '') packIds
  );
  runtimeSchemeInstallCommands = lib.concatStringsSep "\n" (
    map (id: ''
      install -Dm0444 \
        ${renderedSchemes.${id}} \
        "$out/share/cryoforge/theme-runtime/schemes/${id}.json"
    '') packIds
  );
  runtimeAssetInstallCommands = lib.concatStringsSep "\n" (
    lib.concatMap (
      pack:
      lib.optionals (pack.assets.wallpaper != null) [
        ''
          install -Dm0444 \
            ${runtimeRoot}/${pack.assets.wallpaper.path} \
            "$out/share/cryoforge/theme-runtime/${pack.assets.wallpaper.path}"
        ''
        ''
          install -Dm0444 \
            ${runtimeRoot}/${pack.assets.thumbnail.path} \
            "$out/share/cryoforge/theme-runtime/${pack.assets.thumbnail.path}"
        ''
      ]
    ) registry.packs
  );
  guardedCaelestiaCli =
    assert lib.assertMsg (
      caelestiaCli.pname == "caelestia-cli"
      && caelestiaCli.version == "751fbc555a83faba5dd589270d14eeb22afab174"
    ) "Phase 19D must extend the pinned Caelestia CLI";
    assert lib.assertMsg (
      builtins.hashFile "sha256" "${caelestiaSitePackages}/caelestia/utils/scheme.py"
      == "ef14c44b9bea5595663e0369df5a9dc76f83bd4221cfe2b7ec2a6b07391c7555"
    ) "Refusing to transform changed Caelestia scheme handling";
    assert lib.assertMsg (
      builtins.hashFile "sha256" "${caelestiaSitePackages}/caelestia/utils/wallpaper.py"
      == "00e5ae68155d795e6eefec9a10d10272d9386e7435ecba8a40d1f80315e8eab5"
    ) "Refusing to package against changed Caelestia wallpaper handling";
    stdenvNoCC.mkDerivation {
      pname = "caelestia-cli-cryoforge";
      inherit (caelestiaCli) version;
      dontUnpack = true;

      installPhase = ''
        runHook preInstall

        cp -a ${caelestiaCli}/. "$out/"
        chmod -R u+w "$out"

        substituteInPlace "$out/bin/caelestia" \
          --replace-fail '${caelestiaCli}' "$out"
        substituteInPlace "$out/bin/.caelestia-wrapped" \
          --replace-fail '${caelestiaCli}' "$out"
        install -m 0444 \
          ${guardedSchemeSource} \
          "$out/lib/${caelestiaPythonLibDir}/site-packages/caelestia/utils/scheme.py"
        find "$out/lib/${caelestiaPythonLibDir}/site-packages" \
          -type d -name __pycache__ -prune -exec rm -rf {} +

        scheme_data_dir="$out/lib/${caelestiaPythonLibDir}/site-packages/caelestia/data/schemes/cryoforge-pack"
        ${cliSchemeInstallCommands}

        runHook postInstall
      '';

      meta = caelestiaCli.meta;
      passthru.upstreamCaelestiaCli = caelestiaCli;
    };
  resolver = writeShellApplication {
    name = "cryoforge-resolve-active-theme";
    runtimeInputs = [
      coreutils
      python3
    ];
    text = lib.replaceStrings
      [
        "@STATE_ROOT@"
        "@MANIFEST@"
        "@EXPECTED_UID@"
        "@PYTHON@"
      ]
      [
        cryoforgeThemePublisher.stateRoot
        (toString cryoforgeThemePublisher.manifest)
        (toString cryoforgeThemePublisher.expectedUid)
        "${python3}/bin/python3"
      ]
      (builtins.readFile ../desktop/themes/resolve-active-theme.sh);
  };
  publisherInvoker = writeShellApplication {
    name = "cryoforge-invoke-theme-publisher";
    runtimeInputs = lib.optionals usePolkit [ polkit ];
    text =
      if usePolkit then
        ''
          exec /run/wrappers/bin/pkexec --disable-internal-agent \
            ${cryoforgeThemePublisher}/bin/cryoforge-publish-active-theme \
            "$@"
        ''
      else
        ''
          exec ${cryoforgeThemePublisher}/bin/cryoforge-publish-active-theme \
            "$@"
        '';
  };
  applyHelper = writeShellApplication {
    name = "cryoforge-apply-theme-pack";
    runtimeInputs = [
      coreutils
      python3
    ];
    text = lib.replaceStrings
      [
        "@PUBLICATION_ENABLED@"
        "@TEST_FAILURES_ENABLED@"
        "@NEUTRAL_SCHEME@"
        "@CHISA_SCHEME@"
        "@DENIA_SCHEME@"
        "@CHISA_WALLPAPER@"
        "@DENIA_WALLPAPER@"
        "@RESOLVER@"
        "@PUBLISHER_INVOKER@"
        "@PYTHON@"
      ]
      [
        (if publicationEnabled then "1" else "0")
        (if testFailuresEnabled then "1" else "0")
        (lib.escapeShellArg renderedSchemes.neutral)
        (lib.escapeShellArg (renderedSchemes.chisa-pool or renderedSchemes.neutral))
        (lib.escapeShellArg renderedSchemes.cryoforge-denia)
        (lib.escapeShellArg "${runtimeRoot}/assets/chisa-pool/wallpaper.jpg")
        (lib.escapeShellArg "${runtimeRoot}/assets/cryoforge-denia/wallpaper.jpg")
        (lib.escapeShellArg "${resolver}/bin/cryoforge-resolve-active-theme")
        (lib.escapeShellArg "${publisherInvoker}/bin/cryoforge-invoke-theme-publisher")
        (lib.escapeShellArg "${python3}/bin/python3")
      ]
      (builtins.readFile ../desktop/themes/apply-theme-pack.sh);
  };
in
assert lib.assertMsg (
  !publicationEnabled
  || packIds
  == [
    "neutral"
    "chisa-pool"
    "cryoforge-denia"
  ]
) "Phase 19D runtime requires the exact approved pack order";
assert lib.assertMsg (
  builtins.attrNames caelestiaSchemes == builtins.sort builtins.lessThan packIds
) "CryoForge runtime schemes must be registry-derived";
stdenvNoCC.mkDerivation {
  pname = "cryoforge-theme-runtime";
  version = if publicationEnabled then "1.1.0" else "1.0.0";
  dontUnpack = true;
  passthru = {
    caelestiaCli = guardedCaelestiaCli;
    inherit applyHelper publisherInvoker resolver;
    themePublisher = cryoforgeThemePublisher;
  };

  installPhase = ''
    runHook preInstall

    install -Dm0555 \
      ${applyHelper}/bin/cryoforge-apply-theme-pack \
      "$out/bin/cryoforge-apply-theme-pack"
    install -Dm0555 \
      ${resolver}/bin/cryoforge-resolve-active-theme \
      "$out/bin/cryoforge-resolve-active-theme"
    install -Dm0444 \
      ${runtimeRoot}/registry.json \
      "$out/share/cryoforge/theme-runtime/registry.json"
    ${runtimeSchemeInstallCommands}
    ${runtimeAssetInstallCommands}

    runHook postInstall
  '';
}
