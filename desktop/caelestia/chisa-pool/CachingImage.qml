import QtQuick
import Quickshell
import Caelestia.Images

Item {
    id: root

    property string path
    property alias asynchronous: image.asynchronous
    property alias fillMode: image.fillMode
    property alias mipmap: image.mipmap
    property alias source: image.source
    property alias sourceSize: image.sourceSize
    readonly property alias status: image.status
    readonly property alias progress: image.progress
    readonly property bool chisaPoolProfileAvatar: path.endsWith("/.face")

    implicitWidth: image.implicitWidth
    implicitHeight: image.implicitHeight

    Image {
        id: image

        width: root.chisaPoolProfileAvatar ? root.width * 1.08 : root.width
        height: root.chisaPoolProfileAvatar ? root.height * 1.08 : root.height
        x: root.chisaPoolProfileAvatar
            ? (root.width - width) / 2 - root.width * 0.04
            : 0
        y: root.chisaPoolProfileAvatar
            ? (root.height - height) / 2 + root.height * 0.03
            : 0
        smooth: root.smooth

        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        source: IUtils.urlForPath(root.path, fillMode)
        sourceSize: {
            const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
            return Qt.size(width * dpr, height * dpr);
        }
    }
}
