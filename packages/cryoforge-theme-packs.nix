{
  lib,
  stdenvNoCC,
  registry ? import ../desktop/themes/registry.nix { },
  version ? "1.2.0",
  includeCuratedAssets ? true,
}:

let
  chisaWallpaper = ../desktop/caelestia/chisa-pool/chisa-pool-direct.jpg;
  chisaSource = ../desktop/themes/chisa-pool/SOURCE.md;
  deniaWallpaper = ../desktop/themes/cryoforge-denia/wallpaper.jpg;
  deniaPreview = ../desktop/themes/cryoforge-denia/preview.jpg;
  deniaSource = ../desktop/themes/cryoforge-denia/SOURCE.md;
  generatedSourceAssetRoot = ../desktop/themes;
  packIds = map (pack: pack.id) registry.packs;
  hasPack = id: builtins.elem id packIds;
  curatedPacks = builtins.filter (pack: pack.kind == "curated") registry.packs;
  generatedSourceAssets = builtins.listToAttrs (
    map (pack: {
      name = pack.id;
      value = {
        wallpaper = generatedSourceAssetRoot + "/${pack.id}/wallpaper.jpg";
        preview = generatedSourceAssetRoot + "/${pack.id}/preview.jpg";
        source = generatedSourceAssetRoot + "/${pack.id}/SOURCE.md";
      };
    }) (builtins.filter (pack: pack.id != "chisa-pool" && pack.id != "cryoforge-denia") curatedPacks)
  );
  sourceAssets = generatedSourceAssets // {
    chisa-pool = {
      wallpaper = chisaWallpaper;
      preview = chisaWallpaper;
      source = chisaSource;
    };
    cryoforge-denia = {
      wallpaper = deniaWallpaper;
      preview = deniaPreview;
      source = deniaSource;
    };
  };
  curatedAssetAssertions = builtins.all (
    pack:
    let
      source = sourceAssets.${pack.id};
    in
    builtins.hashFile "sha256" source.wallpaper == pack.assets.wallpaper.sha256
    && builtins.hashFile "sha256" source.preview == pack.assets.thumbnail.sha256
  ) curatedPacks;
  curatedAssetInstallCommands = lib.concatStringsSep "\n" (
    map (
      pack:
      let
        source = sourceAssets.${pack.id};
      in
      ''
        install -Dm0444 \
          ${source.wallpaper} \
          "$out/share/cryoforge/theme-packs/${pack.assets.wallpaper.path}"
        install -Dm0444 \
          ${source.preview} \
          "$out/share/cryoforge/theme-packs/${pack.assets.thumbnail.path}"
        install -Dm0444 \
          ${source.source} \
          "$out/share/cryoforge/theme-packs/assets/${pack.id}/SOURCE.md"
      ''
    ) curatedPacks
  );
  runtimeProjection = {
    schemaVersion = 1;
    defaultPackId = registry.defaultPackId;
    packs = map (pack: {
      inherit (pack) id displayName;
      kind = if pack.kind == "overlay" then "neutral" else pack.kind;
      wallpaper = if pack.assets.wallpaper == null then null else pack.assets.wallpaper.path;
      inherit (pack) palette;
      shell = pack.presentation.shell;
      preview = {
        thumbnail = if pack.assets.thumbnail == null then null else pack.assets.thumbnail.path;
        inherit (pack.preview) description swatches;
      };
    }) registry.packs;
  };
  renderedSourceRegistry = builtins.toFile "cryoforge-theme-packs-source-registry.json" (
    builtins.toJSON registry + "\n"
  );
  renderedRuntimeRegistry = builtins.toFile "cryoforge-theme-packs-registry.json" (
    builtins.toJSON runtimeProjection + "\n"
  );
in
assert
  !includeCuratedAssets
  || !hasPack "chisa-pool"
  || builtins.hashFile "sha256" chisaWallpaper
  == "a4dfcf92c4170405ac37102b27c606c5e9b1bb6cd77c9f04d530fa752aab604c";
assert
  !includeCuratedAssets
  || !hasPack "cryoforge-denia"
  || builtins.hashFile "sha256" deniaWallpaper
  == "34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb";
assert
  !includeCuratedAssets
  || !hasPack "cryoforge-denia"
  || builtins.hashFile "sha256" deniaPreview
  == "f67c58a530a4e44c491937e13e33b36aedf9e6ac8b0fca8a25ba6c6696824045";
assert !includeCuratedAssets || curatedAssetAssertions;
stdenvNoCC.mkDerivation {
  pname = "cryoforge-theme-packs";
  inherit version;
  dontUnpack = true;
  passthru = {
    inherit registry runtimeProjection;
  };

  installPhase = ''
    runHook preInstall

    install -Dm0444 \
      ${renderedRuntimeRegistry} \
      "$out/share/cryoforge/theme-packs/registry.json"

    ${if includeCuratedAssets then curatedAssetInstallCommands else ""}
    ${if includeCuratedAssets then ''
      install -Dm0444 \
        ${renderedSourceRegistry} \
        "$out/share/cryoforge/theme-packs/source-registry.json"
    '' else ""}

    runHook postInstall
  '';
}
