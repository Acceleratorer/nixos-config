{
  caelestia-shell,
  config,
  lib,
  pkgs,
  ...
}:

let
  chisaPoolAssets = pkgs.callPackage ../../packages/caelestia-chisa-pool.nix { };
  realGreeter = pkgs.callPackage ../../packages/caelestia-real-greeter.nix {
    inherit caelestia-shell;
    caelestiaChisaPool = chisaPoolAssets;
  };
  recoveryGreeter = config.programs.regreet.package;
  recoveryLog = "/var/log/regreet/phase13b-recovery.log";
  recoveryLauncher = pkgs.writeShellApplication {
    name = "caelestia-real-greeter-recovery-launcher";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./real-greeter/recovery-launcher.sh;
  };
  greeterCommand = lib.escapeShellArgs (
    [
      "${pkgs.dbus}/bin/dbus-run-session"
      "${pkgs.cage}/bin/cage"
    ]
    ++ config.programs.regreet.cageArgs
    ++ [
      "--"
      "${lib.getExe recoveryLauncher}"
      "${realGreeter}/bin/caelestia-real-greeter"
      "${lib.getExe recoveryGreeter}"
      recoveryLog
    ]
  );
  greeterSession = pkgs.writeShellScript "caelestia-real-greeter-session" ''
    exec ${pkgs.systemd}/bin/systemd-cat \
      --identifier=caelestia-real-greeter \
      -- \
      ${greeterCommand}
  '';
  quietHyprlandSessionData = pkgs.runCommand "caelestia-quiet-hyprland-session-data" { } ''
    mkdir -p "$out/share/wayland-sessions"
    substitute \
      ${pkgs.hyprland}/share/wayland-sessions/hyprland.desktop \
      "$out/share/wayland-sessions/hyprland.desktop" \
      --replace-fail \
      'Exec=${pkgs.hyprland}/bin/start-hyprland' \
      'Exec=${realGreeter.sessionCommand}'
  '';
  requiredKernelParams = [
    "quiet"
    "loglevel=3"
    "udev.log_level=3"
    "rd.udev.log_level=3"
    "systemd.show_status=auto"
    "rd.systemd.show_status=auto"
    "vt.global_cursor_default=0"
  ];
  audition = pkgs.writeShellApplication {
    name = "phase13b-real-greeter-audition";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.systemd
    ];
    text = builtins.readFile ./real-greeter/phase13b-audition.sh;
  };
  command = "${greeterSession}";
in
{
  assertions = [
    {
      assertion = config.programs.regreet.enable;
      message = "The real-greeter audition output requires the accepted ReGreet recovery configuration.";
    }
    {
      assertion = config.users.users.greeter.isSystemUser;
      message = "The real-greeter audition output must run as the existing unprivileged greeter user.";
    }
    {
      assertion = config.services.greetd.settings.default_session.command == command;
      message = "The real-greeter audition output must retain the audited compositor/launcher command.";
    }
    {
      assertion = config.services.greetd.settings.default_session.user == "greeter";
      message = "The real-greeter audition output must not run the QML candidate as root.";
    }
    {
      assertion = config.services.greetd.restart;
      message = "The real-greeter audition output must retain greetd's normal restart behavior.";
    }
    {
      assertion = !config.systemd.services.greetd.stopIfChanged;
      message = "The real-greeter audition output must restart greetd in one transaction, never stop then start it.";
    }
    {
      assertion = config.programs.regreet.settings.appearance.default_session == "Hyprland";
      message = "The ReGreet recovery path must retain the accepted Hyprland session selection.";
    }
    {
      assertion = config.boot.plymouth.enable;
      message = "The real-greeter system requires Plymouth for the graphical boot transition.";
    }
    {
      assertion = !config.boot.initrd.verbose;
      message = "The real-greeter system must suppress routine initrd console output.";
    }
    {
      assertion = config.boot.consoleLogLevel == 3;
      message = "The real-greeter system must retain error-level kernel console diagnostics.";
    }
    {
      assertion = lib.all (param: builtins.elem param config.boot.kernelParams) requiredKernelParams;
      message = "The real-greeter system is missing a required conservative quiet-boot kernel parameter.";
    }
    {
      assertion = config.services.greetd.settings.terminal.vt == 1;
      message = "The real-greeter system must retain greetd on VT1.";
    }
    {
      assertion =
        config.systemd.services.greetd.serviceConfig.StandardOutput == "journal"
        && config.systemd.services.greetd.serviceConfig.StandardError == "journal";
      message = "greetd stdout and stderr must be routed to the systemd journal.";
    }
  ];

  boot = {
    initrd.verbose = false;
    consoleLogLevel = 3;
    kernelParams = [
      "quiet"
      "udev.log_level=3"
      "rd.udev.log_level=3"
      "systemd.show_status=auto"
      "rd.systemd.show_status=auto"
      "vt.global_cursor_default=0"
    ];
    plymouth = {
      enable = true;
      theme = "bgrt";
    };
  };

  services.greetd.settings.default_session = {
    inherit command;
    user = lib.mkForce "greeter";
  };

  systemd.services.greetd = {
    environment.XDG_DATA_DIRS = lib.mkForce (
      "${quietHyprlandSessionData}/share:${config.environment.sessionVariables.XDG_DATA_DIRS}"
    );
    serviceConfig = {
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.tmpfiles.settings = {
    "10-regreet" = {
      "/var/lib/regreet".d.mode = lib.mkForce "0700";
      "/var/log/regreet".d.mode = lib.mkForce "0700";
    };

    "13b-caelestia-real-greeter"."/var/lib/caelestia-real-greeter".d = {
      user = "greeter";
      group = "greeter";
      mode = "0700";
    };
  };

  environment.systemPackages = [
    realGreeter
    recoveryLauncher
    audition
  ];
}
