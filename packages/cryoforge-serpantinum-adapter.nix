{
  cryoforgeThemeRuntime,
  lib,
  python3,
  registry ? import ../desktop/themes/registry.nix { },
  resolver ? null,
  stdenvNoCC,
  writeShellApplication,
}:

let
  resolverPath =
    if resolver == null
    then "${cryoforgeThemeRuntime}/bin/cryoforge-resolve-active-theme"
    else toString resolver;
  allowedCompositions = builtins.listToAttrs (
    map (pack: {
      name = pack.id;
      value = pack.allowedWallpaperPackIds;
    }) registry.packs
  );
  adapter = writeShellApplication {
    name = "cryoforge-serpantinum-adapter";
    runtimeInputs = [ python3 ];
    text = lib.replaceStrings
      [
        "@PYTHON@"
        "@RESOLVER@"
        "@ALLOWED_COMPOSITIONS@"
      ]
      [
        (lib.escapeShellArg "${python3}/bin/python3")
        (builtins.toJSON resolverPath)
        (builtins.toJSON allowedCompositions)
      ]
      (builtins.readFile ../desktop/themes/serpantinum-adapter.sh);
  };
in
stdenvNoCC.mkDerivation {
  pname = "cryoforge-serpantinum-adapter";
  version = "0.1.0";
  dontUnpack = true;
  passthru = {
    inherit adapter resolverPath;
  };

  installPhase = ''
    runHook preInstall

    install -Dm0555 \
      ${adapter}/bin/cryoforge-serpantinum-adapter \
      "$out/bin/cryoforge-serpantinum-adapter"

    runHook postInstall
  '';

  meta = {
    description = "Read-only CryoForge resolver adapter for Serpantinum";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "cryoforge-serpantinum-adapter";
  };
}
