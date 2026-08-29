{
  caelestiaCli,
  coreutils,
  cryoforgeThemePacks,
  caelestiaSchemes ? import ../desktop/themes/caelestia-schemes.nix {
    inherit registry;
  },
  lib,
  registry ? import ../desktop/themes/registry.nix { },
  stdenvNoCC,
  writeShellApplication,
}:

let
  runtimeRoot = "${cryoforgeThemePacks}/share/cryoforge/theme-packs";
  renderedSchemes = builtins.mapAttrs
    (id: scheme:
      builtins.toFile
        "cryoforge-${id}-caelestia-scheme.json"
        (builtins.toJSON scheme + "\n")
    )
    caelestiaSchemes;
  renderedCliSchemes = builtins.mapAttrs
    (id: scheme:
      builtins.toFile
        "cryoforge-${id}-caelestia-cli-scheme.txt"
        (
          lib.concatStringsSep "\n" (
            lib.mapAttrsToList
              (name: colour: "${name} ${colour}")
              scheme.colours
          )
          + "\n"
        )
    )
    caelestiaSchemes;
  caelestiaPythonLibDir =
    let
      candidates = lib.filter
        (name: lib.hasPrefix "python" name)
        (builtins.attrNames (builtins.readDir "${caelestiaCli}/lib"));
    in
    assert lib.assertMsg (
      builtins.length candidates == 1
    ) "The pinned Caelestia CLI must contain exactly one Python library tree";
    builtins.head candidates;
  caelestiaSitePackages =
    "${caelestiaCli}/lib/${caelestiaPythonLibDir}/site-packages";
  guardedSchemeSource = builtins.toFile
    "caelestia-cryoforge-scheme.py"
    (
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
  guardedCaelestiaCli =
    assert lib.assertMsg (
      caelestiaCli.pname == "caelestia-cli"
      && caelestiaCli.version == "751fbc555a83faba5dd589270d14eeb22afab174"
    ) "Phase 19C must extend the pinned Caelestia CLI";
    assert lib.assertMsg (
      builtins.hashFile
        "sha256"
        "${caelestiaSitePackages}/caelestia/utils/scheme.py"
      == "ef14c44b9bea5595663e0369df5a9dc76f83bd4221cfe2b7ec2a6b07391c7555"
    ) "Refusing to transform changed Caelestia scheme handling";
    assert lib.assertMsg (
      builtins.hashFile
        "sha256"
        "${caelestiaSitePackages}/caelestia/utils/wallpaper.py"
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

        install -Dm0444 \
          ${renderedCliSchemes.neutral} \
          "$scheme_data_dir/neutral/dark.txt"
        install -Dm0444 \
          ${renderedCliSchemes.cryoforge-denia} \
          "$scheme_data_dir/cryoforge-denia/dark.txt"

        runHook postInstall
      '';

      meta = caelestiaCli.meta;
      passthru.upstreamCaelestiaCli = caelestiaCli;
    };
  applyHelper = writeShellApplication {
    name = "cryoforge-apply-theme-pack";
    runtimeInputs = [ coreutils ];
    text = lib.replaceStrings
      [
        "@NEUTRAL_SCHEME@"
        "@DENIA_SCHEME@"
        "@DENIA_WALLPAPER@"
      ]
      [
        (lib.escapeShellArg renderedSchemes.neutral)
        (lib.escapeShellArg renderedSchemes.cryoforge-denia)
        (lib.escapeShellArg "${runtimeRoot}/assets/cryoforge-denia/wallpaper.jpg")
      ]
      (builtins.readFile ../desktop/themes/apply-theme-pack.sh);
  };
in
assert builtins.attrNames caelestiaSchemes == [
  "cryoforge-denia"
  "neutral"
];
assert
  builtins.hashFile
    "sha256"
    ../desktop/themes/cryoforge-denia/wallpaper.jpg
  == "34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb";
stdenvNoCC.mkDerivation {
  pname = "cryoforge-theme-runtime";
  version = "1.0.0";
  dontUnpack = true;
  passthru.caelestiaCli = guardedCaelestiaCli;

  installPhase = ''
    runHook preInstall

    install -Dm0555 \
      ${applyHelper}/bin/cryoforge-apply-theme-pack \
      "$out/bin/cryoforge-apply-theme-pack"
    install -Dm0444 \
      ${runtimeRoot}/registry.json \
      "$out/share/cryoforge/theme-runtime/registry.json"
    install -Dm0444 \
      ${renderedSchemes.neutral} \
      "$out/share/cryoforge/theme-runtime/schemes/neutral.json"
    install -Dm0444 \
      ${renderedSchemes.cryoforge-denia} \
      "$out/share/cryoforge/theme-runtime/schemes/cryoforge-denia.json"
    install -Dm0444 \
      ${runtimeRoot}/assets/cryoforge-denia/preview.jpg \
      "$out/share/cryoforge/theme-runtime/assets/cryoforge-denia/preview.jpg"
    install -Dm0444 \
      ${runtimeRoot}/assets/cryoforge-denia/wallpaper.jpg \
      "$out/share/cryoforge/theme-runtime/assets/cryoforge-denia/wallpaper.jpg"

    runHook postInstall
  '';
}
