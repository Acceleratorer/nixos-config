{
  registry ? import ./registry.nix { },
}:

let
  packIds = map (pack: pack.id) registry.packs;
  withoutHash = colour: builtins.substring 1 6 colour;

  metadata = {
    neutral = {
      name = "cryoforge-pack";
      flavour = "neutral";
    };
    cryoforge-denia = {
      name = "cryoforge-pack";
      flavour = "cryoforge-denia";
    };
  };

  adaptPalette = palette:
    builtins.mapAttrs (_: withoutHash) {
      primary_paletteKeyColor = palette.accent;
      secondary_paletteKeyColor = palette.focus;
      tertiary_paletteKeyColor = palette.warning;
      neutral_paletteKeyColor = palette.surface;
      neutral_variant_paletteKeyColor = palette.border;

      background = palette.background;
      onBackground = palette.foreground;
      surface = palette.surface;
      surfaceDim = palette.background;
      surfaceBright = palette.surfaceElevated;
      surfaceContainerLowest = palette.background;
      surfaceContainerLow = palette.surface;
      surfaceContainer = palette.surface;
      surfaceContainerHigh = palette.surfaceElevated;
      surfaceContainerHighest = palette.surfaceElevated;
      onSurface = palette.foreground;
      surfaceVariant = palette.surfaceElevated;
      onSurfaceVariant = palette.muted;
      inverseSurface = palette.foreground;
      inverseOnSurface = palette.background;
      outline = palette.border;
      outlineVariant = palette.border;
      shadow = "#000000";
      scrim = "#000000";
      surfaceTint = palette.accent;

      primary = palette.accent;
      onPrimary = palette.accentForeground;
      primaryContainer = palette.surfaceElevated;
      onPrimaryContainer = palette.foreground;
      inversePrimary = palette.focus;
      secondary = palette.focus;
      onSecondary = palette.background;
      secondaryContainer = palette.surfaceElevated;
      onSecondaryContainer = palette.foreground;
      tertiary = palette.warning;
      onTertiary = palette.background;
      tertiaryContainer = palette.surfaceElevated;
      onTertiaryContainer = palette.foreground;
      error = palette.error;
      onError = palette.accentForeground;
      errorContainer = palette.surfaceElevated;
      onErrorContainer = palette.foreground;
      success = palette.success;
      onSuccess = palette.background;
      successContainer = palette.surfaceElevated;
      onSuccessContainer = palette.foreground;

      primaryFixed = palette.accent;
      primaryFixedDim = palette.accent;
      onPrimaryFixed = palette.accentForeground;
      onPrimaryFixedVariant = palette.background;
      secondaryFixed = palette.focus;
      secondaryFixedDim = palette.focus;
      onSecondaryFixed = palette.background;
      onSecondaryFixedVariant = palette.surface;
      tertiaryFixed = palette.warning;
      tertiaryFixedDim = palette.warning;
      onTertiaryFixed = palette.background;
      onTertiaryFixedVariant = palette.surface;

      term0 = palette.background;
      term1 = palette.error;
      term2 = palette.success;
      term3 = palette.warning;
      term4 = palette.focus;
      term5 = palette.accent;
      term6 = palette.focus;
      term7 = palette.foreground;
      term8 = palette.muted;
      term9 = palette.error;
      term10 = palette.success;
      term11 = palette.warning;
      term12 = palette.focus;
      term13 = palette.accent;
      term14 = palette.focus;
      term15 = palette.foreground;
    };

  mkScheme = pack: {
    inherit (metadata.${pack.id}) name flavour;
    cryoforge = {
      schemaVersion = 1;
      packId = pack.id;
    };
    mode = "dark";
    variant = "tonalspot";
    colours = adaptPalette pack.palette;
  };
in
assert packIds == [
  "neutral"
  "cryoforge-denia"
];
builtins.listToAttrs (
  map (pack: {
    name = pack.id;
    value = mkScheme pack;
  }) registry.packs
)
