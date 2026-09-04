{
  id = "cryoforge-pixiv-131599235";
  displayName = "CryoForge カルテジア";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-pixiv-131599235" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-pixiv-131599235/wallpaper.jpg";
      sha256 = "38bfd8afa47dcc21b456647afaea7ada9e6e19098fd24c8de0dff0bf68da6653";
    };
    thumbnail = {
      path = "assets/cryoforge-pixiv-131599235/preview.jpg";
      sha256 = "8b9e95a6d48ef01670cf3ea85331fb4fd479cdc185f3b23ac07032400550b7f2";
    };
  };
  palette = {
    background = "#0e1318";
    surface = "#17212c";
    surfaceElevated = "#25323c";
    foreground = "#efeeeb";
    muted = "#b9ae9d";
    accent = "#d6aa66";
    accentForeground = "#0a0c12";
    border = "#897a5d";
    focus = "#aed98c";
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
    description = "Dark wuwa composition by 卜卜; palette derived from the accepted artwork with contrast checks.";
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
