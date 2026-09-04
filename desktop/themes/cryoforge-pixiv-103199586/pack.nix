{
  id = "cryoforge-pixiv-103199586";
  displayName = "CryoForge Sonetto";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-pixiv-103199586" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-pixiv-103199586/wallpaper.jpg";
      sha256 = "851cdee08bb32d7cb17410e88913433372e614c3a753dd1b62cdf92028432be5";
    };
    thumbnail = {
      path = "assets/cryoforge-pixiv-103199586/preview.jpg";
      sha256 = "19ab6dd8ae19486d625482cb3a865f1ddd9e0efb5e2c20dfafd3043997478b59";
    };
  };
  palette = {
    background = "#17110f";
    surface = "#2a1c19";
    surfaceElevated = "#3c2b25";
    foreground = "#efeceb";
    muted = "#b9a59d";
    accent = "#d68866";
    accentForeground = "#0a0c12";
    border = "#a26b53";
    focus = "#c5d98c";
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
    description = "Dark r1999 composition by Rs; palette derived from the accepted artwork with contrast checks.";
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
