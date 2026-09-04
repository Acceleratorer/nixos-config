{
  id = "cryoforge-pixiv-125244568";
  displayName = "CryoForge winter";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-pixiv-125244568" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-pixiv-125244568/wallpaper.jpg";
      sha256 = "be45bebb160ed28e7775cb7641bc727a853f54550d2d7ccd5e220c8ca140da83";
    };
    thumbnail = {
      path = "assets/cryoforge-pixiv-125244568/preview.jpg";
      sha256 = "985d7150beaf0bebbca6a78b8da1fd0313e7432069af3f04df7309925f941f6f";
    };
  };
  palette = {
    background = "#131016";
    surface = "#221b27";
    surfaceElevated = "#34253c";
    foreground = "#efebeb";
    muted = "#b99d9d";
    accent = "#d66666";
    accentForeground = "#0a0c12";
    border = "#aa5f6f";
    focus = "#d9d98c";
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
    description = "Dark genshin composition by Datsha; palette derived from the accepted artwork with contrast checks.";
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
