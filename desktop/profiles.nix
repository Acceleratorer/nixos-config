{
  caelestia-dots,
  caelestia-shell,
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixosCryoforge;
  system = pkgs.stdenv.hostPlatform.system;
  chisaPoolAssets = pkgs.callPackage ../packages/caelestia-chisa-pool.nix { };

  hyprlandTarget = "hyprland-session.target";
  classicTarget = "nixos-cryoforge-classic.target";
  caelestiaTarget = "nixos-cryoforge-caelestia.target";
  stockTarget = "nixos-cryoforge-caelestia-stock.target";
  cryoforgeTarget = "nixos-cryoforge-caelestia-cryoforge.target";
  fallbackService = "nixos-cryoforge-caelestia-fallback.service";
  notificationBus = "org.freedesktop.Notifications";
  isStock = cfg.desktopProfile == "caelestia-stock";
  isCryoforge = cfg.desktopProfile == "caelestia-cryoforge";
  isCaelestiaDerived = isStock || isCryoforge;
  caelestiaDerivedLabel =
    if isCryoforge then "Caelestia CryoForge" else "Caelestia Stock";
  caelestiaSystemTarget =
    if isStock then stockTarget
    else if isCryoforge then cryoforgeTarget
    else caelestiaTarget;

  classicServiceUnits = [
    "waybar.service"
    "mako.service"
    "hyprpaper.service"
    "hypridle.service"
    "swayosd.service"
  ];

  upstreamCaelestiaPackage =
    caelestia-shell.packages.${system}.with-cli;
  stockCaelestiaPackage = upstreamCaelestiaPackage.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      ${pkgs.coreutils}/bin/install -m 0444 \
        ${caelestia-shell}/shell.qml \
        "$out/share/caelestia-shell/shell.qml"
    '';
  });
  cryoforgeCaelestiaPackage = pkgs.callPackage ../packages/caelestia-cryoforge.nix {
    inherit caelestia-shell;
    caelestiaChisaPool = chisaPoolAssets;
  };
  caelestiaPackage =
    if isCryoforge then cryoforgeCaelestiaPackage else stockCaelestiaPackage;
  caelestiaCli = config.programs.caelestia.cli.package;
  caelestiaShellConfig = ./caelestia/shell.json;
  upstreamSchemeDefault = "${caelestia-dots}/hypr/scheme/default.lua";

  stockShellConfig = pkgs.writeText "caelestia-stock-shell.json" "{}\n";
  stockShellTokens = pkgs.writeText "caelestia-stock-shell-tokens.json" "{}\n";
  stockCliConfig = pkgs.writeText "caelestia-stock-cli.json" (builtins.toJSON {
    theme = {
      enableTerm = false;
      enableHypr = true;
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
  });
  stockHyprVars = pkgs.writeText "caelestia-stock-hypr-vars.lua" "return {}\n";
  stockHyprUser = pkgs.writeText "caelestia-stock-hypr-user.lua" "";

  guardedReadFile = name: expectedHash: path:
    let
      contents = builtins.readFile path;
    in
    assert lib.assertMsg (builtins.hashString "sha256" contents == expectedHash)
      "Refusing to transform changed upstream ${name}";
    contents;

  replaceExactly = name: before: after: contents:
    assert lib.assertMsg (builtins.length (lib.splitString before contents) == 2)
      "Expected exactly one upstream ${name} transformation target";
    lib.replaceStrings [ before ] [ after ] contents;

  hyprlandSessionReady = pkgs.writeShellScript "caelestia-stock-hyprland-session-ready" ''
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

  prepareCaelestiaHyprlandSession = pkgs.writeShellApplication {
    name = "prepare-caelestia-hyprland-session";
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

      systemctl --user stop ${hyprlandTarget}

      dbus-update-activation-environment --systemd \
        DISPLAY \
        WAYLAND_DISPLAY \
        XDG_CURRENT_DESKTOP \
        HYPRLAND_INSTANCE_SIGNATURE

      systemctl --user reset-failed ${hyprlandTarget} || true
      systemctl --user start ${hyprlandTarget}
    '';
  };

  pristineHyprlandLua = guardedReadFile
    "hyprland.lua"
    "c7be93202375f7c6453f2b46890522370d20a780e2dce625e4b8e40d05f50c14"
    "${caelestia-dots}/hypr/hyprland.lua";
  hyprlandSeedBlock = ''
    -- Create a file if it doesn't exist, optionally with initial content
    local function maybe_create(file, content)
        local f = io.open(file)

        if f then
            f:close()
            return
        end

        f = io.open(file, "w")
        if f then
            if content then f:write(content) end
            f:close()
        end
    end

    -- Copy src to dst, but only if dst doesn't already exist
    local function maybe_copy(src, dst)
        local out = io.open(dst)
        if out then
            out:close()
            return
        end

        local input = io.open(src, "r")
        if not input then return end

        out = io.open(dst, "w")
        if out then
            out:write(input:read("*a"))
            out:close()
        end
        input:close()
    end

    -- Maybe set current colours to defaults
    maybe_copy(hypr .. "/scheme/default.lua", hypr .. "/scheme/current.lua")

  '';
  hyprVarsSeedLine =
    ''maybe_create(home .. "/.config/caelestia/hypr-vars.lua", "return {}\n")'';
  hyprUserSeedLine =
    ''maybe_create(home .. "/.config/caelestia/hypr-user.lua")'';
  hyprlandPackagePathLine =
    ''package.path = package.path .. ";" .. home .. "/.config/caelestia/?.lua"'';
  nixHyprlandPackagePath = ''
    package.path = package.path
        .. ";" .. hypr .. "/?.lua"
        .. ";" .. hypr .. "/?/init.lua"
        .. ";" .. home .. "/.config/caelestia/?.lua"'';
  adaptedHyprlandLua =
    assert builtins.length (lib.splitString hyprlandSeedBlock pristineHyprlandLua) == 2;
    assert builtins.length (lib.splitString hyprVarsSeedLine pristineHyprlandLua) == 2;
    assert builtins.length (lib.splitString hyprUserSeedLine pristineHyprlandLua) == 2;
    assert builtins.length (lib.splitString hyprlandPackagePathLine pristineHyprlandLua) == 2;
    pkgs.writeText "caelestia-stock-hyprland.lua"
      (lib.replaceStrings
        [
          hyprlandSeedBlock
          hyprVarsSeedLine
          hyprUserSeedLine
          hyprlandPackagePathLine
        ]
        [
          ""
          ""
          ""
          nixHyprlandPackagePath
        ]
        pristineHyprlandLua);

  pristineExecsLua = guardedReadFile
    "execs.lua"
    "68e0e091d522ba40093896ac27f53c24c8303d21026632b19b23dbbcf4c70e79"
    "${caelestia-dots}/hypr/hyprland/execs.lua";
  execsStartupBlock = ''
    hl.on("hyprland.start", function()
        -- Keyring and auth
        hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
        hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

        -- Clipboard history
        hl.exec_cmd("wl-paste --type text --watch cliphist store")
        hl.exec_cmd("wl-paste --type image --watch cliphist store")

        -- Auto delete trash 30 days old
        hl.exec_cmd("trash-empty 30")

        -- Cursors
        hl.exec_cmd("hyprctl setcursor " .. vars.cursorTheme .. " " .. vars.cursorSize)
        hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme " .. vars.cursorTheme)
        hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size " .. vars.cursorSize)

        -- Location provider and night light
        hl.exec_cmd("/usr/lib/geoclue-2.0/demos/agent")
        hl.exec_cmd("sleep 1 && gammastep")

        -- Forward bluetooth media commands to MPRIS
        hl.exec_cmd("mpris-proxy")

        -- Start shell
        hl.exec_cmd("caelestia shell -d")
    end)
  '';
  adaptedExecsLua = assert builtins.length (lib.splitString execsStartupBlock pristineExecsLua) == 2;
    pkgs.writeText "caelestia-stock-execs.lua" (lib.replaceStrings
      [ execsStartupBlock ]
      [ ''
        hl.on("hyprland.start", function()
            -- NixOS owns session startup and the shared authentication infrastructure.
            hl.exec_cmd("${prepareCaelestiaHyprlandSession}/bin/prepare-caelestia-hyprland-session")

            -- Cursors
            hl.exec_cmd("${pkgs.hyprland}/bin/hyprctl setcursor " .. vars.cursorTheme .. " " .. vars.cursorSize)
            hl.exec_cmd("${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface cursor-theme " .. vars.cursorTheme)
            hl.exec_cmd("${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface cursor-size " .. vars.cursorSize)
        end)

        hl.on("hyprland.shutdown", function()
            hl.exec_cmd("${pkgs.systemd}/bin/systemctl --user stop ${hyprlandTarget}")
        end)
      '' ]
      pristineExecsLua);

  pristineVariablesLua = guardedReadFile
    "variables.lua"
    "34007a1a642e122edf9fb5f721c5c2ea21684c3dacaf39ea8ae0d96e1725a010"
    "${caelestia-dots}/hypr/variables.lua";
  cryoforgeVariablesLua = pkgs.writeText "caelestia-cryoforge-variables.lua"
    (lib.pipe pristineVariablesLua [
      (replaceExactly "variables.lua terminal default"
        ''    terminal                   = "foot",''
        ''    terminal                   = "kitty",'')
      (replaceExactly "variables.lua workspace swipe fingers"
        ''    workspaceSwipeFingers      = 4,''
        ''    workspaceSwipeFingers      = 3,'')
    ]);

  pristineRulesLua = guardedReadFile
    "rules.lua"
    "61beafb70cc86825b77b6735325efb8daf804d6425296264cae34b0a987a1390"
    "${caelestia-dots}/hypr/hyprland/rules.lua";
  rulesSpecialTagNames = ''
    local system_monitor_tag = "system_monitor"
    local music_player_tag = "music_player"
    local communication_app_tag = "communication_app"
    local todo_app_tag = "todo_app"
  '';
  rulesSpecialRouting = ''
    -- Special workspaces
    tagged_rule(system_monitor_tag, { "btop" }, "class")
    tagged_rule(music_player_tag, {
        "feishin|Supersonic|Plexamp",                                  -- Self hosted
        "Spotify",                                                     -- Spotify
        "Cider",                                                       -- Apple music
        "com.github.th-ch.youtube-music|com-maxrave-simpmusic-MainKt", -- YouTube music
    }, "class")
    tagged_rule(music_player_tag, {
        "Spotify|Spotify Free" -- Spotify wayland, it has no class for some reason
    }, "initial_title")
    tagged_rule(communication_app_tag, {
        "discord|equibop|vesktop", -- Discord clients
        "whatsapp"                 -- Whatsapp
    }, "class")
    tagged_rule(todo_app_tag, {
        "todoist" -- Todoist
    }, "class")


  '';
  rulesSpecialTagDefinitions = ''
    create_tag(system_monitor_tag, { workspace = "special:sysmon" })
    create_tag(music_player_tag, { workspace = "special:music" })
    create_tag(communication_app_tag, { workspace = "special:communication" })
    create_tag(todo_app_tag, { workspace = "special:todo" })
  '';
  cryoforgeRulesLua = pkgs.writeText "caelestia-cryoforge-rules.lua"
    (lib.pipe pristineRulesLua [
      (replaceExactly "rules.lua special-workspace tag names" rulesSpecialTagNames "")
      (replaceExactly "rules.lua special-workspace routing" rulesSpecialRouting "")
      (replaceExactly "rules.lua special-workspace tag definitions" rulesSpecialTagDefinitions "")
    ]);

  pristineGesturesLua = guardedReadFile
    "gestures.lua"
    "c62c60854456d84529fcceb5ac9e687f0368993b84926133e144233a42a1783a"
    "${caelestia-dots}/hypr/hyprland/gestures.lua";
  gesturesSpecialActions = ''
    hl.gesture({ fingers = vars.gestureFingers, direction = "up", action = "special", workspace_name = "special" })
    hl.gesture({
        fingers   = vars.gestureFingers,
        direction = "down",
        action    = fn.toggle("specialws"),
    })
  '';
  cryoforgeGesturesLua = pkgs.writeText "caelestia-cryoforge-gestures.lua"
    (lib.pipe pristineGesturesLua [
      (replaceExactly "gestures.lua unused special-workspace helper import"
        "local fn   = require(\"utils.functions\")\n"
        "")
      (replaceExactly "gestures.lua special-workspace actions" gesturesSpecialActions "")
    ]);

  pristineKeybindsLua = guardedReadFile
    "keybinds.lua"
    "dc0f374bc650fe81c2ea086449ac73fd8312f3490418d40c4432591d9d74a938"
    "${caelestia-dots}/hypr/hyprland/keybinds.lua";
  keybindsMoveSpecial = ''
    -- Move window to/from special workspace
    create_bind(vars.kbMoveWinToWsSpecial, hl.dsp.window.move({ workspace = "special:special" }))
    create_bind(vars.kbMoveWinFromWsSpecial, hl.dsp.window.move({ workspace = "e+0" }))

  '';
  keybindsToggleSpecial = ''
    -- Special workspace toggles
    create_bind(vars.kbSpecialWs, fn.toggle("specialws"))
    create_bind(vars.kbSystemMonitorWs, fn.toggle("sysmon"))
    create_bind(vars.kbMusicWs, fn.toggle("music"))
    create_bind(vars.kbCommunicationWs, fn.toggle("communication"))
    create_bind(vars.kbTodoWs, fn.toggle("todo"))

  '';
  cryoforgeKeybindsLua = pkgs.writeText "caelestia-cryoforge-keybinds.lua"
    (lib.pipe pristineKeybindsLua [
      (replaceExactly "keybinds.lua move-window special-workspace binds" keybindsMoveSpecial "")
      (replaceExactly "keybinds.lua special-workspace toggles" keybindsToggleSpecial "")
      (replaceExactly "keybinds.lua Print screenshot bind"
        ''create_bind(vars.kbScreenshot, hl.dsp.exec_cmd("caelestia screenshot"), locked)''
        ''create_bind(vars.kbScreenshot, hl.dsp.global("caelestia:screenshot"), locked)'')
    ]);

  upstreamHyprlandFiles = [
    "hyprland/animations.lua"
    "hyprland/decoration.lua"
    "hyprland/env.lua"
    "hyprland/general.lua"
    "hyprland/gestures.lua"
    "hyprland/group.lua"
    "hyprland/input.lua"
    "hyprland/keybinds.lua"
    "hyprland/misc.lua"
    "hyprland/rules.lua"
    "scheme/default.lua"
    "utils/functions.lua"
    "utils/json.lua"
    "variables.lua"
  ];
  stockHyprlandConfigFiles =
    [
      {
        name = "hypr/hyprland.lua";
        source = adaptedHyprlandLua;
      }
      {
        name = "hypr/hyprland/execs.lua";
        source = adaptedExecsLua;
      }
    ]
    ++ map (relativePath: {
      name = "hypr/${relativePath}";
      source = "${caelestia-dots}/hypr/${relativePath}";
    }) upstreamHyprlandFiles;
  cryoforgeHyprlandOverrides = {
    "hypr/hyprland/gestures.lua" = cryoforgeGesturesLua;
    "hypr/hyprland/keybinds.lua" = cryoforgeKeybindsLua;
    "hypr/hyprland/rules.lua" = cryoforgeRulesLua;
    "hypr/variables.lua" = cryoforgeVariablesLua;
  };
  cryoforgeHyprlandConfigFiles = map (entry:
    entry // lib.optionalAttrs (lib.hasAttr entry.name cryoforgeHyprlandOverrides) {
      source = lib.getAttr entry.name cryoforgeHyprlandOverrides;
    }
  ) stockHyprlandConfigFiles;
  profileHyprlandConfigFiles =
    if isCryoforge
    then cryoforgeHyprlandConfigFiles
    else stockHyprlandConfigFiles;

  checkLegacyCaelestiaStockHyprDirectory = pkgs.writeShellScript
    "check-legacy-caelestia-stock-hypr-directory" ''
    set -eu

    hypr_dir="$HOME/.config/hypr"

    if [[ ! -e "$hypr_dir" && ! -L "$hypr_dir" ]]; then
      exit 0
    fi

    if [[ -d "$hypr_dir" && ! -L "$hypr_dir" ]]; then
      exit 0
    fi

    if [[ ! -L "$hypr_dir" ]]; then
      echo "Refusing Caelestia Stock migration: $hypr_dir is not a directory or symlink" >&2
      exit 1
    fi

    old_generation="''${1:-}"
    old_home_files=""
    if [[ -n "$old_generation" && -d "$old_generation/home-files" ]]; then
      old_home_files="$(readlink -e "$old_generation/home-files")"
    fi

    old_hypr="$old_home_files/.config/hypr"
    if [[ -z "$old_home_files" || ! -L "$old_hypr" ]]; then
      echo "Refusing Caelestia Stock migration: no previous Home Manager symlink declaration for $hypr_dir" >&2
      exit 1
    fi

    current_target="$(readlink "$hypr_dir")"
    old_target="$(readlink "$old_hypr")"

    case "$current_target" in
      ${builtins.storeDir}/*) ;;
      *)
        echo "Refusing Caelestia Stock migration: $hypr_dir targets non-store path $current_target" >&2
        exit 1
        ;;
    esac

    case "$old_target" in
      ${builtins.storeDir}/*) ;;
      *)
        echo "Refusing Caelestia Stock migration: previous declaration targets non-store path $old_target" >&2
        exit 1
        ;;
    esac

    if [[ "$current_target" != "$old_hypr" ]]; then
      echo "Refusing Caelestia Stock migration: $hypr_dir target does not match the previous declaration" >&2
      echo "  current: $current_target" >&2
      echo "  previous: $old_hypr" >&2
      exit 1
    fi

    if ! current_resolved="$(readlink -e "$hypr_dir")" || [[ ! -d "$current_resolved" ]]; then
      echo "Refusing Caelestia Stock migration: $hypr_dir has a dangling or non-directory store target" >&2
      exit 1
    fi

    if ! old_resolved="$(readlink -e "$old_hypr")" || [[ "$current_resolved" != "$old_resolved" ]]; then
      echo "Refusing Caelestia Stock migration: $hypr_dir does not match the previous immutable directory" >&2
      exit 1
    fi

    # Emit only the already-validated symlink. The caller removes this path,
    # never its immutable target.
    printf '%s\n' "$hypr_dir"
  '';

  seedCaelestiaStockState = pkgs.writeShellScript "seed-caelestia-stock-state" ''
    set -eu

    config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
    state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
    cache_home="''${XDG_CACHE_HOME:-$HOME/.cache}"

    ensure_directory() {
      if [ -L "$1" ]; then
        return 1
      fi
      if [ -e "$1" ]; then
        [ -d "$1" ]
      else
        ${pkgs.coreutils}/bin/install -d -m 0700 "$1"
      fi
    }

    seed_file() {
      if [ ! -e "$2" ] && [ ! -L "$2" ]; then
        ${pkgs.coreutils}/bin/install -m 0600 "$1" "$2"
      fi
    }

    caelestia_dir="$config_home/caelestia"
    if ensure_directory "$caelestia_dir"; then
      ensure_directory "$caelestia_dir/monitors" || true
      ensure_directory "$caelestia_dir/templates" || true
      seed_file ${stockShellConfig} "$caelestia_dir/shell.json"
      seed_file ${stockShellTokens} "$caelestia_dir/shell-tokens.json"
      seed_file ${stockCliConfig} "$caelestia_dir/cli.json"
      seed_file ${stockHyprVars} "$caelestia_dir/hypr-vars.lua"
      seed_file ${stockHyprUser} "$caelestia_dir/hypr-user.lua"
    fi

    hypr_dir="$config_home/hypr"
    if ensure_directory "$hypr_dir" && ensure_directory "$hypr_dir/scheme"; then
      seed_file ${upstreamSchemeDefault} "$hypr_dir/scheme/current.lua"
    fi

    ensure_directory "$state_home/caelestia" || true
    ensure_directory "$cache_home/caelestia" || true
  '';

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

  initialiseChisaPoolState = pkgs.writeShellScript "initialise-chisa-pool-state" ''
    set -eu

    state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
    state_dir="$state_home/caelestia"
    wallpaper_dir="$state_dir/wallpaper"

    ${pkgs.coreutils}/bin/install -d -m 0700 "$state_dir" "$wallpaper_dir"
    ${pkgs.coreutils}/bin/install -m 0600 \
      ${chisaPoolAssets}/share/caelestia-chisa-pool/avatar/IMG_5542.jpg \
      "$HOME/.face"
    ${pkgs.coreutils}/bin/printf '%s' \
      '${chisaPoolAssets}/share/caelestia-chisa-pool/background/chisa-pool-direct.jpg' \
      > "$wallpaper_dir/path.txt"
    ${pkgs.coreutils}/bin/chmod 0600 "$wallpaper_dir/path.txt"
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

  mkStockService =
    { description, execStart, execStartPre ? null, after ? [ ] }:
    {
      Unit = {
        Description = description;
        After = [ hyprlandTarget ] ++ after;
        PartOf = [ caelestiaSystemTarget ];
        Conflicts = [ classicTarget caelestiaTarget ]
          ++ lib.optional isStock cryoforgeTarget
          ++ lib.optional isCryoforge stockTarget
          ++ classicServiceUnits;
        ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
      };

      Service = {
        Type = "exec";
        ExecStart = execStart;
        Restart = "on-failure";
        RestartSec = "3s";
        TimeoutStopSec = "5s";
        Slice = "session.slice";
      } // lib.optionalAttrs (execStartPre != null) {
        ExecStartPre = execStartPre;
      };

      Install.WantedBy = [ caelestiaSystemTarget ];
    };
in
{
  options.nixosCryoforge = {
    desktopProfile = lib.mkOption {
      type = lib.types.enum [
        "classic"
        "caelestia"
        "caelestia-stock"
        "caelestia-cryoforge"
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
    home.activation = {
      initialiseCaelestiaShellConfig = lib.hm.dag.entryAfter [ "linkGeneration" ]
        (if isCaelestiaDerived then ''
          run ${seedCaelestiaStockState}
        '' else ''
          config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
          config_dir="$config_home/caelestia"
          shell_config="$config_dir/shell.json"

          if [[ ! -e "$shell_config" && ! -L "$shell_config" ]]; then
            run ${pkgs.coreutils}/bin/install -d -m 0700 "$config_dir"
            run ${pkgs.coreutils}/bin/install -m 0600 \
              ${caelestiaShellConfig} "$shell_config"
          fi
        '');

      initialiseChisaPoolTheme = lib.mkIf isCryoforge
        (lib.hm.dag.entryAfter [ "initialiseCaelestiaShellConfig" ] ''
          run ${initialiseChisaPoolState}
        '');

      migrateLegacyCaelestiaStockHyprDirectory = lib.mkIf isCaelestiaDerived
        (lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
          legacy_hypr_dir="$(${checkLegacyCaelestiaStockHyprDirectory} "''${oldGenPath:-}")"
          if [[ -n "$legacy_hypr_dir" ]]; then
            run ${pkgs.coreutils}/bin/rm -- "$legacy_hypr_dir"
          fi
        '');
    };

    programs.caelestia = {
      enable = true;
      package = caelestiaPackage;

      systemd = {
        enable = true;
        target = caelestiaSystemTarget;
        environment = [
          "QS_APP_ID=org.caelestia.shell"
          "QS_ICON_THEME=Papirus"
        ];
      };

      cli = {
        enable = true;
        settings =
          if isCaelestiaDerived
          then { }
          else {
            theme = {
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
    } // lib.listToAttrs (lib.optionals isCaelestiaDerived (map (entry: {
      name = entry.name;
      value.source = entry.source;
    }) profileHyprlandConfigFiles));

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
          Conflicts = [ caelestiaTarget stockTarget cryoforgeTarget ];
          PartOf = [ hyprlandTarget ];
          After = [ hyprlandTarget ] ++ classicServiceUnits;
        };
        Install.WantedBy =
          lib.optional (cfg.desktopProfile == "classic") hyprlandTarget;
      };

      nixos-cryoforge-caelestia = {
        Unit = {
          Description = "NixOS CryoForge Caelestia desktop profile";
          Conflicts = [ classicTarget stockTarget cryoforgeTarget ];
          PartOf = [ hyprlandTarget ];
          After = [
            hyprlandTarget
            "caelestia.service"
          ];
        };
        Install.WantedBy =
          lib.optional (cfg.desktopProfile == "caelestia") hyprlandTarget;
      };

      nixos-cryoforge-caelestia-stock = {
        Unit = {
          Description = "NixOS CryoForge Caelestia stock desktop profile";
          Conflicts = [ classicTarget caelestiaTarget cryoforgeTarget ] ++ classicServiceUnits;
          PartOf = [ hyprlandTarget ];
          After = [
            hyprlandTarget
            "caelestia.service"
          ];
        };
        Install.WantedBy =
          lib.optional (cfg.desktopProfile == "caelestia-stock") hyprlandTarget;
      };

      nixos-cryoforge-caelestia-cryoforge = {
        Unit = {
          Description = "NixOS CryoForge Caelestia CryoForge profile";
          Conflicts = [ classicTarget caelestiaTarget stockTarget ] ++ classicServiceUnits;
          PartOf = [ hyprlandTarget ];
          After = [
            hyprlandTarget
            "caelestia.service"
          ];
        };
        Install.WantedBy =
          lib.optional (cfg.desktopProfile == "caelestia-cryoforge") hyprlandTarget;
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
        } // lib.optionalAttrs (!isCaelestiaDerived) {
          OnFailure = [ fallbackService ];
        };

        Service = {
          Type = lib.mkForce "dbus";
          BusName = notificationBus;
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
        } // lib.optionalAttrs (!isCaelestiaDerived) {
          ExecStartPre = initialiseCaelestiaState;
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
    } // lib.optionalAttrs isCaelestiaDerived {
      caelestia-clipboard-text = mkStockService {
        description = "${caelestiaDerivedLabel} text clipboard history watcher";
        execStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
      };

      caelestia-clipboard-image = mkStockService {
        description = "${caelestiaDerivedLabel} image clipboard history watcher";
        execStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
      };

      caelestia-trash-cleanup = {
        Unit = {
          Description = "${caelestiaDerivedLabel} trash cleanup";
          After = [ hyprlandTarget ];
          PartOf = [ caelestiaSystemTarget ];
          Conflicts = [ classicTarget caelestiaTarget ]
            ++ lib.optional isStock cryoforgeTarget
            ++ lib.optional isCryoforge stockTarget;
          ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.trash-cli}/bin/trash-empty 30";
          RemainAfterExit = true;
        };

        Install.WantedBy = [ caelestiaSystemTarget ];
      };

      caelestia-geoclue-agent = mkStockService {
        description = "${caelestiaDerivedLabel} GeoClue demo agent";
        execStart = "${pkgs.geoclue2-with-demo-agent}/libexec/geoclue-2.0/demos/agent";
      };

      caelestia-gammastep = mkStockService {
        description = "${caelestiaDerivedLabel} Gammastep night light";
        after = [ "caelestia-geoclue-agent.service" ];
        execStartPre = "${pkgs.coreutils}/bin/sleep 1";
        execStart = "${pkgs.gammastep}/bin/gammastep";
      };

      caelestia-mpris-proxy = mkStockService {
        description = "${caelestiaDerivedLabel} Bluetooth MPRIS proxy";
        execStart = "${pkgs.bluez}/bin/mpris-proxy";
      };
    };
  };
}
