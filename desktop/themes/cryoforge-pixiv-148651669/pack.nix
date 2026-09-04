{
  id = "cryoforge-pixiv-148651669";
  displayName = "CryoForge 清宵";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-pixiv-148651669" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-pixiv-148651669/wallpaper.jpg";
      sha256 = "40afcae1b8c97e65e2ad33152f84769034b47632491b92e5d670ca35dc596ed6";
    };
    thumbnail = {
      path = "assets/cryoforge-pixiv-148651669/preview.jpg";
      sha256 = "9b300179ced540687e3010773493717e388d85eb842786cb7a462a92343da590";
    };
  };
  palette = {
    background = "#101612";
    surface = "#1b281e";
    surfaceElevated = "#253c3b";
    foreground = "#ebefef";
    muted = "#9db6b9";
    accent = "#66aad6";
    accentForeground = "#0a0c12";
    border = "#538aa2";
    focus = "#a688dd";
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
