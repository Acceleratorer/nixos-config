{
  coreutils,
  cryoforgeThemePacks,
  lib,
  polkit,
  python3,
  registry ? import ../desktop/themes/registry.nix { },
  caelestiaSchemes ? import ../desktop/themes/caelestia-schemes.nix {
    inherit registry;
  },
  stateRoot ? "/var/lib/cryoforge-theme",
  requireRoot ? true,
  expectedUid ? 0,
  installPolicy ? true,
  stdenvNoCC,
  writeText,
  writeShellApplication,
}:

let
  runtimeRoot = "${cryoforgeThemePacks}/share/cryoforge/theme-packs";
  renderedSchemes = builtins.mapAttrs (
    id: scheme:
    builtins.toFile "cryoforge-${id}-publisher-scheme.json" (
      builtins.toJSON scheme + "\n"
    )
  ) caelestiaSchemes;
  packManifest = builtins.listToAttrs (
    map (pack: {
      name = pack.id;
      value = {
        inherit (pack) allowedWallpaperPackIds;
        scheme = {
          path = renderedSchemes.${pack.id};
          sha256 = builtins.hashFile "sha256" renderedSchemes.${pack.id};
        };
      };
    }) registry.packs
  );
  wallpaperPacks = builtins.filter (pack: pack.assets.wallpaper != null) registry.packs;
  wallpaperManifest = builtins.listToAttrs (
    map (pack: {
      name = pack.id;
      value = {
        wallpaper = {
          path = "${runtimeRoot}/${pack.assets.wallpaper.path}";
          sha256 = pack.assets.wallpaper.sha256;
        };
        thumbnail = {
          path = "${runtimeRoot}/${pack.assets.thumbnail.path}";
          sha256 = pack.assets.thumbnail.sha256;
        };
      };
    }) wallpaperPacks
  );
  manifest = writeText "cryoforge-theme-publication-manifest.json" (
    builtins.toJSON {
      schemaVersion = 1;
      packs = packManifest;
      wallpapers = wallpaperManifest;
    }
    + "\n"
  );
  publisher = writeShellApplication {
    name = "cryoforge-publish-active-theme";
    runtimeInputs = [
      coreutils
      python3
    ];
    text = lib.replaceStrings
      [
        "@STATE_ROOT@"
        "@MANIFEST@"
        "@REQUIRE_ROOT@"
        "@EXPECTED_UID@"
        "@PYTHON@"
      ]
      [
        stateRoot
        (toString manifest)
        (if requireRoot then "1" else "0")
        (toString expectedUid)
        "${python3}/bin/python3"
      ]
      (builtins.readFile ../desktop/themes/publish-active-theme.sh);
  };
in
assert lib.assertMsg (
  builtins.attrNames caelestiaSchemes
  == builtins.sort builtins.lessThan (map (pack: pack.id) registry.packs)
) "CryoForge publisher schemes must be registry-derived";
assert lib.assertMsg (
  builtins.attrNames wallpaperManifest
  == builtins.sort builtins.lessThan (map (pack: pack.id) wallpaperPacks)
) "CryoForge publisher wallpapers must be registry-derived";
stdenvNoCC.mkDerivation {
  pname = "cryoforge-theme-publisher";
  version = "1.0.0";
  dontUnpack = true;
  passthru = {
    inherit
      expectedUid
      manifest
      publisher
      requireRoot
      stateRoot
      ;
  };

  installPhase = ''
    runHook preInstall

    install -Dm0555 \
      ${publisher}/bin/cryoforge-publish-active-theme \
      "$out/bin/cryoforge-publish-active-theme"
    install -Dm0444 \
      ${manifest} \
      "$out/share/cryoforge/theme-publisher/manifest.json"

    ${if installPolicy then ''
      install -d -m 0755 "$out/share/polkit-1/actions"
      substitute \
        ${../desktop/themes/org.cryoforge.theme.publish.policy} \
        "$out/share/polkit-1/actions/org.cryoforge.theme.publish.policy" \
        --replace-fail \
        '@PUBLISHER@' \
        "$out/bin/cryoforge-publish-active-theme"
      chmod 0444 "$out/share/polkit-1/actions/org.cryoforge.theme.publish.policy"
    '' else ""}

    runHook postInstall
  '';

  meta = {
    description = "Authenticated fixed-path CryoForge active-theme publisher";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "cryoforge-publish-active-theme";
  };
}
