{
  registry ? {
    schemaVersion = 1;
    defaultPackId = "neutral";
    packs = [
      {
        id = "neutral";
        displayName = "CryoForge Neutral";
        kind = "neutral";
        wallpaper = null;
        palette = import ../palette.nix;
        shell = {
          panel = "surface";
          card = "surfaceElevated";
          text = "foreground";
          subduedText = "muted";
          accent = "accent";
          outline = "border";
          focus = "focus";
        };
        preview = {
          thumbnail = null;
          description = "Wallpaper-independent fallback using the active CryoForge neutral palette.";
          swatches = [
            "background"
            "surfaceElevated"
            "accent"
            "foreground"
            "focus"
          ];
        };
      }
    ];
  },
}:

let
  registryKeys = [
    "schemaVersion"
    "defaultPackId"
    "packs"
  ];
  packKeys = [
    "id"
    "displayName"
    "kind"
    "wallpaper"
    "palette"
    "shell"
    "preview"
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
    "thumbnail"
    "description"
    "swatches"
  ];

  exactKeys = expected: value:
    builtins.isAttrs value
    && builtins.attrNames value
      == builtins.sort builtins.lessThan expected;
  unique = values:
    builtins.length values
    == builtins.length (
      builtins.foldl'
        (seen: value:
          if builtins.elem value seen then seen else seen ++ [ value ]
        )
        [ ]
        values
    );
  validSlug = value:
    builtins.isString value
    && builtins.stringLength value >= 1
    && builtins.stringLength value <= 64
    && builtins.match "^[a-z0-9]+(-[a-z0-9]+)*$" value != null;
  validColor = value:
    builtins.isString value
    && builtins.match
      "^#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]$"
      value
      != null;
  validLocalAsset = value:
    builtins.isString value
    && builtins.stringLength value >= 1
    && builtins.stringLength value <= 240
    && builtins.match
      "^[A-Za-z0-9][A-Za-z0-9._-]*(/[A-Za-z0-9][A-Za-z0-9._-]*)*$"
      value
      != null;
  validPalette = palette:
    exactKeys semanticKeys palette
    && builtins.all (key: validColor palette.${key}) semanticKeys;
  validShell = shell:
    exactKeys shellRoleKeys shell
    && builtins.all
      (role: builtins.elem shell.${role} semanticKeys)
      shellRoleKeys;
  validPreview = preview:
    exactKeys previewKeys preview
    && builtins.isString preview.description
    && builtins.stringLength preview.description >= 1
    && builtins.stringLength preview.description <= 180
    && builtins.match "^[^\n\r]+$" preview.description != null
    && builtins.isList preview.swatches
    && builtins.length preview.swatches >= 1
    && builtins.length preview.swatches <= 6
    && unique preview.swatches
    && builtins.all
      (swatch: builtins.isString swatch && builtins.elem swatch semanticKeys)
      preview.swatches;
  validPack = pack:
    exactKeys packKeys pack
    && validSlug pack.id
    && builtins.isString pack.displayName
    && builtins.stringLength pack.displayName >= 1
    && builtins.stringLength pack.displayName <= 80
    && builtins.elem pack.kind [
      "neutral"
      "curated"
    ]
    && validPalette pack.palette
    && validShell pack.shell
    && validPreview pack.preview
    && (
      if pack.kind == "curated" then
        validLocalAsset pack.wallpaper
        && validLocalAsset pack.preview.thumbnail
      else
        (pack.wallpaper == null || validLocalAsset pack.wallpaper)
        && (
          pack.preview.thumbnail == null
          || validLocalAsset pack.preview.thumbnail
        )
    );
  validRegistry =
    exactKeys registryKeys registry
    && registry.schemaVersion == 1
    && validSlug registry.defaultPackId
    && builtins.isList registry.packs
    && builtins.length registry.packs >= 1
    && builtins.all validPack registry.packs
    && (
      let
        ids = map (pack: pack.id) registry.packs;
      in
      unique ids
      && builtins.length (
        builtins.filter (id: id == registry.defaultPackId) ids
      ) == 1
    );
in
if validRegistry then
  registry
else
  throw "CryoForge theme-pack registry validation failed"
