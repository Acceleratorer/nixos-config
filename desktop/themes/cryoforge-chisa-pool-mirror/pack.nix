{
  id = "cryoforge-chisa-pool-mirror";
  displayName = "CryoForge Chisa pool float — mirror";
  kind = "curated";
  allowedWallpaperPackIds = [ "cryoforge-chisa-pool-mirror" ];
  assets = {
    wallpaper = {
      path = "assets/cryoforge-chisa-pool-mirror/wallpaper.jpg";
      sha256 = "667e0e8dce360d1f827172c68e817705dd22a3d817e23efcce638b092a6b9701";
    };
    thumbnail = {
      path = "assets/cryoforge-chisa-pool-mirror/preview.jpg";
      sha256 = "27e59c334df4a8e342810b48641b6cefb9a3c8000b7a927ec9031f0f14552f09";
    };
  };
  palette = {
    background = "#111315";
    surface = "#1d2126";
    surfaceElevated = "#25353c";
    foreground = "#efebeb";
    muted = "#b99d9d";
    accent = "#58c6e4";
    accentForeground = "#0a0c12";
    border = "#438498";
    focus = "#de9c87";
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
    description = "Dark wuwa composition by qianqianjie (attribution lead); palette derived from the accepted artwork with contrast checks.";
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
