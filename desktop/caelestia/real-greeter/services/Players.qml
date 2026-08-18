pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property list<var> list: []
    readonly property var active: null

    function getArtUrl(player: var): string {
        return "";
    }
}
