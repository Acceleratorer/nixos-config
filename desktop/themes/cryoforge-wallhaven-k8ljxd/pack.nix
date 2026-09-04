{
  id = "cryoforge-wallhaven-k8ljxd";
  displayName = "CryoForge Chisa underwater";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-wallhaven-k8ljxd" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-wallhaven-k8ljxd/wallpaper.jpg";
      sha256 = "2cad194aabfeefe149c49153abd3cf9ec7916be61331ab53a06dc5348cbe805b";
    };
    thumbnail = {
      path = "assets/cryoforge-wallhaven-k8ljxd/preview.jpg";
      sha256 = "d6709783b271cd432539cacb58b43b897e810fbe7dc3bf2e42fce2bddbba0cbe";
    };
  };
  palette = {
    background = "#111515";
    surface = "#1d2426";
    surfaceElevated = "#25373c";
    foreground = "#ebefef";
    muted = "#9db6b9";
    accent = "#49d2f3";
    accentForeground = "#0a0c12";
    border = "#3a899c";
    focus = "#8571f4";
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
    description = "Dark wuwa composition by Meng Ziya (Wallhaven attribution); palette derived from the accepted artwork with contrast checks.";
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
