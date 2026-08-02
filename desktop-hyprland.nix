{ pkgs, ... }:

let
  wallpaper = pkgs.runCommand "caelestia-aurora-wallpaper.png" {
    nativeBuildInputs = [ pkgs.librsvg ];
  } ''
    rsvg-convert \
      --width 2560 \
      --height 1600 \
      ${./desktop/wallpaper.svg} \
      --output "$out"
  '';
in
{
  # GNOME and GDM remain installed as a recovery session.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  services.displayManager.defaultSession = "hyprland";

  services.blueman.enable = true;
  services.gnome.gnome-keyring.enable = true;

  security.pam.services.hyprlock = { };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config.hyprland = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  environment.systemPackages = with pkgs; [
    adw-gtk3
    bibata-cursors
    brightnessctl
    cliphist
    fastfetch
    foot
    grim
    hypridle
    hyprlock
    hyprpaper
    hyprpicker
    kitty
    libnotify
    mako
    networkmanagerapplet
    nwg-look
    pamixer
    papirus-icon-theme
    pavucontrol
    playerctl
    polkit_gnome
    rofi
    slurp
    swappy
    swaybg
    swayosd
    thunar
    waybar
    wl-clipboard
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  environment.etc."nixos-rice/wallpaper.png".source = wallpaper;

  systemd.user.services.hyprland-polkit-agent = {
    description = "Polkit authentication agent for Hyprland";
    serviceConfig = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };
}
