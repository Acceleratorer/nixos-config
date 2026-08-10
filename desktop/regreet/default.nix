{ config, pkgs, ... }:

let
  cryoforgeFonts = pkgs.google-fonts.override {
    fonts = [
      "Bebas Neue"
      "Tsukimi Rounded"
      "Zen Maru Gothic"
    ];
  };

  cryoforgeRegreet = pkgs.regreet.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ./cryoforge.patch
      ./restart.patch
    ];
    postPatch = ''
      cp ${./src/component.rs} src/gui/component.rs
      cp ${./src/templates.rs} src/gui/templates.rs
    '';
  });
in
{
  systemd.services.greetd.environment.XDG_DATA_DIRS =
    config.environment.sessionVariables.XDG_DATA_DIRS;

  programs.regreet = {
    enable = true;
    package = cryoforgeRegreet;

    settings = {
      background = {
        path = "${./background.png}";
        fit = "Fill";
      };

      appearance = {
        greeting_msg = "SECURE BOOT LOGIN · 認証保護";
        skip_selection = true;
        default_user = "accelra";
        default_session = "Hyprland";
      };

      widget.clock = {
        format = "%H:%M";
        resolution = "1s";
        label_width = 360;
      };
    };

    extraCss = builtins.readFile ./regreet.css;

    theme = {
      package = pkgs.gnome-themes-extra;
      name = "Adwaita";
    };

    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };

    font = {
      package = cryoforgeFonts;
      name = "Zen Maru Gothic";
      size = 14;
    };

    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
    };
  };
}
