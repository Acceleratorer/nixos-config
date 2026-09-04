{
  id = "cryoforge-pixiv-139029721";
  displayName = "CryoForge 若那虹彩倾洒";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-pixiv-139029721" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-pixiv-139029721/wallpaper.jpg";
      sha256 = "f493a8ccf51b363e0f1a5a1d7fe23f4f8001423da80f69c235beeb00ad192806";
    };
    thumbnail = {
      path = "assets/cryoforge-pixiv-139029721/preview.jpg";
      sha256 = "5b5600cd34f202f1e3cc683fa690a724a657ab7dc22ddbb33f28e483cae85687";
    };
  };
  palette = {
    background = "#0b131b";
    surface = "#122030";
    surfaceElevated = "#253b3c";
    foreground = "#ebedef";
    muted = "#9daab9";
    accent = "#49f3cf";
    accentForeground = "#0a0c12";
    border = "#358e7e";
    focus = "#7192f4";
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
