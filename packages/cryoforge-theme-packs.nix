{ stdenvNoCC }:

let
  registry = import ../desktop/themes/registry.nix { };
  renderedRegistry = builtins.toFile
    "cryoforge-theme-packs-registry.json"
    (builtins.toJSON registry + "\n");
in
stdenvNoCC.mkDerivation {
  pname = "cryoforge-theme-packs";
  version = "1.0.0";
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm0444 \
      ${renderedRegistry} \
      "$out/share/cryoforge/theme-packs/registry.json"

    runHook postInstall
  '';
}
