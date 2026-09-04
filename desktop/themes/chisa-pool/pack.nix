let
  acceptedGreeterSchemePath = ../../caelestia/real-greeter/assets/scheme.json;
  acceptedGreeterScheme = builtins.fromJSON (builtins.readFile acceptedGreeterSchemePath);
in
assert
  builtins.hashFile "sha256" acceptedGreeterSchemePath
  == "d65fe2ec280c09864be9854f03eda35cb3ed8c6395ea8d671982acbc6f917c40";
{
  id = "chisa-pool";
  displayName = "Chisa Pool";
  kind = "curated";
  allowedWallpaperPackIds = [ "chisa-pool" ];
  assets = {
    wallpaper = {
      path = "assets/chisa-pool/wallpaper.jpg";
      sha256 = "a4dfcf92c4170405ac37102b27c606c5e9b1bb6cd77c9f04d530fa752aab604c";
    };
    thumbnail = {
      path = "assets/chisa-pool/preview.jpg";
      sha256 = "a4dfcf92c4170405ac37102b27c606c5e9b1bb6cd77c9f04d530fa752aab604c";
    };
  };
  palette = {
    background = "#05070d";
    surface = "#0a1020";
    surfaceElevated = "#223151";
    foreground = "#dcebff";
    muted = "#8193ab";
    accent = "#00e5ff";
    accentForeground = "#002f35";
    border = "#4d6fb7";
    focus = "#77b6e1";
    success = "#9bd8b5";
    warning = "#f2d28b";
    error = "#ffb4ab";
  };
  scheme = {
    mode = "fixed";
    acceptedSourceSha256 = "d65fe2ec280c09864be9854f03eda35cb3ed8c6395ea8d671982acbc6f917c40";
    colours = acceptedGreeterScheme.colours;
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
    description = "Accepted Chisa Pool wallpaper and the existing Chisa greeter palette.";
    swatches = [
      "background"
      "surfaceElevated"
      "accent"
      "focus"
      "foreground"
    ];
  };
  fallback = {
    missingPublicState = true;
    invalidPublicState = true;
    recovery = true;
  };
}
