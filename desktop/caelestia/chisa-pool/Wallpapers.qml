pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string themeId: "chisa-pool"
    readonly property string current: Quickshell.shellPath("assets/chisa-pool-direct.jpg")
    readonly property string actualCurrent: current
    readonly property list<var> list: [
        {
            "name": "chisa-pool-direct.jpg",
            "parentDir": Quickshell.shellPath("assets"),
            "path": root.current,
            "relativePath": "chisa-pool-direct.jpg"
        }
    ]

    property bool previewColourLock

    function getCategoryFor(w: var): string {
        return root.themeId;
    }

    function preview(path: string): void {
    }

    function query(search: string): list<var> {
        return root.list;
    }

    function setWallpaper(path: string): void {
    }

    function setRandom(): void {
    }

    function stopPreview(): void {
    }
}
