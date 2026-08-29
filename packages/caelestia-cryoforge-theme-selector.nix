{
  caelestiaShellCryoforge,
  coreutils,
  cryoforgeCaelestiaCli,
  cryoforgeThemeRuntime,
  lib,
  upstreamCaelestiaCli,
}:

let
  themeSelectorPage = ../desktop/caelestia/nexus/ThemePackGallery.qml;
  themeSelectorPageSha256 = "6871c184e4af53a31f00c1d2759b73bf4513d18f2538da10f7e1580b4d6d64ea";
  themeSelectorPatch = ../desktop/caelestia/cryoforge-nexus-theme-selector.patch;
  themeSelectorPatchSha256 = "9e400f31b47fa4be390138f7370a5d398a880677e544c6e6f8c58909b88060c1";
  upstreamCaelestiaCliPath =
    builtins.unsafeDiscardStringContext (toString upstreamCaelestiaCli);

  guardedPackage =
    assert lib.assertMsg (
      builtins.hashFile "sha256" themeSelectorPage == themeSelectorPageSha256
    ) "CryoForge Nexus theme selector page checksum mismatch";
    assert lib.assertMsg (
      builtins.hashFile "sha256" themeSelectorPatch == themeSelectorPatchSha256
    ) "CryoForge Nexus theme selector patch checksum mismatch";
    assert lib.assertMsg (
      caelestiaShellCryoforge.pname == "caelestia-shell-cryoforge"
    ) "Phase 19C must wrap the accepted CryoForge shell derivation";
    assert lib.assertMsg (
      cryoforgeCaelestiaCli.pname == "caelestia-cli-cryoforge"
      && builtins.length (
        lib.filter
          (dependency: dependency == upstreamCaelestiaCli)
          caelestiaShellCryoforge.propagatedBuildInputs
      ) == 1
    ) "Phase 19C must replace the accepted shell's pinned CLI exactly once";
    caelestiaShellCryoforge;
in
guardedPackage.overrideAttrs (old: {
  pname = "caelestia-shell-cryoforge-theme-selector";
  patches = (old.patches or [ ]) ++ [ themeSelectorPatch ];
  propagatedBuildInputs = map
    (dependency:
      if dependency == upstreamCaelestiaCli
      then cryoforgeCaelestiaCli
      else dependency
    )
    old.propagatedBuildInputs;
  patchFlags = [
    "-p1"
    "--fuzz=0"
  ];
  passthru = (old.passthru or { }) // {
    caelestiaCli = cryoforgeCaelestiaCli;
  };

  postInstall =
    assert lib.assertMsg (
      builtins.length (
        lib.splitString
          upstreamCaelestiaCliPath
          (old.postInstall or "")
      ) == 2
    ) "Phase 19C must replace the accepted shell launcher CLI exactly once";
    lib.replaceStrings
      [ upstreamCaelestiaCliPath ]
      [ (toString cryoforgeCaelestiaCli) ]
      (old.postInstall or "")
    + ''
      ${coreutils}/bin/install -m 0444 \
        ${themeSelectorPage} \
        "$out/share/caelestia-shell/modules/nexus/pages/wallandstyle/ThemePackGallery.qml"
      substituteInPlace \
        "$out/share/caelestia-shell/modules/nexus/pages/wallandstyle/ThemePackGallery.qml" \
        --replace-fail '@THEME_RUNTIME_ROOT@' \
        '${cryoforgeThemeRuntime}/share/cryoforge/theme-runtime' \
        --replace-fail '@THEME_APPLY_HELPER@' \
        '${cryoforgeThemeRuntime}/bin/cryoforge-apply-theme-pack'
    '';
})
