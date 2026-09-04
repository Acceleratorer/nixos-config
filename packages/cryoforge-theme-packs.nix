{
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
  packIds = map (pack: pack.id) registry.packs;
  hasPack = id: builtins.elem id packIds;
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
    install -Dm0444 \
      ${renderedSourceRegistry} \
      "$out/share/cryoforge/theme-packs/source-registry.json"

    ${if includeCuratedAssets && hasPack "chisa-pool" then ''
      install -Dm0444 \
        ${chisaWallpaper} \
        "$out/share/cryoforge/theme-packs/assets/chisa-pool/wallpaper.jpg"
      install -Dm0444 \
        ${chisaWallpaper} \
        "$out/share/cryoforge/theme-packs/assets/chisa-pool/preview.jpg"
      install -Dm0444 \
        ${chisaSource} \
        "$out/share/cryoforge/theme-packs/assets/chisa-pool/SOURCE.md"
    '' else ""}

    ${if includeCuratedAssets && hasPack "cryoforge-denia" then ''
      install -Dm0444 \
        ${deniaWallpaper} \
        "$out/share/cryoforge/theme-packs/assets/cryoforge-denia/wallpaper.jpg"
      install -Dm0444 \
        ${deniaPreview} \
        "$out/share/cryoforge/theme-packs/assets/cryoforge-denia/preview.jpg"
      install -Dm0444 \
        ${deniaSource} \
        "$out/share/cryoforge/theme-packs/assets/cryoforge-denia/SOURCE.md"
    '' else ""}

    runHook postInstall
  '';
}
