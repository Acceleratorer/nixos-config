{
  id = "cryoforge-pixiv-129183437";
  displayName = "CryoForge :D";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-pixiv-129183437" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-pixiv-129183437/wallpaper.jpg";
      sha256 = "58c2568d39022fa5c1281e4958b46f2c48e6ea92e6ec42a1a0637450bdcbfb8e";
    };
    thumbnail = {
      path = "assets/cryoforge-pixiv-129183437/preview.jpg";
      sha256 = "8028f0c0ab75f57e671a44c18635478176507031f0d94551d6a5168b9003ba45";
    };
  };
  palette = {
    background = "#0f0f17";
    surface = "#191929";
    surfaceElevated = "#25253c";
    foreground = "#efebef";
    muted = "#b99db9";
    accent = "#d666d6";
    accentForeground = "#0a0c12";
    border = "#9956a9";
    focus = "#d98c8c";
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
    description = "Dark hsr composition by SWKL:D; palette derived from the accepted artwork with contrast checks.";
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
