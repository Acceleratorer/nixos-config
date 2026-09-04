{
  id = "cryoforge-pixiv-146159627";
  displayName = "CryoForge Vertin and Sonetto";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-pixiv-146159627" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-pixiv-146159627/wallpaper.jpg";
      sha256 = "6127a9b7c6e79df23f4e3a1e5cd45e58f5a5a59215bffa4b0f1da7be1c872abc";
    };
    thumbnail = {
      path = "assets/cryoforge-pixiv-146159627/preview.jpg";
      sha256 = "f726fab543da56686a29f786765ecb42b7de0472f6e9ed7eb80c7c3cc898df83";
    };
  };
  palette = {
    background = "#121511";
    surface = "#1f261c";
    surfaceElevated = "#383c25";
    foreground = "#efefeb";
    muted = "#b9b79d";
    accent = "#d6cf66";
    accentForeground = "#0a0c12";
    border = "#8a8948";
    focus = "#94da8b";
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
    description = "Dark r1999 composition by Ardannnkuaci; palette derived from the accepted artwork with contrast checks.";
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
