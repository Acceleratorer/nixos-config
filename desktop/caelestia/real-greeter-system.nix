{
  caelestia-shell,
  config,
  lib,
  pkgs,
  ...
}:

let
  realGreeter = pkgs.callPackage ../../packages/caelestia-real-greeter.nix {
    inherit caelestia-shell;
  };
  recoveryGreeter = config.programs.regreet.package;
  recoveryLog = "/var/log/regreet/phase13b-recovery.log";
  recoveryLauncher = pkgs.writeShellApplication {
    name = "caelestia-real-greeter-recovery-launcher";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./real-greeter/recovery-launcher.sh;
  };
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
  command = lib.escapeShellArgs (
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
  ];

  services.greetd.settings.default_session = {
    inherit command;
    user = lib.mkForce "greeter";
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
