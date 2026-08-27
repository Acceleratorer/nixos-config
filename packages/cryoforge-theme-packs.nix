{
  stdenvNoCC,
  registry ? import ../desktop/themes/registry.nix { },
  version ? "1.1.0",
  includeCuratedAssets ? true,
}:

let
  renderedRegistry = builtins.toFile
    "cryoforge-theme-packs-registry.json"
    (builtins.toJSON registry + "\n");
  wallpaper = ../desktop/themes/cryoforge-denia/wallpaper.jpg;
  preview = ../desktop/themes/cryoforge-denia/preview.jpg;
  source = ../desktop/themes/cryoforge-denia/SOURCE.md;
in
assert
  !includeCuratedAssets
  || builtins.hashFile "sha256" wallpaper
    == "34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb";
assert
  !includeCuratedAssets
  || builtins.hashFile "sha256" preview
    == "f67c58a530a4e44c491937e13e33b36aedf9e6ac8b0fca8a25ba6c6696824045";
stdenvNoCC.mkDerivation {
  pname = "cryoforge-theme-packs";
  inherit version;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm0444 \
      ${renderedRegistry} \
      "$out/share/cryoforge/theme-packs/registry.json"

    ${if includeCuratedAssets then ''
      install -Dm0444 \
        ${wallpaper} \
        "$out/share/cryoforge/theme-packs/assets/cryoforge-denia/wallpaper.jpg"
      install -Dm0444 \
        ${preview} \
        "$out/share/cryoforge/theme-packs/assets/cryoforge-denia/preview.jpg"
      install -Dm0444 \
        ${source} \
        "$out/share/cryoforge/theme-packs/assets/cryoforge-denia/SOURCE.md"
    '' else ""}

    runHook postInstall
  '';
}
