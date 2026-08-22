{
  caelestia-dots,
  caelestia-shell,
  desktopProfile ? "classic",
  lib,
  pkgs,
  ...
}:

let
  isCaelestiaDerived = builtins.elem desktopProfile [
    "caelestia-stock"
    "caelestia-cryoforge"
  ];
in
{
  imports = [
    caelestia-shell.homeManagerModules.default
    ./desktop/profiles.nix
  ];

  gtk = {
    enable = true;
    colorScheme = "dark";

    font = {
      name = "Adwaita Sans";
      size = 11;
    };

    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
  };

  home.pointerCursor = if isCaelestiaDerived then {
    package = pkgs.sweet-nova;
    name = "Sweet-cursors";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  } else {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  systemd.user.sessionVariables = {
    XCURSOR_THEME =
      if isCaelestiaDerived
      then "Sweet-cursors"
      else "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
  };

  # Change only this value, rebuild, then begin a new Hyprland session.
  nixosCryoforge.desktopProfile = desktopProfile;

  home = {
    username = "accelra";
    homeDirectory = "/home/accelra";
    stateVersion = "26.05";
  };

  home.packages = lib.optionals isCaelestiaDerived [
    (
      caelestia-shell.inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
        withX11 = false;
        withI3 = false;
      }
    )
  ];

  xdg.configFile = lib.optionalAttrs (!isCaelestiaDerived) {
    hypr.source = ./desktop/hypr;
    kitty.source = ./desktop/kitty;
    mako.source = ./desktop/mako;
    rofi.source = ./desktop/rofi;
    waybar.source = ./desktop/waybar;
  };
}
