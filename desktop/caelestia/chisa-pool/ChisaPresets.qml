pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    readonly property list<var> presets: [
        {
            "id": "chisa-pool",
            "name": "Chisa Pool",
            "wallpaper": Quickshell.shellPath("assets/chisa-pool-direct.jpg"),
            "thumbnail": Quickshell.shellPath("assets/chisa-pool-direct.jpg"),
            "tokens": {
                "deepSurface": "#08111F",
                "foreground": "#F2F7FF",
                "muted": "#A7B6CF",
                "cyan": "#18D7E8",
                "blue": "#77B9E4",
                "lavender": "#B39BF6",
                "blush": "#FFA6B4"
            }
        }
    ]

    readonly property var selectedPreset: root.presets.find(preset => preset.id === props.selectedPresetId) ?? root.presets[0]
    readonly property string selectedPresetId: root.selectedPreset.id
    readonly property color deepSurface: root.selectedPreset.tokens.deepSurface
    readonly property color foreground: root.selectedPreset.tokens.foreground
    readonly property color muted: root.selectedPreset.tokens.muted
    readonly property color cyan: root.selectedPreset.tokens.cyan
    readonly property color blue: root.selectedPreset.tokens.blue
    readonly property color lavender: root.selectedPreset.tokens.lavender
    readonly property color blush: root.selectedPreset.tokens.blush

    function preview(preset: var): void {
        if (!preset)
            return;

        Wallpapers.previewColourLock = true;
        Wallpapers.preview(preset.wallpaper);
    }

    function stopPreview(): void {
        Wallpapers.stopPreview();
        Wallpapers.previewColourLock = false;
    }

    function apply(preset: var): void {
        if (!preset)
            return;

        props.selectedPresetId = preset.id;
        root.stopPreview();
        Wallpapers.setManualWallpaper(preset.wallpaper);
    }

    PersistentProperties {
        id: props

        property string selectedPresetId: "chisa-pool"

        reloadableId: "chisaPresetGallery"
    }
}
