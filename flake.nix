{
  description = "accelra's NixOS configuration";

  inputs = {
    nixpkgs.url = "https://releases.nixos.org/nixos/26.05/nixos-26.05.6282.2f5a153c270b/nixexprs.tar.xz";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-dots = {
      url = "github:caelestia-dots/caelestia/a6ed1e5e831aba9aac46265ae156db4fab2b9e43";
      flake = false;
    };

    caelestia-shell = {
      url = "github:caelestia-dots/shell/817a220e8e87c4df9f3681033a0d8a8054cdaa30";
      inputs.caelestia-cli.url = "github:caelestia-dots/cli/751fbc555a83faba5dd589270d14eeb22afab174";
      inputs.caelestia-cli.inputs.caelestia-shell.follows = "caelestia-shell";
      inputs.caelestia-cli.inputs.nixpkgs.follows = "caelestia-shell/nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.quickshell.url = "git+https://git.outfoxxed.me/outfoxxed/quickshell?rev=28771c7c74b42e20afca0b1b63980cb46515537c";
      inputs.quickshell.inputs.nixpkgs.follows = "caelestia-shell/nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, caelestia-dots, caelestia-shell, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      mkNixos = {
        desktopProfile ? "classic",
        extraModules ? [ ],
        extraSpecialArgs ? { },
      }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit desktopProfile; } // extraSpecialArgs;
          modules =
            [
              ./configuration.nix
              home-manager.nixosModules.home-manager
              {
                home-manager = {
                  extraSpecialArgs = {
                    inherit caelestia-dots caelestia-shell desktopProfile;
                  };
                  useGlobalPkgs = true;
                  users.accelra = import ./home.nix;
                };

                system.nixos.revision = "2f5a153c270b70cb0f8c11f46d96d6d3bc39f4e3";
                system.nixos.versionSuffix = ".6282.2f5a153c270b";
              }
            ]
            ++ extraModules;
        };
      caelestiaChisaPool =
        pkgs.callPackage ./packages/caelestia-chisa-pool.nix { };
      caelestiaRealGreeter =
        pkgs.callPackage ./packages/caelestia-real-greeter.nix {
          inherit caelestia-shell;
          caelestiaChisaPool = caelestiaChisaPool;
        };
      caelestiaCryoforge =
        pkgs.callPackage ./packages/caelestia-cryoforge.nix {
          inherit caelestia-shell;
          caelestiaChisaPool = caelestiaChisaPool;
        };
      caelestiaRealLock =
        pkgs.callPackage ./packages/caelestia-real-lock.nix {
          inherit caelestia-shell;
          caelestiaShellCryoforge = caelestiaCryoforge;
          caelestiaChisaPool = caelestiaChisaPool;
        };
      caelestiaChisaPoolPreviews =
        pkgs.callPackage ./packages/caelestia-chisa-pool-previews.nix {
          inherit caelestiaRealGreeter;
          inherit (pkgs) libglvnd mesa xorgserver;
        };
      cryoforgeSystem = mkNixos {
        desktopProfile = "caelestia-cryoforge";
      };
      realGreeterSystem = mkNixos {
        desktopProfile = "caelestia-cryoforge";
        extraModules = [
          ./desktop/caelestia/real-greeter-system.nix
          {
            # This dedicated audition output must replace the running ReGreet
            # command. The accepted CryoForge output retains greetd's normal
            # session-protection behavior. Keep the candidate transition as
            # one systemd restart transaction: the default stop-then-start
            # path left greetd inactive when the first audition was
            # interrupted between those two operations.
            systemd.services.greetd.restartIfChanged = nixpkgs.lib.mkForce true;
            systemd.services.greetd.stopIfChanged = nixpkgs.lib.mkForce false;
          }
        ];
        extraSpecialArgs = { inherit caelestia-shell; };
      };
      recoveryGreeter = cryoforgeSystem.config.programs.regreet.package;
      cryoforgeCommand = cryoforgeSystem.config.services.greetd.settings.default_session.command;
      realGreeterCommand = realGreeterSystem.config.services.greetd.settings.default_session.command;
      cryoforgeGreetdUnit = cryoforgeSystem.config.systemd.units."greetd.service".unit;
      realGreeterGreetdUnit = realGreeterSystem.config.systemd.units."greetd.service".unit;
      realGreeterSessionData = builtins.head (
        nixpkgs.lib.splitString ":"
          realGreeterSystem.config.systemd.services.greetd.environment.XDG_DATA_DIRS
      );
      expectedCryoforgeCommand = nixpkgs.lib.escapeShellArgs (
        [
          "${pkgs.dbus}/bin/dbus-run-session"
          "${pkgs.cage}/bin/cage"
        ]
        ++ cryoforgeSystem.config.programs.regreet.cageArgs
        ++ [
          "--"
          "${nixpkgs.lib.getExe recoveryGreeter}"
        ]
      );
    in {
    packages.${system} = {
      caelestia-chisa-pool = caelestiaChisaPool;
      caelestia-chisa-pool-previews = caelestiaChisaPoolPreviews;
      caelestia-shell-cryoforge = caelestiaCryoforge;
      caelestia-real-greeter = caelestiaRealGreeter;
      caelestia-real-lock = caelestiaRealLock;
      hyprexpo = pkgs.callPackage ./packages/hyprexpo.nix { };
    };

    checks.${system} = {
      inherit caelestiaRealGreeter;

      phase13c-real-lock-contract =
        pkgs.runCommand "phase13c-real-lock-contract-tests" {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.gnugrep
          ];
        } ''
          bash ${./tests/phase13c/test_real_lock_contract.sh} \
            ${caelestiaRealLock}/share/caelestia-real-lock \
            ${caelestia-shell} \
            ${caelestiaRealLock.quickshell} \
            ${caelestiaRealGreeter}/share/caelestia-real-greeter \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/keybinds.lua".source}
          touch "$out"
        '';

      chisa-pool-assets = pkgs.runCommand "chisa-pool-asset-contract-tests" {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.gnugrep
        ];
      } ''
        assets=${caelestiaChisaPool}/share/caelestia-chisa-pool
        greeter=${caelestiaRealGreeter}/share/caelestia-real-greeter
        lock=${caelestiaRealLock}/share/caelestia-real-lock
        shell=${caelestiaCryoforge}/share/caelestia-shell

        test -r "$assets/background/chisa-pool-direct.jpg"
        test -r "$assets/avatar/IMG_5542.jpg"
        test -r "$assets/theme.json"
        grep -Fqx '  "id": "chisa-pool",' "$assets/theme.json"
        grep -Fqx '  "selection": "manual"' "$assets/theme.json"

        test "$(sha256sum "$assets/background/chisa-pool-direct.jpg" | cut -d ' ' -f 1)" = \
          a4dfcf92c4170405ac37102b27c606c5e9b1bb6cd77c9f04d530fa752aab604c
        test "$(sha256sum "$assets/avatar/IMG_5542.jpg" | cut -d ' ' -f 1)" = \
          50006b77e15bede6ee84dfdd6f282bf03d3b0a0ac912f60644c9700d5e85e1ca

        for root in "$greeter" "$lock" "$shell"; do
          test -r "$root/assets/chisa-pool-direct.jpg"
          test -r "$root/assets/IMG_5542.jpg"
          test -r "$root/assets/theme.json"
        done

        test "$(readlink "$greeter/assets/greeter-wallpaper.png")" = chisa-pool-direct.jpg
        grep -Fq '@AVATAR@' ${./desktop/caelestia/real-greeter/launch-runtime.sh}
        grep -Fq 'IMG_5542.jpg' ${caelestiaRealGreeter}/bin/.caelestia-real-greeter-qml-wrapped
        grep -Fq 'chisa-pool-direct.jpg' "$shell/services/Wallpapers.qml"
        test "$(sha256sum "$greeter/modules/lock/center/ProfilePic.qml" | cut -d ' ' -f 1)" = \
          b38f25dd2604223bbf2dae1f2046399bd80182c17742710893a06dad64fe90a9
        test "$(sha256sum "$shell/modules/lock/center/ProfilePic.qml" | cut -d ' ' -f 1)" = \
          b38f25dd2604223bbf2dae1f2046399bd80182c17742710893a06dad64fe90a9
        test "$(sha256sum "$greeter/components/images/CachingImage.qml" | cut -d ' ' -f 1)" = \
          bc6c1658f0f2748ae96970b07f0e20aa86baf1dd07437e5a7726d0cddc0e9419
        test "$(sha256sum "$shell/components/images/CachingImage.qml" | cut -d ' ' -f 1)" = \
          bc6c1658f0f2748ae96970b07f0e20aa86baf1dd07437e5a7726d0cddc0e9419
        grep -Fq 'width: root.chisaPoolProfileAvatar ? root.width * 1.08 : root.width' \
          "$greeter/components/images/CachingImage.qml"
        grep -Fq 'root.width * 0.04' "$greeter/components/images/CachingImage.qml"
        grep -Fq 'root.height * 0.03' "$greeter/components/images/CachingImage.qml"
        ! find "$assets" "$greeter" "$lock" "$shell" \
          \( -iname '*img7*' -o -iname '*denia*' \) -print | grep -q .
        ! grep -R -q -i -E 'img7|denia' \
          "$assets" "$greeter" "$lock" "$shell" \
          --include='*.qml' --include='*.json' --include='*.sh' --include='README'
        ! grep -q -E 'random|rotation|rotate|timer|cycle' "$assets/theme.json"
        ! grep -q -E 'Quickshell\.execDetached|Process[[:space:]]*\{|Timer[[:space:]]*\{' \
          ${./desktop/caelestia/chisa-pool/Wallpapers.qml}
        touch "$out"
      '';

      phase16a-chisa-preset-gallery-contract = pkgs.runCommand "phase16a-chisa-preset-gallery-contract-tests" {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnugrep
        ];
      } ''
        bash ${./tests/phase16a/test_chisa_preset_gallery_contract.sh} \
          ${caelestiaCryoforge}/share/caelestia-shell \
          ${caelestia-shell} \
          ${./packages/caelestia-cryoforge.nix} \
          ${./desktop/caelestia/cryoforge-chisa-preset-gallery.patch} \
          ${./desktop/caelestia/chisa-pool/ChisaPresets.qml} \
          ${./desktop/caelestia/chisa-pool/ChisaPresetGallery.qml} \
          ${./desktop/caelestia/chisa-pool/ChisaPresetWallpapers.qml}
        touch "$out"
      '';

      chisa-pool-previews = caelestiaChisaPoolPreviews;

      phase13b-recovery-launcher = pkgs.runCommand "phase13b-recovery-launcher-tests" {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gnused
        ];
      } ''
        bash ${./desktop/caelestia/real-greeter/tests/recovery_launcher_test.sh} \
          ${./desktop/caelestia/real-greeter/recovery-launcher.sh}
        touch "$out"
      '';

      phase13b-controller-recovery = pkgs.runCommand "phase13b-controller-recovery-tests" {
        nativeBuildInputs = [
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.python3
        ];
      } ''
        export PYTHONDONTWRITEBYTECODE=1
        export QT_QPA_PLATFORM=offscreen
        export QSG_RHI_BACKEND=software
        export XDG_RUNTIME_DIR="$TMPDIR/runtime"
        mkdir -m 0700 "$XDG_RUNTIME_DIR"

        for scenario in \
          success \
          failure-retry \
          cancel \
          cancel-late-success \
          cancel-late-failure \
          cancel-late-auth-message \
          cancel-late-duplicate \
          cancel-late-start-session \
          cancel-fresh-success \
          recovery \
          recovery-initial \
          recovery-late-success \
          recovery-launching-rejected; do
          CAELESTIA_GREETER_RUNTIME_DIR="$TMPDIR/candidate-$scenario" \
          CAELESTIA_CONTROLLER_LOG="$TMPDIR/$scenario.log" \
          ${pkgs.python3}/bin/python3 \
            ${caelestiaRealGreeter}/share/caelestia-real-greeter/tests/fake_greetd_protocol.py \
            "controller-$scenario" -- \
            ${caelestiaRealGreeter}/bin/caelestia-real-greeter-controller-test
        done

        find "$TMPDIR" -type f \( -name '*.log' -o -name '*.qslog' \) \
          -exec grep -F -l 'phase13a-password-literal-must-not-appear' {} + \
          > "$TMPDIR/password-leaks" || true
        if [ -s "$TMPDIR/password-leaks" ]; then
          cat "$TMPDIR/password-leaks" >&2
          echo "Password sentinel appeared in controller or Quickshell logs." >&2
          exit 1
        fi
        touch "$out"
      '';

      phase13b-greetd-activation-transaction = pkgs.runCommand "phase13b-greetd-activation-transaction-tests" {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.gnused
        ];
      } ''
        bash ${./desktop/caelestia/real-greeter/tests/greetd_activation_transaction_test.sh} \
          ${cryoforgeGreetdUnit}/greetd.service \
          ${realGreeterGreetdUnit}/greetd.service
        touch "$out"
      '';

      phase13b-system-contract =
        assert cryoforgeCommand == expectedCryoforgeCommand;
        assert realGreeterSystem.config.programs.regreet.package == recoveryGreeter;
        assert realGreeterSystem.config.services.greetd.settings.default_session.user == "greeter";
        assert realGreeterSystem.config.services.greetd.restart;
        assert realGreeterSystem.config.systemd.services.greetd.restartIfChanged;
        assert !realGreeterSystem.config.systemd.services.greetd.stopIfChanged;
        assert !cryoforgeSystem.config.systemd.services.greetd.restartIfChanged;
        assert cryoforgeSystem.config.systemd.services.greetd.stopIfChanged;
        assert realGreeterSystem.config.boot.plymouth.enable;
        assert realGreeterSystem.config.boot.plymouth.theme == "bgrt";
        assert !realGreeterSystem.config.boot.initrd.verbose;
        assert realGreeterSystem.config.boot.consoleLogLevel == 3;
        assert nixpkgs.lib.all
          (param: builtins.elem param realGreeterSystem.config.boot.kernelParams)
          [
            "quiet"
            "loglevel=3"
            "udev.log_level=3"
            "rd.udev.log_level=3"
            "systemd.show_status=auto"
            "rd.systemd.show_status=auto"
            "vt.global_cursor_default=0"
            "splash"
          ];
        assert realGreeterSystem.config.systemd.services.greetd.serviceConfig.StandardOutput == "journal";
        assert realGreeterSystem.config.systemd.services.greetd.serviceConfig.StandardError == "journal";
        assert realGreeterSystem.config.services.greetd.settings.terminal.vt == 1;
        assert realGreeterSystem.config.systemd.services."getty@".enable;
        assert builtins.elem "autovt@.service" realGreeterSystem.config.systemd.services."getty@".aliases;
        assert !realGreeterSystem.config.systemd.services."autovt@tty1".enable;
        assert realGreeterSystem.config.systemd.tmpfiles.settings."10-regreet"."/var/lib/regreet".d.mode == "0700";
        assert realGreeterSystem.config.systemd.tmpfiles.settings."10-regreet"."/var/log/regreet".d.mode == "0700";
        assert realGreeterSystem.config.systemd.tmpfiles.settings."13b-caelestia-real-greeter"."/var/lib/caelestia-real-greeter".d.mode == "0700";
        pkgs.runCommand "phase13b-system-contract" {
          nativeBuildInputs = [ pkgs.gnugrep ];
        } ''
          grep -Fq \
            'exec ${pkgs.systemd}/bin/systemd-cat' \
            ${realGreeterCommand}
          grep -Fq -- \
            '--identifier=caelestia-real-greeter' \
            ${realGreeterCommand}
          grep -Fq \
            '${pkgs.dbus}/bin/dbus-run-session ${pkgs.cage}/bin/cage' \
            ${realGreeterCommand}
          grep -Fq \
            '${caelestiaRealGreeter}/bin/caelestia-real-greeter' \
            ${realGreeterCommand}
          grep -Fq \
            '${nixpkgs.lib.getExe recoveryGreeter}' \
            ${realGreeterCommand}
          grep -Fqx \
            'Exec=${pkgs.hyprland}/bin/start-hyprland' \
            ${pkgs.hyprland}/share/wayland-sessions/hyprland.desktop
          grep -Fq \
            'exec ${pkgs.systemd}/bin/systemd-cat' \
            ${caelestiaRealGreeter.sessionCommand}
          grep -Fq -- \
            '--identifier=caelestia-hyprland-session' \
            ${caelestiaRealGreeter.sessionCommand}
          grep -Fq \
            '${pkgs.hyprland}/bin/start-hyprland "$@"' \
            ${caelestiaRealGreeter.sessionCommand}
          grep -Fqx \
            'Exec=${caelestiaRealGreeter.sessionCommand}' \
            ${realGreeterSessionData}/wayland-sessions/hyprland.desktop
          grep -Fq \
            'property list<string> sessionCommand: ["${caelestiaRealGreeter.sessionCommand}"]' \
            ${caelestiaRealGreeter}/share/caelestia-real-greeter/real-greeter/adapters/GreetdController.qml
          grep -Fq \
            'phase13b-real-greeter-audition' \
            ${realGreeterSystem.config.system.build.toplevel}/sw/bin/phase13b-real-greeter-audition
          ! grep -Fqx 'X-RestartIfChanged=false' ${realGreeterGreetdUnit}/greetd.service
          grep -Fqx 'X-StopIfChanged=false' ${realGreeterGreetdUnit}/greetd.service
          grep -Fqx 'StandardOutput=journal' ${realGreeterGreetdUnit}/greetd.service
          grep -Fqx 'StandardError=journal' ${realGreeterGreetdUnit}/greetd.service
          ! grep -Fqx 'StandardOutput=tty' ${realGreeterGreetdUnit}/greetd.service
          ! grep -Fqx 'StandardError=tty' ${realGreeterGreetdUnit}/greetd.service
          grep -Fqx 'X-RestartIfChanged=false' ${cryoforgeGreetdUnit}/greetd.service
          ! grep -Fqx 'X-StopIfChanged=false' ${cryoforgeGreetdUnit}/greetd.service
          test "$(readlink ${realGreeterSystem.config.system.build.toplevel}/etc/systemd/system/autovt@.service)" = \
            getty@.service
          test "$(readlink -f \
            ${realGreeterSystem.config.system.build.toplevel}/etc/systemd/system/autovt@tty1.service)" = \
            /dev/null
          touch "$out"
        '';
    };

    nixosConfigurations.nixos = mkNixos { };

    nixosConfigurations.nixos-caelestia-stock = mkNixos {
      desktopProfile = "caelestia-stock";
    };

    nixosConfigurations.nixos-caelestia-cryoforge = cryoforgeSystem;

    nixosConfigurations.nixos-caelestia-cryoforge-real-greeter = realGreeterSystem;
  };
}
