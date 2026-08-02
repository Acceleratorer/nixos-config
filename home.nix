{ caelestia-shell, lib, pkgs, ... }:

let
  enableCaelestiaShellExperiment = true;
in
{
  home = {
    username = "accelra";
    homeDirectory = "/home/accelra";
    packages = lib.optionals enableCaelestiaShellExperiment [
      caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.caelestia-shell
    ];
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
