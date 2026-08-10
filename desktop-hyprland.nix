{ config, pkgs, ... }:

let
  hyprexpo = pkgs.callPackage ./packages/hyprexpo.nix {
    hyprland = config.programs.hyprland.package;
  };

  # Rofi 2.0.0 repeatedly crashes in its native Wayland teardown path.
  # Hyprland already provides XWayland, so keep Rofi on its stable XCB backend.
  rofiX11 = pkgs.rofi.override {
    rofi-unwrapped = pkgs.rofi-unwrapped.override {
      waylandSupport = false;
    };
  };

  hyprlandSessionTarget = "hyprland-session.target";
  hyprlandSessionServices = [
    "hyprland-polkit-agent.service"
    "xdg-desktop-portal-hyprland.service"
  ];

  hyprlandSessionReady = pkgs.writeShellScript "hyprland-session-ready" ''
    set -e

    runtime_dir="''${XDG_RUNTIME_DIR:-}"

    test -n "$runtime_dir"
    test -n "''${DISPLAY:-}"
    test -n "''${WAYLAND_DISPLAY:-}"
    test -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}"
    test "''${XDG_CURRENT_DESKTOP:-}" = "Hyprland"
    test -S "$runtime_dir/$WAYLAND_DISPLAY"

    exec ${pkgs.hyprland}/bin/hyprctl -j monitors >/dev/null
  '';

  prepareHyprlandSession = pkgs.writeShellApplication {
    name = "prepare-hyprland-session";
    runtimeInputs = with pkgs; [
      coreutils
      dbus
      systemd
    ];
    text = ''
      set -eu

      ready=false
      for _ in $(seq 1 100); do
        if ${hyprlandSessionReady}; then
          ready=true
          break
        fi
        sleep 0.1
      done

      if [ "$ready" != true ]; then
        echo "Timed out waiting for the current Hyprland compositor" >&2
        exit 1
      fi

      systemctl --user stop ${hyprlandSessionTarget}

      dbus-update-activation-environment --systemd \
        DISPLAY \
        WAYLAND_DISPLAY \
        XDG_CURRENT_DESKTOP \
        HYPRLAND_INSTANCE_SIGNATURE

      systemctl --user reset-failed ${toString hyprlandSessionServices} || true
      systemctl --user start ${hyprlandSessionTarget}
    '';
  };

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
    prepareHyprlandSession
    rofiX11
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

  environment.etc."hypr/hyprexpo.conf".text = ''
    plugin = ${hyprexpo}/lib/libhyprexpo.so
  '';

  systemd.user.services = {
    hyprland-polkit-agent = {
      description = "Polkit authentication agent for Hyprland";
      wantedBy = [ hyprlandSessionTarget ];
      partOf = [ hyprlandSessionTarget ];
      after = [ hyprlandSessionTarget ];
      unitConfig.ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
      serviceConfig = {
        ExecCondition = hyprlandSessionReady;
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
      };
    };

    xdg-desktop-portal-hyprland = {
      overrideStrategy = "asDropin";
      wantedBy = [ hyprlandSessionTarget ];
      partOf = [ hyprlandSessionTarget ];
      after = [ hyprlandSessionTarget ];
      unitConfig.ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
      serviceConfig.ExecCondition = hyprlandSessionReady;
    };
  };
}
