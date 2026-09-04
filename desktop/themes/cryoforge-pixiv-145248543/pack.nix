{
  id = "cryoforge-pixiv-145248543";
  displayName = "CryoForge ダーニャ";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-pixiv-145248543" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-pixiv-145248543/wallpaper.jpg";
      sha256 = "8fe7d2f34cc8e01a7500cf46e35543273b63b11c5af401cc962f4ab7674f4f85";
    };
    thumbnail = {
      path = "assets/cryoforge-pixiv-145248543/preview.jpg";
      sha256 = "230dfeda4dbf7ad2d855700cd5e646ab961d3fe7672d6fcb9037b0ac5d6ce66c";
    };
  };
  palette = {
    background = "#0d0d19";
    surface = "#16162c";
    surfaceElevated = "#29253c";
    foreground = "#efebed";
    muted = "#b99da8";
    accent = "#d66695";
    accentForeground = "#0a0c12";
    border = "#a15987";
    focus = "#d9b98c";
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
    description = "Dark wuwa composition by sonchi; palette derived from the accepted artwork with contrast checks.";
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
