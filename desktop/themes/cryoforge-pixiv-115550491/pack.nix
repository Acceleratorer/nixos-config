{
  id = "cryoforge-pixiv-115550491";
  displayName = "CryoForge Voyager";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-pixiv-115550491" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-pixiv-115550491/wallpaper.jpg";
      sha256 = "f89615bc718e21c22c42a24b706f3472a2a72d2192a6900cf6de077aa6d46bd1";
    };
    thumbnail = {
      path = "assets/cryoforge-pixiv-115550491/preview.jpg";
      sha256 = "2b7dfa2d31253d954087545f10bc484e17d00353cb310efdf486d2598fa31277";
    };
  };
  palette = {
    background = "#0f1017";
    surface = "#181b2a";
    surfaceElevated = "#25293c";
    foreground = "#ebecef";
    muted = "#9da6b9";
    accent = "#668bd6";
    accentForeground = "#0a0c12";
    border = "#5a72aa";
    focus = "#bf8cd9";
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
    description = "Dark r1999 composition by miya*ki; palette derived from the accepted artwork with contrast checks.";
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
