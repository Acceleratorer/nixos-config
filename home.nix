{ caelestia-shell, pkgs, ... }:

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

  home.pointerCursor = {
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
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "24";
  };

  # Change only this value, rebuild, then begin a new Hyprland session.
  nixosCryoforge.desktopProfile = "classic";

  home = {
    username = "accelra";
    homeDirectory = "/home/accelra";
    stateVersion = "26.05";
  };

  xdg.configFile = {
    hypr.source = ./desktop/hypr;
    kitty.source = ./desktop/kitty;
    mako.source = ./desktop/mako;
    rofi.source = ./desktop/rofi;
    waybar.source = ./desktop/waybar;
  };
}
