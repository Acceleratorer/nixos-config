{
  id = "cryoforge-pixiv-124952563";
  displayName = "CryoForge Kakania&Isolde";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-pixiv-124952563" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-pixiv-124952563/wallpaper.jpg";
      sha256 = "b3545793a6d832f74269a6c4cd1938a40c5990eadf30b9206961a91a33a5ab22";
    };
    thumbnail = {
      path = "assets/cryoforge-pixiv-124952563/preview.jpg";
      sha256 = "33c7e8915173f1427a2316d12bc1b064bccd9ea9cabde10f474ecb9920899f67";
    };
  };
  palette = {
    background = "#131511";
    surface = "#20261d";
    surfaceElevated = "#353c25";
    foreground = "#edebef";
    muted = "#a89db9";
    accent = "#cbef4d";
    accentForeground = "#0a0c12";
    border = "#788d37";
    focus = "#74f18b";
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
    description = "Dark r1999 composition by allk; palette derived from the accepted artwork with contrast checks.";
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
