{
  lib,
  fetchFromGitHub,
  hyprland,
  hyprlandPlugins,
}:

hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "hyprexpo";
  version = "0.55.4";

  # Hyprland plugins are ABI-sensitive. This is the upstream v0.55.4 release,
  # pinned for the Hyprland 0.55.4 package in this flake.
  src = fetchFromGitHub {
    owner = "sandwichfarm";
    repo = "hyprexpo";
    rev = "e76761b268a0ee1747d41e21355fa315797a9bfd";
    hash = "sha256-sERoTu9NcGD0RA3jAdHc4GOPkRbgqMrgDT8f7+Jv9fc=";
  };

  inherit (hyprland) nativeBuildInputs;

  meta = {
    description = "An enhanced Hyprland workspaces overview plugin";
    homepage = "https://github.com/sandwichfarm/hyprexpo";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
}
