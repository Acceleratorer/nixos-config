{
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
