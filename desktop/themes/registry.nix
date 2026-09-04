{
  registry ? {
    schemaVersion = 2;
    defaultPackId = "neutral";
    fallbackPackId = "chisa-pool";
    packs = [
      {
        id = "neutral";
        displayName = "CryoForge Neutral";
        kind = "overlay";
        allowedWallpaperPackIds = [
          "chisa-pool"
          "cryoforge-denia"
          "cryoforge-chisa-pool-mirror"
          "cryoforge-wallhaven-k8ljxd"
          "cryoforge-pixiv-115550491"
          "cryoforge-pixiv-129183437"
          "cryoforge-pixiv-125244568"
          "cryoforge-pixiv-132131646"
          "cryoforge-pixiv-148651669"
          "cryoforge-pixiv-103199586"
          "cryoforge-pixiv-146159627"
          "cryoforge-pixiv-131599235"
          "cryoforge-pixiv-124952563"
          "cryoforge-local-hnny-vtwuaark-l"
          "cryoforge-pixiv-139029721"
          "cryoforge-pixiv-131466322"
          "cryoforge-pixiv-148651017"
          "cryoforge-pixiv-145248543"
        ];
        assets = {
          wallpaper = null;
          thumbnail = null;
        };
        palette = import ../palette.nix;
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
          description = "Wallpaper-independent overlay using the CryoForge neutral palette.";
          swatches = [
            "background"
            "surfaceElevated"
            "accent"
            "foreground"
            "focus"
          ];
        };
        fallback = {
          missingPublicState = false;
          invalidPublicState = false;
          recovery = false;
        };
      }
      (import ./chisa-pool/pack.nix)
      (
        let
          legacyDenia = import ./cryoforge-denia/pack.nix;
        in
        {
          inherit (legacyDenia)
            displayName
            id
            kind
            palette
            ;
          allowedWallpaperPackIds = [ legacyDenia.id ];
          assets = {
            wallpaper = {
              path = legacyDenia.wallpaper;
              sha256 = "34e9569bd827a07c20715d6b14c09603c60755d4a9d829ed6b542fff6f3fefcb";
            };
            thumbnail = {
              path = legacyDenia.preview.thumbnail;
              sha256 = "f67c58a530a4e44c491937e13e33b36aedf9e6ac8b0fca8a25ba6c6696824045";
            };
          };
          scheme = {
            mode = "adapted";
            acceptedSourceSha256 = null;
            colours = null;
          };
          presentation = {
            shell = legacyDenia.shell;
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
            inherit (legacyDenia.preview) description swatches;
          };
          fallback = {
            missingPublicState = false;
            invalidPublicState = false;
            recovery = false;
          };
        }
      )
      (import ./cryoforge-chisa-pool-mirror/pack.nix)
      (import ./cryoforge-wallhaven-k8ljxd/pack.nix)
      (import ./cryoforge-pixiv-115550491/pack.nix)
      (import ./cryoforge-pixiv-129183437/pack.nix)
      (import ./cryoforge-pixiv-125244568/pack.nix)
      (import ./cryoforge-pixiv-132131646/pack.nix)
      (import ./cryoforge-pixiv-148651669/pack.nix)
      (import ./cryoforge-pixiv-103199586/pack.nix)
      (import ./cryoforge-pixiv-146159627/pack.nix)
      (import ./cryoforge-pixiv-131599235/pack.nix)
      (import ./cryoforge-pixiv-124952563/pack.nix)
      (import ./cryoforge-local-hnny-vtwuaark-l/pack.nix)
      (import ./cryoforge-pixiv-139029721/pack.nix)
      (import ./cryoforge-pixiv-131466322/pack.nix)
      (import ./cryoforge-pixiv-148651017/pack.nix)
      (import ./cryoforge-pixiv-145248543/pack.nix)
    ];
  },
}:

