{
  caelestia-shell,
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixosCryoforge;
  system = pkgs.stdenv.hostPlatform.system;

  hyprlandTarget = "hyprland-session.target";
  classicTarget = "nixos-cryoforge-classic.target";
  caelestiaTarget = "nixos-cryoforge-caelestia.target";
  fallbackService = "nixos-cryoforge-caelestia-fallback.service";
  notificationBus = "org.freedesktop.Notifications";

  classicServiceUnits = [
    "waybar.service"
    "mako.service"
    "hyprpaper.service"
    "hypridle.service"
    "swayosd.service"
  ];

  caelestiaPackage =
    caelestia-shell.packages.${system}.caelestia-shell;
  caelestiaCli = config.programs.caelestia.cli.package;
  caelestiaShellConfig = ./caelestia/shell.json;

  initialiseCaelestiaState = pkgs.writeShellScript "initialise-caelestia-state" ''
    set -eu

    state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
    state_dir="$state_home/caelestia"
    wallpaper_dir="$state_dir/wallpaper"

    ${pkgs.coreutils}/bin/install -d -m 0700 "$state_dir" "$wallpaper_dir"

    if [ ! -s "$state_dir/scheme.json" ]; then
      ${caelestiaCli}/bin/caelestia scheme get --name >/dev/null
    fi

    if [ ! -s "$wallpaper_dir/path.txt" ]; then
      ${pkgs.coreutils}/bin/printf '%s' \
        '/etc/nixos-rice/wallpaper.png' > "$wallpaper_dir/path.txt"
    fi
  '';

  startClassicFallback = pkgs.writeShellScript "start-classic-fallback" ''
    exec ${pkgs.systemd}/bin/systemctl \
      --user --no-block start ${classicTarget}
  '';

  mkClassicService =
    description: execStart:
    {
      Unit = {
        Description = description;
        After = [ hyprlandTarget ];
        PartOf = [ classicTarget ];
        Conflicts = [ "caelestia.service" ];
        ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
      };

      Service = {
        Type = "exec";
        ExecStart = execStart;
        Restart = "on-failure";
        RestartSec = "3s";
        TimeoutStopSec = "5s";
        Slice = "session.slice";
      };

      Install.WantedBy = [ classicTarget ];
    };
in
{
  options.nixosCryoforge = {
    desktopProfile = lib.mkOption {
      type = lib.types.enum [
        "classic"
        "caelestia"
      ];
      default = "classic";
      description = "Hyprland desktop component ownership profile.";
    };

    palette = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = import ./palette.nix;
      description = "CryoForge palette tokens, not consumed by desktop components yet.";
    };
  };

  config = {
    home.activation.initialiseCaelestiaShellConfig =
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
        config_dir="$config_home/caelestia"
        shell_config="$config_dir/shell.json"

        if [[ ! -e "$shell_config" && ! -L "$shell_config" ]]; then
          run ${pkgs.coreutils}/bin/install -d -m 0700 "$config_dir"
          run ${pkgs.coreutils}/bin/install -m 0600 \
            ${caelestiaShellConfig} "$shell_config"
        fi
      '';

    programs.caelestia = {
      enable = true;
      package = caelestiaPackage;

      systemd = {
        enable = true;
        target = caelestiaTarget;
        environment = [
          "QS_APP_ID=org.caelestia.shell"
          "QS_ICON_THEME=Papirus"
        ];
      };

      cli = {
        enable = true;
        settings.theme = {
          enableTerm = false;
          enableHypr = false;
          enableDiscord = false;
          enableSpicetify = false;
          enablePandora = false;
          enableFuzzel = false;
          enableBtop = false;
          enableNvtop = false;
          enableHtop = false;
          enableGtk = false;
          enableQt = false;
          enableWarp = false;
          enableChromium = false;
          enableZed = false;
          enableCava = false;
        };
      };
    };

    xdg.dataFile."applications/org.caelestia.shell.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Caelestia Shell
      NoDisplay=true
    '';

    xdg.configFile = {
      "swayosd/config.toml".text = ''
        [server]
        top_margin = 0.5
        max_volume = 100
        min_brightness = 5
        show_percentage = true
        keyboard_backlight = false

        [client]
      '';

      "swayosd/style.css".text = ''
        window#osd {
          border: 1px solid #4d6fb7;
          border-radius: 16px;
          background: #05070d;
        }

        window#osd #container {
          margin: 4px;
          padding: 12px 16px;
          border-radius: 12px;
          background: #0a1020;
        }

        window#osd image {
          color: #77b6e1;
        }

        window#osd label {
          color: #dcebff;
        }

        window#osd progressbar,
        window#osd segmentedprogress {
          min-height: 8px;
          border-radius: 999px;
          background: transparent;
          border: none;
        }

        window#osd trough,
        window#osd segment {
          min-height: inherit;
          border-radius: inherit;
          border: none;
          background: #111a2e;
        }

        window#osd progress,
        window#osd segment.active {
          min-height: inherit;
          border-radius: inherit;
          border: none;
          background: #00e5ff;
        }

        window#osd segment {
          margin-left: 8px;
        }

        window#osd segment:first-child {
          margin-left: 0;
        }
      '';
    };

    systemd.user.targets = {
      hyprland-session.Unit = {
        Description = "Hyprland compositor session";
        Documentation = [ "man:systemd.special(7)" ];
        BindsTo = [ "graphical-session.target" ];
        Wants = [ "graphical-session-pre.target" ];
        After = [ "graphical-session-pre.target" ];
      };

      nixos-cryoforge-classic = {
        Unit = {
          Description = "NixOS CryoForge classic desktop profile";
          Conflicts = [ caelestiaTarget ];
          PartOf = [ hyprlandTarget ];
          After = [ hyprlandTarget ] ++ classicServiceUnits;
        };
        Install.WantedBy =
          lib.optional (cfg.desktopProfile == "classic") hyprlandTarget;
      };

      nixos-cryoforge-caelestia = {
        Unit = {
          Description = "NixOS CryoForge Caelestia desktop profile";
          Conflicts = [ classicTarget ];
          PartOf = [ hyprlandTarget ];
          After = [
            hyprlandTarget
            "caelestia.service"
          ];
        };
        Install.WantedBy =
          lib.optional (cfg.desktopProfile == "caelestia") hyprlandTarget;
      };
    };

    systemd.user.services = {
      waybar = mkClassicService
        "Waybar for the NixOS CryoForge classic profile"
        "${pkgs.waybar}/bin/waybar";

      mako = mkClassicService
        "Mako for the NixOS CryoForge classic profile"
        "${pkgs.mako}/bin/mako";

      hyprpaper = mkClassicService
        "hyprpaper for the NixOS CryoForge classic profile"
        "${pkgs.hyprpaper}/bin/hyprpaper";

      hypridle = mkClassicService
        "hypridle for the NixOS CryoForge classic profile"
        "${pkgs.hypridle}/bin/hypridle";

      swayosd = mkClassicService
        "SwayOSD for the NixOS CryoForge classic profile"
        "${pkgs.swayosd}/bin/swayosd-server --config ${config.xdg.configHome}/swayosd/config.toml --style ${config.xdg.configHome}/swayosd/style.css";

      caelestia = {
        Unit = {
          After = lib.mkForce [ hyprlandTarget ];
          Conflicts = classicServiceUnits;
          ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
          OnFailure = [ fallbackService ];
        };

        Service = {
          Type = lib.mkForce "dbus";
          BusName = notificationBus;
          ExecStartPre = initialiseCaelestiaState;
          ExecStop = "-${caelestiaPackage}/bin/caelestia-shell kill";
          Restart = lib.mkForce "no";
          TimeoutStartSec = "10s";
          TimeoutStopSec = lib.mkForce "15s";

          # Experimental exception: Quickshell launches desktop entries with
          # QProcess::startDetached(), without a supported systemd scope hook.
          # They inherit this cgroup and must survive shell shutdown; validate
          # the remaining-cgroup behaviour before enabling this profile.
          KillMode = "process";
          UMask = "0077";
        };
      };

      nixos-cryoforge-caelestia-fallback = {
        Unit = {
          Description = "Fall back to the NixOS CryoForge classic profile";
          After = [ "caelestia.service" ];
        };

        Service = {
          Type = "oneshot";
          ExecStart = startClassicFallback;
        };
      };
    };
  };
}
