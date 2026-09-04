{
  id = "cryoforge-local-hnny-vtwuaark-l";
  displayName = "CryoForge HNNY local reference";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-local-hnny-vtwuaark-l" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-local-hnny-vtwuaark-l/wallpaper.jpg";
      sha256 = "6f88acd972cad942fed224a5c990a33fc83c02cdadafa14a51e3fc6c2e6bfd71";
    };
    thumbnail = {
      path = "assets/cryoforge-local-hnny-vtwuaark-l/preview.jpg";
      sha256 = "d4878f58c36f494332ededfcc5f604f1b07742768bb3d5acf5d5b1fc30702145";
    };
  };
  palette = {
    background = "#18110f";
    surface = "#2a1d18";
    surfaceElevated = "#3c2b25";
    foreground = "#efedeb";
    muted = "#b9a79d";
    accent = "#d98863";
    accentForeground = "#0a0c12";
    border = "#a46a51";
    focus = "#c8df86";
    success = "#73d39f";
    warning = "#eac886";
    error = "#e46776";
  };
  scheme = {
    mode = "adapted";
    acceptedSourceSha256 = null;
    colours = null;
  };
  presentation = {
    shell = {
      panel = "surface";
      card = "surfaceElevated";
      text = "foreground";
      subduedText = "muted";
      accent = "accent";
      outline = "border";
      focus = "focus";
    };
    lock = {
      palette = "session";
      wallpaper = "session";
    };
    normalGreeter = {
      palette = "pack";
      wallpaper = "canonical";
    };
  };
  preview = {
    description = "Dark wuwa composition by unattributed; palette derived from the accepted artwork with contrast checks.";
    swatches = [
      "background"
      "surfaceElevated"
      "accent"
      "focus"
      "foreground"
    ];
  };
  fallback = {
    missingPublicState = false;
    invalidPublicState = false;
    recovery = false;
  };
}