let
  registryKeys = [
    "schemaVersion"
    "defaultPackId"
    "fallbackPackId"
    "packs"
  ];
  packKeys = [
    "allowedWallpaperPackIds"
    "assets"
    "displayName"
    "fallback"
    "id"
    "kind"
    "palette"
    "presentation"
    "preview"
    "scheme"
  ];
  assetKeys = [
    "path"
    "sha256"
  ];
  assetsKeys = [
    "thumbnail"
    "wallpaper"
  ];
  semanticKeys = [
    "background"
    "surface"
    "surfaceElevated"
    "foreground"
    "muted"
    "accent"
    "accentForeground"
    "border"
    "focus"
    "success"
    "warning"
    "error"
  ];
  schemeKeys = [
    "acceptedSourceSha256"
    "colours"
    "mode"
  ];
  presentationKeys = [
    "lock"
    "normalGreeter"
    "shell"
  ];
  surfacePresentationKeys = [
    "palette"
    "wallpaper"
  ];
  shellRoleKeys = [
    "panel"
    "card"
    "text"
    "subduedText"
    "accent"
    "outline"
    "focus"
  ];
  previewKeys = [
    "description"
    "swatches"
  ];
  fallbackKeys = [
    "invalidPublicState"
    "missingPublicState"
    "recovery"
  ];
  requiredSchemeColourKeys = [
    "background"
    "error"
    "errorContainer"
    "inverseOnSurface"
    "inversePrimary"
    "inverseSurface"
    "neutral_paletteKeyColor"
    "neutral_variant_paletteKeyColor"
    "onBackground"
    "onError"
    "onErrorContainer"
    "onPrimary"
    "onPrimaryContainer"
    "onPrimaryFixed"
    "onPrimaryFixedVariant"
    "onSecondary"
    "onSecondaryContainer"
    "onSecondaryFixed"
    "onSecondaryFixedVariant"
    "onSuccess"
    "onSuccessContainer"
    "onSurface"
    "onSurfaceVariant"
    "onTertiary"
    "onTertiaryContainer"
    "onTertiaryFixed"
    "onTertiaryFixedVariant"
    "outline"
    "outlineVariant"
    "primary"
    "primaryContainer"
    "primaryFixed"
    "primaryFixedDim"
    "primary_paletteKeyColor"
    "scrim"
    "secondary"
    "secondaryContainer"
    "secondaryFixed"
    "secondaryFixedDim"
    "secondary_paletteKeyColor"
    "shadow"
    "success"
    "successContainer"
    "surface"
    "surfaceBright"
    "surfaceContainer"
    "surfaceContainerHigh"
    "surfaceContainerHighest"
    "surfaceContainerLow"
    "surfaceContainerLowest"
    "surfaceDim"
    "surfaceTint"
    "surfaceVariant"
    "term0"
    "term1"
    "term10"
    "term11"
    "term12"
    "term13"
    "term14"
    "term15"
    "term2"
    "term3"
    "term4"
    "term5"
    "term6"
    "term7"
    "term8"
    "term9"
    "tertiary"
    "tertiaryContainer"
    "tertiaryFixed"
    "tertiaryFixedDim"
    "tertiary_paletteKeyColor"
  ];

  exactKeys =
    expected: value:
    builtins.isAttrs value && builtins.attrNames value == builtins.sort builtins.lessThan expected;
  unique =
    values:
    builtins.length values
    == builtins.length (
      builtins.foldl' (seen: value: if builtins.elem value seen then seen else seen ++ [ value ]) [ ] values
    );
  validSlug =
    value:
    builtins.isString value
    && builtins.stringLength value >= 1
    && builtins.stringLength value <= 64
    && builtins.match "^[a-z0-9]+(-[a-z0-9]+)*$" value != null;
  validColor =
    value:
    builtins.isString value
    && builtins.match "^#[0-9a-f]{6}$" value != null;
  validSchemeColor =
    value:
    builtins.isString value
    && builtins.match "^[0-9a-f]{6}$" value != null;
  validSha256 =
    value:
    builtins.isString value
    && builtins.match "^[0-9a-f]{64}$" value != null;
  validLocalAsset =
    value:
    builtins.isString value
    && builtins.stringLength value >= 1
    && builtins.stringLength value <= 240
    && builtins.match "^[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)*$" value != null;
  validAsset =
    asset:
    asset == null
    || (
      exactKeys assetKeys asset
      && validLocalAsset asset.path
      && validSha256 asset.sha256
    );
  validPalette =
    palette:
    exactKeys semanticKeys palette && builtins.all (key: validColor palette.${key}) semanticKeys;
  validScheme =
    scheme:
    exactKeys schemeKeys scheme
    && builtins.elem scheme.mode [
      "adapted"
      "fixed"
    ]
    && (
      if scheme.mode == "fixed" then
        validSha256 scheme.acceptedSourceSha256
        && exactKeys requiredSchemeColourKeys scheme.colours
        && builtins.all (key: validSchemeColor scheme.colours.${key}) requiredSchemeColourKeys
      else
        scheme.acceptedSourceSha256 == null && scheme.colours == null
    );
  validShell =
    shell:
    exactKeys shellRoleKeys shell
    && builtins.all (role: builtins.elem shell.${role} semanticKeys) shellRoleKeys;
  validSurfacePresentation =
    surface:
    exactKeys surfacePresentationKeys surface
    && builtins.elem surface.palette [
      "pack"
      "session"
    ]
    && builtins.elem surface.wallpaper [
      "canonical"
      "session"
    ];
  validPresentation =
    presentation:
    exactKeys presentationKeys presentation
    && validShell presentation.shell
    && validSurfacePresentation presentation.lock
    && validSurfacePresentation presentation.normalGreeter;
  validPreview =
    preview:
    exactKeys previewKeys preview
    && builtins.isString preview.description
    && builtins.stringLength preview.description >= 1
    && builtins.stringLength preview.description <= 180
    && builtins.match "^[^\n\r]+$" preview.description != null
    && builtins.isList preview.swatches
    && builtins.length preview.swatches >= 1
    && builtins.length preview.swatches <= 6
    && unique preview.swatches
    && builtins.all (
      swatch: builtins.isString swatch && builtins.elem swatch semanticKeys
    ) preview.swatches;
  validFallback =
    fallback:
    exactKeys fallbackKeys fallback
    && builtins.all (key: builtins.isBool fallback.${key}) fallbackKeys;
  validPack =
    pack:
    exactKeys packKeys pack
    && validSlug pack.id
    && builtins.isString pack.displayName
    && builtins.stringLength pack.displayName >= 1
    && builtins.stringLength pack.displayName <= 80
    && builtins.elem pack.kind [
      "curated"
      "overlay"
    ]
    && builtins.isList pack.allowedWallpaperPackIds
    && builtins.length pack.allowedWallpaperPackIds >= 1
    && unique pack.allowedWallpaperPackIds
    && builtins.all validSlug pack.allowedWallpaperPackIds
    && exactKeys assetsKeys pack.assets
    && validAsset pack.assets.wallpaper
    && validAsset pack.assets.thumbnail
    && validPalette pack.palette
    && validScheme pack.scheme
    && validPresentation pack.presentation
    && validPreview pack.preview
    && validFallback pack.fallback
    && (
      if pack.kind == "curated" then
        pack.assets.wallpaper != null
        && pack.assets.thumbnail != null
        && pack.allowedWallpaperPackIds == [ pack.id ]
      else
        pack.assets.wallpaper == null
        && pack.assets.thumbnail == null
        && pack.presentation.normalGreeter.wallpaper == "canonical"
    );
  validRegistry =
    exactKeys registryKeys registry
    && registry.schemaVersion == 2
    && validSlug registry.defaultPackId
    && validSlug registry.fallbackPackId
    && builtins.isList registry.packs
    && builtins.length registry.packs >= 1
    && builtins.all validPack registry.packs
    && (
      let
        ids = map (pack: pack.id) registry.packs;
        wallpaperIds = map (pack: pack.id) (
          builtins.filter (pack: pack.assets.wallpaper != null) registry.packs
        );
        fallbackPacks = builtins.filter (
          pack:
          pack.fallback.missingPublicState
          && pack.fallback.invalidPublicState
          && pack.fallback.recovery
        ) registry.packs;
      in
      unique ids
      && builtins.length (builtins.filter (id: id == registry.defaultPackId) ids) == 1
      && builtins.length (builtins.filter (id: id == registry.fallbackPackId) ids) == 1
      && builtins.length fallbackPacks == 1
      && (builtins.head fallbackPacks).id == registry.fallbackPackId
      && builtins.all (
        pack:
        builtins.all (
          wallpaperId: builtins.elem wallpaperId wallpaperIds
        ) pack.allowedWallpaperPackIds
      ) registry.packs
    );
in
if validRegistry then registry else throw "CryoForge theme-pack registry validation failed"
