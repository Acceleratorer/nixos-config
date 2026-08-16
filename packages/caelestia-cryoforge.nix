{
  caelestia-shell,
  coreutils,
  lib,
  stdenv,
}:

let
  system = stdenv.hostPlatform.system;
  upstreamPackage = caelestia-shell.packages.${system}.with-cli;

  guardedSource =
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
  patches = (old.patches or [ ]) ++ [ ../desktop/caelestia/cryoforge-special-workspaces.patch ];
  patchFlags = (old.patchFlags or [ "-p1" ]) ++ [ "--fuzz=0" ];

  postInstall = (old.postInstall or "") + ''
    ${coreutils}/bin/install -m 0444 \
      ${caelestia-shell}/shell.qml \
      "$out/share/caelestia-shell/shell.qml"
  '';
})
