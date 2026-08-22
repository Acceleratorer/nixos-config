{
  lib,
  stdenvNoCC,
}:

let
  background = ../desktop/caelestia/chisa-pool/chisa-pool-direct.jpg;
  backgroundSha256 = "a4dfcf92c4170405ac37102b27c606c5e9b1bb6cd77c9f04d530fa752aab604c";
  avatar = ../desktop/caelestia/chisa-pool/IMG_5542.jpg;
  avatarSha256 = "50006b77e15bede6ee84dfdd6f282bf03d3b0a0ac912f60644c9700d5e85e1ca";
in
assert lib.assertMsg (builtins.hashFile "sha256" background == backgroundSha256) "chisa-pool-direct.jpg checksum mismatch";
assert lib.assertMsg (builtins.hashFile "sha256" avatar == avatarSha256) "IMG_5542.jpg checksum mismatch";
stdenvNoCC.mkDerivation {
  passthru = {
    inherit avatar avatarSha256 background backgroundSha256;
    id = "chisa-pool";
    sourceUrl = "https://pbs.twimg.com/media/HM1_AEKXoAAPl26.jpg?name=orig";
  };

  pname = "caelestia-chisa-pool-assets";
  version = "1.0.0";
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -dm 0755 "$out/share/caelestia-chisa-pool/background"
    install -dm 0755 "$out/share/caelestia-chisa-pool/avatar"
    install -m 0444 ${background} \
      "$out/share/caelestia-chisa-pool/background/chisa-pool-direct.jpg"
    install -m 0444 ${avatar} \
      "$out/share/caelestia-chisa-pool/avatar/IMG_5542.jpg"
    install -m 0444 ${../desktop/caelestia/chisa-pool/theme.json} \
      "$out/share/caelestia-chisa-pool/theme.json"

    runHook postInstall
  '';

  meta = {
    description = "Fixed Chisa pool visual assets for the Caelestia prototype";
    platforms = lib.platforms.linux;
  };
}
