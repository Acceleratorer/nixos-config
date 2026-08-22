{
  caelestiaChisaPool,
  caelestia-shell,
  coreutils,
  lib,
  stdenv,
}:

let
  system = stdenv.hostPlatform.system;
  chisaPoolCachingImage = ../desktop/caelestia/chisa-pool/CachingImage.qml;
  chisaPoolCachingImageSha256 = "bc6c1658f0f2748ae96970b07f0e20aa86baf1dd07437e5a7726d0cddc0e9419";
  chisaPresetPatch = ../desktop/caelestia/cryoforge-chisa-preset-gallery.patch;
  chisaPresetPatchSha256 = "0b73f3dc7fd093e4d5b167079c2a8f80fcf08e6791cb4855e55bbe983ccaf877";
  chisaPresetSourceHashes = {
    "modules/nexus/PageCompRegistry.qml" = "97e55e31cd177cb63fd3d494343b93bd427a53a82c8e3f87401fcdaf6a469e91";
    "modules/nexus/pages/WallpaperAndStyle.qml" = "b6bb2d3c496d226f9c3cd4db73683cd2d0223c312fc22d792a52410c78f346a9";
  };
  chisaPresetManifest = ../desktop/caelestia/chisa-pool/ChisaPresets.qml;
  chisaPresetWallpapers = ../desktop/caelestia/chisa-pool/ChisaPresetWallpapers.qml;
  chisaPresetGallery = ../desktop/caelestia/chisa-pool/ChisaPresetGallery.qml;
  upstreamPackage = caelestia-shell.packages.${system}.with-cli;

  guardedSource =
    assert lib.assertMsg (
      builtins.hashFile "sha256" chisaPresetPatch == chisaPresetPatchSha256
    ) "CryoForge Chisa preset gallery patch checksum mismatch";
    assert lib.assertMsg (
      lib.all (
        path:
        builtins.hashFile "sha256" "${caelestia-shell}/${path}" == chisaPresetSourceHashes.${path}
      ) (builtins.attrNames chisaPresetSourceHashes)
    ) "Refusing to apply the Chisa preset gallery patch to changed upstream QML";
    assert lib.assertMsg (
      builtins.hashFile "sha256" "${caelestia-shell}/services/Wallpapers.qml"
      == "4ca7c20c2b6e7b7c38e19781835b7d31aed0e76d3b9be1bf7d4411045879b397"
    ) "Refusing to replace changed upstream Wallpapers.qml";
    assert lib.assertMsg (
      builtins.hashFile "sha256" "${caelestia-shell}/components/images/CachingImage.qml"
      == "1975baaa613da28cabd65a685ea0884682b475fd161d92d11cbee03ba7fbd159"
    ) "Refusing to replace changed upstream CachingImage.qml";
    assert lib.assertMsg (
      builtins.hashFile "sha256" "${caelestia-shell}/modules/bar/components/workspaces/Workspaces.qml"
      == "6629c0e665cca1adcedb116e1b114162ef8da07b6cc27c6975d5b31f3a9c43e5"
    ) "Refusing to transform changed upstream Workspaces.qml";
    assert lib.assertMsg (
      builtins.hashFile "sha256" "${caelestia-shell}/modules/bar/Bar.qml"
      == "0c829a84a980b7c32bebd206216de795b766562de9b7bf6b9b70de1e181e23ff"
    ) "Refusing to transform changed upstream Bar.qml";
    caelestia-shell;
in
upstreamPackage.overrideAttrs (old: {
  pname = "caelestia-shell-cryoforge";
  src = guardedSource;
  patches = (old.patches or [ ]) ++ [
    ../desktop/caelestia/cryoforge-special-workspaces.patch
    chisaPresetPatch
  ];
  patchFlags = (old.patchFlags or [ "-p1" ]) ++ [ "--fuzz=0" ];

  postInstall = (old.postInstall or "") + ''
    ${coreutils}/bin/install -m 0444 \
      ${caelestia-shell}/shell.qml \
      "$out/share/caelestia-shell/shell.qml"
    ${coreutils}/bin/install -m 0444 \
      ${caelestiaChisaPool}/share/caelestia-chisa-pool/background/chisa-pool-direct.jpg \
      "$out/share/caelestia-shell/assets/chisa-pool-direct.jpg"
    ${coreutils}/bin/install -m 0444 \
      ${caelestiaChisaPool}/share/caelestia-chisa-pool/avatar/IMG_5542.jpg \
      "$out/share/caelestia-shell/assets/IMG_5542.jpg"
    ${coreutils}/bin/install -m 0444 \
      ${caelestiaChisaPool}/share/caelestia-chisa-pool/theme.json \
      "$out/share/caelestia-shell/assets/theme.json"
    ${coreutils}/bin/install -m 0444 \
      ${chisaPresetWallpapers} \
      "$out/share/caelestia-shell/services/Wallpapers.qml"
    ${coreutils}/bin/install -m 0444 \
      ${chisaPresetManifest} \
      "$out/share/caelestia-shell/services/ChisaPresets.qml"
    ${coreutils}/bin/install -m 0444 \
      ${chisaPresetGallery} \
      "$out/share/caelestia-shell/modules/nexus/pages/wallandstyle/ChisaPresetGallery.qml"
    ${coreutils}/bin/install -m 0444 \
      ${chisaPoolCachingImage} \
      "$out/share/caelestia-shell/components/images/CachingImage.qml"
  '';
})
