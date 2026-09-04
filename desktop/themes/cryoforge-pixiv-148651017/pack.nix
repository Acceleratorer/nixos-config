{
  id = "cryoforge-pixiv-148651017";
  displayName = "CryoForge Qingxiao";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-pixiv-148651017" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-pixiv-148651017/wallpaper.jpg";
      sha256 = "fb8af5e723de96b8ec518cc6c22c912d89c973eed598ba4bf4bf4a20db8e465f";
    };
    thumbnail = {
      path = "assets/cryoforge-pixiv-148651017/preview.jpg";
      sha256 = "6c5bc7090a6f44d39cdf53b2aaab521d4239af693bc0bfde0ba729c575c91873";
    };
  };
  palette = {
    background = "#0d121a";
    surface = "#15202e";
    surfaceElevated = "#25343c";
    foreground = "#ebefef";
    muted = "#9db7b9";
    accent = "#55d3e7";
    accentForeground = "#0a0c12";
    border = "#3f8492";
    focus = "#867bea";
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
    description = "Dark wuwa composition by Mihan; palette derived from the accepted artwork with contrast checks.";
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
