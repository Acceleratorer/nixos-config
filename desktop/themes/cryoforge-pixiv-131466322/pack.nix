{
  id = "cryoforge-pixiv-131466322";
  displayName = "CryoForge 浮生半日闲";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-pixiv-131466322" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-pixiv-131466322/wallpaper.jpg";
      sha256 = "473d626366116da236bbf800a254bf4f0595cf826bdba2cde81b5be42fcdd525";
    };
    thumbnail = {
      path = "assets/cryoforge-pixiv-131466322/preview.jpg";
      sha256 = "bd7e4184ca1a07c2ddc307d83d15c8f449d1fa61d7bbc304af364cc9b74eee09";
    };
  };
  palette = {
    background = "#101216";
    surface = "#1a1e28";
    surfaceElevated = "#25333c";
    foreground = "#ebebef";
    muted = "#9d9db9";
    accent = "#61bddc";
    accentForeground = "#0a0c12";
    border = "#498197";
    focus = "#9784e1";
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
    description = "Dark wuwa composition by Rafa; palette derived from the accepted artwork with contrast checks.";
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
