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
      themeRegistryModel = import ./desktop/themes/registry.nix;
      currentThemeRegistry = themeRegistryModel { };
      neutralThemePack = builtins.head currentThemeRegistry.packs;
      phase19aThemeRegistry = themeRegistryModel {
        registry = currentThemeRegistry // {
          packs = [ neutralThemePack ];
        };
      };
      cryoforgeThemePacks =
        pkgs.callPackage ./packages/cryoforge-theme-packs.nix {
          registry = currentThemeRegistry;
        };
      currentThemePacks = cryoforgeThemePacks;
      phase19aThemePacks =
        pkgs.callPackage ./packages/cryoforge-theme-packs.nix {
          registry = phase19aThemeRegistry;
          version = "1.0.0";
          includeCuratedAssets = false;
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
      classicSystem = mkNixos { };
      stockSystem = mkNixos {
        desktopProfile = "caelestia-stock";
      };
      activationSeedScript = systemConfig:
        let
          activation =
            systemConfig.config.home-manager.users.accelra.home.activation
              .initialiseCaelestiaShellConfig.data;
        in
        assert nixpkgs.lib.hasPrefix "run " activation;
        nixpkgs.lib.removeSuffix "\n" (
          nixpkgs.lib.removePrefix "run " activation
        );
      targetSeedScript = activationSeedScript realGreeterSystem;
      stockSeedScript = activationSeedScript stockSystem;
      replaceExactly = label: needle: replacement: value:
        let
          parts = nixpkgs.lib.splitString needle value;
        in
        assert nixpkgs.lib.assertMsg (
          builtins.length parts == 2
        ) "${label} must match exactly once";
        nixpkgs.lib.concatStringsSep replacement parts;
      # R3 historical projection begin
      removeDelimited = label: start: end: value:
        let
          startParts = nixpkgs.lib.splitString start value;
          endParts = nixpkgs.lib.splitString end (builtins.elemAt startParts 1);
        in
        assert nixpkgs.lib.assertMsg (
          builtins.length startParts == 2
          && builtins.length endParts == 2
        ) "${label} markers must occur exactly once";
        builtins.head startParts + builtins.elemAt endParts 1;
      r3ProjectionStart =
        "      # R3 historical projection begin\n";
      r3ProjectionEnd =
        "      # R3 historical projection end\n";
      currentFlakeSource = builtins.readFile ./flake.nix;
      flakeWithoutR3Projection = removeDelimited
        "R3 historical projection"
        r3ProjectionStart
        r3ProjectionEnd
        currentFlakeSource;
      preR3FlakeSourceText = builtins.replaceStrings
        [
          "\${r3HistoricalSourceProjection}/desktop/caelestia/real-greeter-system.nix"
          "\${r3HistoricalSourceProjection}/desktop/caelestia/real-greeter"
          "\${r3HistoricalSourceProjection}/flake.nix"
          "\${r3HistoricalSourceProjection}"
          "        assert realGreeterSystem.config.systemd.services.greetd.serviceConfig.Restart == \"always\";\n"
          "          grep -Fqx 'Restart=always' \${realGreeterGreetdUnit}/greetd.service\n"
        ]
        [
          "\${./desktop/caelestia/real-greeter-system.nix}"
          "\${./desktop/caelestia/real-greeter}"
          "\${./flake.nix}"
          "\${./.}"
          ""
          ""
        ]
        flakeWithoutR3Projection;
      preR3FlakeSource =
        assert nixpkgs.lib.assertMsg (
          builtins.hashString "sha256" preR3FlakeSourceText
          == "a99978a6c7475c4cf80c34083fd4d1a67c87f19730487b576187fe1d97e91244"
        ) "Pre-R3 flake projection changed historical content";
        builtins.toFile "r3-pre-r3-flake.nix" preR3FlakeSourceText;
      currentRealGreeterSystemSource =
        builtins.readFile ./desktop/caelestia/real-greeter-system.nix;
      preR3RealGreeterSystemSourceText =
        replaceExactly
          "R3 greetd restart policy"
          "      Restart = lib.mkForce \"always\";\n"
          ""
          (
            removeDelimited
              "R3 greetd restart assertion"
              "    {\n      assertion = config.systemd.services.greetd.serviceConfig.Restart == \"always\";\n"
              "      message = \"The real-greeter target must always recover from an exited greetd process.\";\n    }\n"
              currentRealGreeterSystemSource
          );
      preR3RealGreeterSystemSource =
        assert nixpkgs.lib.assertMsg (
          builtins.hashString "sha256" preR3RealGreeterSystemSourceText
          == "e63487de3f193c738a13bb4429b6bc83c01f73767de81057cb1e1ead58f99ce3"
        ) "Pre-R3 real-greeter system projection changed historical content";
        builtins.toFile
          "r3-pre-r3-real-greeter-system.nix"
          preR3RealGreeterSystemSourceText;
      currentRecoveryLauncherSource =
        builtins.readFile ./desktop/caelestia/real-greeter/recovery-launcher.sh;
      preR3RecoveryLauncherSourceText =
        replaceExactly
          "R3 recovery launcher environment"
          ''
            start_recovery() {
                exec env \
                    HOME="$recovery_state_root/home" \
                    XDG_CACHE_HOME="$recovery_runtime_root/cache" \
                    XDG_CONFIG_HOME="$recovery_runtime_root/config" \
                    XDG_DATA_HOME="$recovery_runtime_root/data" \
                    XDG_STATE_HOME="$recovery_state_root/state" \
                    "$recovery" --logs "$recovery_log" --log-level warn
            }
          ''
          ''
            start_recovery() {
                exec "$recovery" --logs "$recovery_log" --log-level warn
            }
          ''
          (
            removeDelimited
              "R3 recovery state directories"
              "    \"$state_root/recovery\" \\\n"
              "    \"$state_root/recovery/state\" \\\n"
              (
                removeDelimited
                  "R3 recovery runtime directories"
                  "    \"$runtime_root/recovery\" \\\n"
                  "    \"$runtime_root/recovery/data\" \\\n"
                  (
                    removeDelimited
                      "R3 recovery roots"
                      "recovery_runtime_root=\"$runtime_root/recovery\"\n"
                      "recovery_state_root=\"$state_root/recovery\"\n"
                      currentRecoveryLauncherSource
                  )
              )
          );
      preR3RecoveryLauncherSource =
        assert nixpkgs.lib.assertMsg (
          builtins.hashString "sha256" preR3RecoveryLauncherSourceText
          == "b9c45baa3af6c00b465b01eb88bcf98ce9aa613d35b0aa8d7359f13278e2961c"
        ) "Pre-R3 recovery launcher projection changed historical content";
        builtins.toFile
          "r3-pre-r3-recovery-launcher.sh"
          preR3RecoveryLauncherSourceText;
      currentRecoveryLauncherTestSource =
        builtins.readFile ./desktop/caelestia/real-greeter/tests/recovery_launcher_test.sh;
      preR3RecoveryLauncherTestSourceText =
        removeDelimited
          "R3 recovery launcher ambient XDG test"
          "        HOME=\"$test_root/ambient-home-$run_number\" \\\n"
          "        XDG_STATE_HOME=\"$test_root/ambient-state-$run_number\" \\\n"
          (
            removeDelimited
              "R3 recovery launcher private XDG test"
              "    test \"$HOME\" = \"$CAELESTIA_GREETER_STATE_ROOT/recovery/home\"\n"
              "    test \"$XDG_STATE_HOME\" != \"$CAELESTIA_GREETER_STATE_ROOT/state\"\n"
              currentRecoveryLauncherTestSource
          );
      preR3RecoveryLauncherTestSource =
        assert nixpkgs.lib.assertMsg (
          builtins.hashString "sha256" preR3RecoveryLauncherTestSourceText
          == "2d152de7ae38ff3e5c5c404db7e82b12faf5ba73a8c45daf83684a7f1d8c1d56"
        ) "Pre-R3 recovery launcher test projection changed historical content";
        builtins.toFile
          "r3-pre-r3-recovery-launcher-test.sh"
          preR3RecoveryLauncherTestSourceText;
      r3HistoricalSourceProjection =
        pkgs.runCommand "r3-historical-source-projection" { } ''
          mkdir -p "$out"
          cp -R ${./.}/. "$out/"
          chmod -R u+w "$out"
          install -m 0444 ${preR3FlakeSource} "$out/flake.nix"
          install -m 0444 \
            ${preR3RealGreeterSystemSource} \
            "$out/desktop/caelestia/real-greeter-system.nix"
          install -m 0444 \
            ${preR3RecoveryLauncherSource} \
            "$out/desktop/caelestia/real-greeter/recovery-launcher.sh"
          install -m 0555 \
            ${preR3RecoveryLauncherTestSource} \
            "$out/desktop/caelestia/real-greeter/tests/recovery_launcher_test.sh"
        '';
      # R3 historical projection end
      phase19aRegistrySourceText =
        replaceExactly
          "Phase 19A registry"
          "      (import ./cryoforge-denia/pack.nix)\n"
          ""
          (builtins.readFile ./desktop/themes/registry.nix);
      phase19aRegistrySource =
        assert nixpkgs.lib.assertMsg (
          builtins.hashString "sha256" phase19aRegistrySourceText
          == "5cae58665564915b987b2582d6173c616c661b548df81d291af9aebcaf7b92cf"
        ) "Pre-Phase-19B registry projection changed historical content";
        builtins.toFile
          "phase19a-theme-pack-registry.nix"
          phase19aRegistrySourceText;
      phase19aSourceProjection =
        pkgs.runCommand "phase19a-theme-pack-source-projection" { } ''
          mkdir -p "$out"
          cp -R ${r3HistoricalSourceProjection}/. "$out/"
          chmod -R u+w "$out/desktop/themes" "$out/tests"
          rm -rf \
            "$out/desktop/themes/cryoforge-denia" \
            "$out/tests/phase19b"
          rm "$out/desktop/themes/registry.nix"
          install -m 0444 \
            ${phase19aRegistrySource} \
            "$out/desktop/themes/registry.nix"
        '';
      removeExactSnippets = phase: snippets: value:
        nixpkgs.lib.foldl'
          (current: snippet:
            replaceExactly "${phase} package projection" snippet "" current
          )
          value
          snippets;
      cryoforgePackageSource =
        builtins.readFile ./packages/caelestia-cryoforge.nix;
      phase16ePackageSnippets = [
        "  nexusMediaWorkspacePage = ../desktop/caelestia/nexus/MediaWorkspacePage.qml;\n  nexusMediaWorkspacePageSha256 = \"0f9e92d8a59e6504a0ec4588b767f4f312e9e88774aed4c87e3c8520c9214303\";\n  nexusMediaWorkspacePatch = ../desktop/caelestia/cryoforge-nexus-media-workspace.patch;\n  nexusMediaWorkspacePatchSha256 = \"2fb9bd5d7074705c7c9cf9dc20263abe52bc23c362e9885ab0fe5ed799db0cdd\";\n  nexusMediaWorkspaceSourceHashes = {\n    \"modules/nexus/PageRegistry.qml\" = \"d257afbcc7f67b2206892b0fe209b5485ff9db46483d48d8bc5b25a81200c032\";\n    \"modules/nexus/PageCompRegistry.qml\" = \"97e55e31cd177cb63fd3d494343b93bd427a53a82c8e3f87401fcdaf6a469e91\";\n    \"services/Players.qml\" = \"935e8e35f27d314f9222de9abacad43003f362a56a74f6acf616989e46a60d97\";\n    \"components/widgets/CoverArt.qml\" = \"373542849aa3a57f66e626357054453460bea101df34a7b5cafeecb30298e791\";\n  };\n"
        "    assert lib.assertMsg (\n      builtins.hashFile \"sha256\" nexusMediaWorkspacePage == nexusMediaWorkspacePageSha256\n    ) \"CryoForge Nexus Media Workspace page checksum mismatch\";\n    assert lib.assertMsg (\n      builtins.hashFile \"sha256\" nexusMediaWorkspacePatch == nexusMediaWorkspacePatchSha256\n    ) \"CryoForge Nexus Media Workspace patch checksum mismatch\";\n    assert lib.assertMsg (\n      lib.all (\n        path:\n        builtins.hashFile \"sha256\" \"\${caelestia-shell}/\${path}\" == nexusMediaWorkspaceSourceHashes.\${path}\n      ) (builtins.attrNames nexusMediaWorkspaceSourceHashes)\n    ) \"Refusing to apply the Nexus Media Workspace patch to changed upstream QML\";\n"
        "    nexusMediaWorkspacePatch\n"
        "    \${coreutils}/bin/install -m 0444 \\\n      \${nexusMediaWorkspacePage} \\\n      \"\$out/share/caelestia-shell/modules/nexus/pages/MediaWorkspacePage.qml\"\n"
      ];
      phase16dPackageSnippets = [
        "  nexusFocusHubPage = ../desktop/caelestia/nexus/FocusHubPage.qml;\n"
        "  nexusFocusHubPatch = ../desktop/caelestia/cryoforge-nexus-focus-hub.patch;\n"
        "  nexusFocusHubPatchSha256 = \"9084c0012ceff1a635c2fad4443e09b0470e6fc96205bc8a25d13c6ec055b287\";\n"
        "  nexusFocusHubSourceHashes = {\n    \"modules/nexus/PageRegistry.qml\" = \"d257afbcc7f67b2206892b0fe209b5485ff9db46483d48d8bc5b25a81200c032\";\n    \"modules/nexus/PageCompRegistry.qml\" = \"97e55e31cd177cb63fd3d494343b93bd427a53a82c8e3f87401fcdaf6a469e91\";\n  };\n"
        "    assert lib.assertMsg (\n      builtins.hashFile \"sha256\" nexusFocusHubPatch == nexusFocusHubPatchSha256\n    ) \"CryoForge Nexus Focus Hub patch checksum mismatch\";\n"
        "    assert lib.assertMsg (\n      lib.all (\n        path:\n        builtins.hashFile \"sha256\" \"\${caelestia-shell}/\${path}\" == nexusFocusHubSourceHashes.\${path}\n      ) (builtins.attrNames nexusFocusHubSourceHashes)\n    ) \"Refusing to apply the Nexus Focus Hub patch to changed upstream QML\";\n"
        "    nexusFocusHubPatch\n"
        "    \${coreutils}/bin/install -m 0444 \\\n      \${nexusFocusHubPage} \\\n      \"\$out/share/caelestia-shell/modules/nexus/pages/FocusHubPage.qml\"\n"
      ];
      phase16eBaseCryoforgePackageSourceText =
        removeExactSnippets "Phase 16E" phase16ePackageSnippets cryoforgePackageSource;
      phase16eBaseCryoforgePackage =
        assert nixpkgs.lib.assertMsg (
          nixpkgs.lib.hasInfix "nexusFocusHubPatch" phase16eBaseCryoforgePackageSourceText
          && !(nixpkgs.lib.hasInfix "nexusMediaWorkspace" phase16eBaseCryoforgePackageSourceText)
        ) "Pre-Phase-16E package projection removed content outside Phase 16E";
        builtins.toFile "caelestia-cryoforge-phase16e-base.nix"
          phase16eBaseCryoforgePackageSourceText;
      phase16eBaseCryoforgeBuildPackage =
        builtins.toFile "caelestia-cryoforge-phase16e-build.nix" (
          builtins.replaceStrings
            [ "../desktop/" ]
            [ "${./desktop}/" ]
            phase16eBaseCryoforgePackageSourceText
        );
      caelestiaCryoforgePre16e =
        pkgs.callPackage phase16eBaseCryoforgeBuildPackage {
          inherit caelestia-shell;
          caelestiaChisaPool = caelestiaChisaPool;
        };
      phase16dBaseCryoforgePackageSourceText =
        removeExactSnippets
          "Phase 16D"
          phase16dPackageSnippets
          phase16eBaseCryoforgePackageSourceText;
      phase16dBaseCryoforgePackage =
        assert nixpkgs.lib.assertMsg (
          builtins.hashString "sha256" phase16dBaseCryoforgePackageSourceText
          == "eba2358673c4b316464ed80c8aebef271fc7bf00dc421760a58509d1bea4d312"
        ) "Pre-Phase-16D package projection changed historical package content";
        builtins.toFile "caelestia-cryoforge-phase16d-base.nix"
          phase16dBaseCryoforgePackageSourceText;
    in {
    packages.${system} = {
      caelestia-chisa-pool = caelestiaChisaPool;
      caelestia-chisa-pool-previews = caelestiaChisaPoolPreviews;
      caelestia-shell-cryoforge = caelestiaCryoforge;
      caelestia-real-greeter = caelestiaRealGreeter;
      caelestia-real-lock = caelestiaRealLock;
      cryoforge-theme-packs = cryoforgeThemePacks;
      hyprexpo = pkgs.callPackage ./packages/hyprexpo.nix { };
    };

    checks.${system} = {
      inherit caelestiaRealGreeter;

      phase19a-theme-pack-foundation-contract =
        let
          registryModel = themeRegistryModel;
          registry = phase19aThemeRegistry;
          neutral = builtins.head registry.packs;
          curated = neutral // {
            id = "future-pack";
            displayName = "Future Pack";
            kind = "curated";
            wallpaper = "assets/future.png";
            preview = neutral.preview // {
              thumbnail = "assets/future-thumbnail.png";
            };
          };
          validates = candidate:
            (builtins.tryEval (
              builtins.deepSeq (registryModel { registry = candidate; }) true
            )).success;
          invalidRegistries = [
            (registry // {
              packs = [ (neutral // { id = "Neutral"; }) ];
            })
            (registry // { packs = [ neutral neutral ]; })
            (registry // { defaultPackId = "missing"; })
            (registry // { unexpected = true; })
            (registry // {
              packs = [ (neutral // { unexpected = true; }) ];
            })
            (registry // {
              packs = [
                (neutral // {
                  palette = neutral.palette // { unexpected = "#000000"; };
                })
              ];
            })
            (registry // {
              packs = [
                (neutral // {
                  shell = neutral.shell // { unexpected = "surface"; };
                })
              ];
            })
            (registry // {
              packs = [
                (neutral // {
                  preview = neutral.preview // { unexpected = true; };
                })
              ];
            })
            (registry // {
              packs = [
                (neutral // {
                  palette = neutral.palette // { accent = "#ABCDEF"; };
                })
              ];
            })
            (registry // {
              packs = [
                (neutral // {
                  shell = neutral.shell // { panel = "missing"; };
                })
              ];
            })
            (registry // {
              packs = [
                (curated // {
                  wallpaper = "https://example.invalid/future.png";
                })
              ];
            })
            (registry // {
              packs = [ (curated // { wallpaper = "/assets/future.png"; }) ];
            })
            (registry // {
              packs = [
                (curated // { wallpaper = "assets/../future.png"; })
              ];
            })
            (registry // {
              packs = [
                (curated // { wallpaper = "github:example/future"; })
              ];
            })
            (registry // {
              packs = [ (curated // { wallpaper = null; }) ];
            })
            (registry // {
              packs = [
                (curated // {
                  preview = curated.preview // { thumbnail = null; };
                })
              ];
            })
          ];
          expectedRegistry = builtins.toFile
            "phase19a-theme-pack-registry.json"
            (builtins.toJSON registry + "\n");
          expectedPalette = builtins.toFile
            "phase19a-theme-pack-palette.json"
            (builtins.toJSON (import ./desktop/palette.nix) + "\n");
          validatorEvidence =
            assert validates (registry // { packs = [ neutral curated ]; });
            assert builtins.all
              (candidate: !validates candidate)
              invalidRegistries;
            builtins.toFile "phase19a-theme-pack-validator-evidence"
              "valid local curated assets accepted; malformed models rejected\n";
        in
        pkgs.runCommand "phase19a-theme-pack-foundation-contract-tests" {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnugrep
            pkgs.python3
          ];
        } ''
          bash ${./tests/phase19a/test_theme_pack_foundation_contract.sh} \
            ${phase19aSourceProjection} \
            ${phase19aThemePacks} \
            ${expectedRegistry} \
            ${expectedPalette} \
            ${validatorEvidence}
          touch "$out"
        '';

      phase19b-first-curated-theme-contract =
        let
          expectedRegistry = builtins.toFile
            "phase19b-theme-pack-registry.json"
            (builtins.toJSON currentThemeRegistry + "\n");
          phase19aExpectedRegistry = builtins.toFile
            "phase19b-phase19a-theme-pack-registry.json"
            (builtins.toJSON phase19aThemeRegistry + "\n");
          expectedPalette = builtins.toFile
            "phase19b-theme-pack-neutral-palette.json"
            (builtins.toJSON (import ./desktop/palette.nix) + "\n");
          phase19aValidatorEvidence = builtins.toFile
            "phase19b-phase19a-theme-pack-validator-evidence"
            "valid local curated assets accepted; malformed models rejected\n";
        in
        pkgs.runCommand "phase19b-first-curated-theme-contract-tests" {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.python3
          ];
        } ''
          bash ${./tests/phase19b/test_first_curated_theme_contract.sh} \
            ${r3HistoricalSourceProjection} \
            ${./desktop/themes/cryoforge-denia/wallpaper.jpg} \
            ${currentThemePacks} \
            ${expectedRegistry} \
            ${phase19aSourceProjection} \
            ${phase19aThemePacks} \
            ${phase19aExpectedRegistry} \
            ${expectedPalette} \
            ${phase19aValidatorEvidence}
          touch "$out"
        '';

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

      phase16b-cryoforge-window-feel-contract =
        assert
          cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/variables.lua".source
          == realGreeterSystem.config.home-manager.users.accelra.xdg.configFile."hypr/variables.lua".source;
        pkgs.runCommand "phase16b-cryoforge-window-feel-contract-tests" {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.gnused
          ];
        } ''
          bash ${./tests/phase16b/test_window_feel_contract.sh} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/variables.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/general.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/decoration.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/animations.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/rules.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/execs.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/utils/functions.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/keybinds.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/gestures.lua".source} \
            ${stockSystem.config.home-manager.users.accelra.xdg.configFile."hypr/variables.lua".source} \
            ${stockSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/decoration.lua".source} \
            ${stockSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/animations.lua".source} \
            ${stockSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/rules.lua".source} \
            ${stockSystem.config.home-manager.users.accelra.xdg.configFile."hypr/utils/functions.lua".source} \
            ${stockSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/keybinds.lua".source} \
            ${stockSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/gestures.lua".source} \
            ${caelestia-dots} \
            ${./desktop/hypr/hyprland.conf} \
            ${./desktop/profiles.nix} \
            ${r3HistoricalSourceProjection}/flake.nix \
            ${./desktop/caelestia/cryoforge-special-workspaces.patch} \
            ${./desktop/caelestia/cryoforge-region-screenshot.patch} \
            ${./desktop/caelestia/screenshot-region.sh} \
            ${./desktop/caelestia/cryoforge-chisa-preset-gallery.patch} \
            ${phase16dBaseCryoforgePackage}
          touch "$out"
        '';

      phase16c-base-app-integration-contract =
        let
          targetHome = realGreeterSystem.config.home-manager.users.accelra;
          cryoforgeHome = cryoforgeSystem.config.home-manager.users.accelra;
          expectedUserServices = [
            "caelestia"
            "caelestia-clipboard-image"
            "caelestia-clipboard-text"
            "caelestia-mpris-proxy"
            "caelestia-trash-cleanup"
            "hypridle"
            "hyprpaper"
            "mako"
            "nixos-cryoforge-caelestia-fallback"
            "swayosd"
            "waybar"
          ];
          expectedActivations = [
            "checkFilesChanged"
            "checkLinkTargets"
            "dconfSettings"
            "initialiseCaelestiaShellConfig"
            "initialiseChisaPoolTheme"
            "installPackages"
            "linkGeneration"
            "migrateLegacyCaelestiaStockHyprDirectory"
            "onFilesChange"
            "reloadSystemd"
            "writeBoundary"
          ];
        in
        assert targetHome.nixosCryoforge.palette == import ./desktop/palette.nix;
        assert
          targetHome.home.activation.initialiseCaelestiaShellConfig.data
          == cryoforgeHome.home.activation.initialiseCaelestiaShellConfig.data;
        assert !(builtins.hasAttr "kitty/kitty.conf" targetHome.xdg.configFile);
        assert !(builtins.hasAttr "fastfetch/config.jsonc" targetHome.xdg.configFile);
        assert builtins.attrNames targetHome.systemd.user.services == expectedUserServices;
        assert builtins.attrNames targetHome.home.activation == expectedActivations;
        assert realGreeterSystem.config.programs.regreet.enable;
        assert realGreeterSystem.config.programs.regreet.package == recoveryGreeter;
        assert realGreeterSystem.config.services.greetd.settings.default_session.user == "greeter";
        assert realGreeterSystem.config.services.greetd.restart;
        assert realGreeterSystem.config.systemd.services.greetd.restartIfChanged;
        assert !realGreeterSystem.config.systemd.services.greetd.stopIfChanged;
        assert realGreeterSystem.config.security.pam.services ? hyprlock;
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
        pkgs.runCommand "phase16c-base-app-integration-contract-tests" {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.fastfetch
            pkgs.findutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.kitty
            pkgs.python3
          ];
        } ''
          bash ${./tests/phase16c/test_base_app_integration_contract.sh} \
            ${./desktop/palette.nix} \
            ${./desktop/apps/kitty.nix} \
            ${./desktop/apps/fastfetch.nix} \
            ${targetSeedScript} \
            ${stockSeedScript} \
            ${./desktop/profiles.nix} \
            ${r3HistoricalSourceProjection}/flake.nix \
            ${./flake.lock} \
            ${./home.nix} \
            ${./configuration.nix} \
            ${./desktop-hyprland.nix} \
            ${./desktop/caelestia/chisa-pool} \
            ${r3HistoricalSourceProjection}/desktop/caelestia/real-greeter \
            ${./desktop/regreet} \
            ${./desktop/hypr} \
            ${phase16dBaseCryoforgePackage} \
            ${./packages/caelestia-real-greeter.nix} \
            ${./packages/caelestia-real-lock.nix} \
            ${r3HistoricalSourceProjection}/desktop/caelestia/real-greeter-system.nix \
            ${./desktop/caelestia/cryoforge-chisa-preset-gallery.patch} \
            ${./desktop/caelestia/cryoforge-special-workspaces.patch} \
            ${./desktop/caelestia/cryoforge-region-screenshot.patch} \
            ${./desktop/caelestia/screenshot-region.sh} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/variables.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/general.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/decoration.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/animations.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/rules.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/execs.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/utils/functions.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/keybinds.lua".source} \
            ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/gestures.lua".source}
          touch "$out"
        '';

      phase16d-nexus-focus-hub-contract = pkgs.runCommand "phase16d-nexus-focus-hub-contract-tests" {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnugrep
          pkgs.gnused
          pkgs.patch
          pkgs.qt6.qtdeclarative
        ];
      } ''
        bash ${./tests/phase16d/test_nexus_focus_hub_contract.sh} \
          ${caelestiaCryoforgePre16e}/share/caelestia-shell \
          ${caelestia-shell} \
          ${phase16eBaseCryoforgePackage} \
          ${./desktop/caelestia/cryoforge-nexus-focus-hub.patch} \
          ${./desktop/caelestia/nexus/FocusHubPage.qml} \
          ${r3HistoricalSourceProjection}/flake.nix \
          ${./flake.lock} \
          ${r3HistoricalSourceProjection} \
          ${realGreeterSystem.config.system.build.toplevel}
        touch "$out"
      '';

      phase16e-nexus-media-workspace-contract =
        let
          targetName = "nixos-caelestia-cryoforge-real-greeter";
          targetSystem = realGreeterSystem;
        in
        assert targetName == "nixos-caelestia-cryoforge-real-greeter";
        pkgs.runCommand "phase16e-nexus-media-workspace-contract-tests" {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.patch
            pkgs.python3
            pkgs.qt6.qtdeclarative
          ];
        } ''
          bash ${./tests/phase16e/test_nexus_media_workspace_contract.sh} \
            ${targetSystem.config.home-manager.users.accelra.programs.caelestia.package}/share/caelestia-shell \
            ${caelestiaCryoforgePre16e}/share/caelestia-shell \
            ${caelestia-shell} \
            ${./packages/caelestia-cryoforge.nix} \
            ${phase16eBaseCryoforgePackage} \
            ${phase16dBaseCryoforgePackage} \
            ${./desktop/caelestia/cryoforge-nexus-media-workspace.patch} \
            ${./desktop/caelestia/nexus/MediaWorkspacePage.qml} \
            ${./desktop/caelestia/cryoforge-nexus-focus-hub.patch} \
            ${./desktop/caelestia/nexus/FocusHubPage.qml} \
            ${r3HistoricalSourceProjection}/flake.nix \
            ${./flake.lock} \
            ${r3HistoricalSourceProjection} \
            ${targetSystem.config.system.build.toplevel}
          touch "$out"
        '';

      phase17a-screenshot-contract = pkgs.runCommand "phase17a-screenshot-contract-tests" {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnugrep
          pkgs.gnused
        ];
      } ''
        bash ${./tests/phase17a/test_screenshot_contract.sh} \
          ${caelestiaCryoforge}/share/caelestia-shell/modules/areapicker/AreaPicker.qml \
          ${./desktop/caelestia/screenshot-region.sh} \
          ${cryoforgeSystem.config.home-manager.users.accelra.xdg.configFile."hypr/hyprland/keybinds.lua".source} \
          ${cryoforgeSystem.config.home-manager.users.accelra.programs.caelestia.cli.package}
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
        assert realGreeterSystem.config.systemd.services.greetd.serviceConfig.Restart == "always";
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
          grep -Fqx 'Restart=always' ${realGreeterGreetdUnit}/greetd.service
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

    nixosConfigurations.nixos = classicSystem;

    nixosConfigurations.nixos-caelestia-stock = stockSystem;

    nixosConfigurations.nixos-caelestia-cryoforge = cryoforgeSystem;

    nixosConfigurations.nixos-caelestia-cryoforge-real-greeter = realGreeterSystem;
  };
}
