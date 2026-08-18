import QtQuick
import QtQuick.Window
import Quickshell
import Caelestia.Config
import "modules"
import "real-greeter"

ShellRoot {
    GSFLoader {}

    GreeterLock {
        id: lock

        screen: previewScreen
    }

    QtObject {
        id: previewScreen

        readonly property int height: 1080
        readonly property string name: "phase13a-preview"
    }

    Window {
        id: previewWindow

        visible: true
        width: 1920
        height: 1080
        color: "transparent"
        title: "Caelestia real lock tree"

        contentItem.Config.screen: "phase13a-preview"
        contentItem.Tokens.screen: "phase13a-preview"

        GreeterContent {
            anchors.fill: parent
            lock: lock
        }

        Timer {
            running: Boolean(Quickshell.env("CAELESTIA_SCREENSHOT"))
            interval: Number(Quickshell.env("CAELESTIA_SCREENSHOT_DELAY_MS")) || 2200
            onTriggered: previewWindow.contentItem.grabToImage(result => {
                const path = Quickshell.env("CAELESTIA_SCREENSHOT");
                if (!result.saveToFile(path))
                    console.error(`unable to save screenshot to ${path}`);
                Qt.exit(0);
            })
        }
    }
}
