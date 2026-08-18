pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property string current: Quickshell.shellPath("assets/greeter-wallpaper.png")
}
