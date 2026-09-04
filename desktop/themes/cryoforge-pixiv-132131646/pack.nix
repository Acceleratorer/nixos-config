{
  id = "cryoforge-pixiv-132131646";
  displayName = "CryoForge スカーク";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-pixiv-132131646" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-pixiv-132131646/wallpaper.jpg";
      sha256 = "cfa1248d62e7964619e1242f519cf15a8fdb3d5814606a923b09655f98925d81";
    };
    thumbnail = {
      path = "assets/cryoforge-pixiv-132131646/preview.jpg";
      sha256 = "d1ae44fbd24bd247ee88bc76216b5e97c9a2826704d47d1c75e7c5686fb8d123";
    };
  };
  palette = {
    background = "#0b151b";
    surface = "#122530";
    surfaceElevated = "#25313c";
    foreground = "#ebebef";
    muted = "#9d9fb9";
    accent = "#6670d6";
    accentForeground = "#0a0c12";
    border = "#6b77b3";
    focus = "#cf8cd9";
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
    description = "Dark genshin composition by 久蒼穹; palette derived from the accepted artwork with contrast checks.";
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
