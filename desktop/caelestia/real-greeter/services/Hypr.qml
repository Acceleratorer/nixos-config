pragma Singleton

import QtQuick
import Quickshell

Singleton {
    signal configReloaded

    readonly property bool capsLock: false
    readonly property bool numLock: false
    readonly property bool usingLua: false
    readonly property string defaultKbLayout: Quickshell.env("XKB_DEFAULT_LAYOUT") || "us"
    readonly property string kbLayout: defaultKbLayout
    readonly property string kbLayoutFull: defaultKbLayout

    readonly property var extras: QtObject {
        function batchMessage(messages: list<string>): void {
        }
    }
}
