import QtQuick
import QtQuick.Effects
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.lock
import qs.services

Item {
    id: root

    required property var lock
    property bool recoveryAvailable

    signal recoveryRequested

    Image {
        anchors.fill: parent
        source: Quickshell.shellPath("assets/greeter-wallpaper.png")
        asynchronous: true
        fillMode: Image.PreserveAspectCrop

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blur: 0.3
            blurEnabled: true
            blurMax: 48
            blurMultiplier: 1
        }
    }

    StyledRect {
        anchors.fill: parent
        color: Qt.alpha(Colours.palette.m3surface, 0.32)
    }

    Item {
        id: lockContent

        anchors.centerIn: parent
        implicitWidth: root.height * Tokens.sizes.lock.heightMult * Tokens.sizes.lock.ratio
        implicitHeight: root.height * Tokens.sizes.lock.heightMult

        StyledRect {
            anchors.fill: parent
            color: Colours.palette.m3surface
            opacity: Colours.transparency.enabled ? Colours.transparency.base : 1
            radius: parent.Tokens.rounding.extraLarge * 1.5

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
            }
        }

        Content {
            anchors.centerIn: parent
            width: parent.width - Tokens.padding.extraLargeIncreased
            height: parent.height - Tokens.padding.extraLargeIncreased

            lock: root.lock
        }
    }

    IconTextButton {
        id: recoveryButton

        function activate(): void {
            if (!disabled)
                root.recoveryRequested();
        }

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Tokens.padding.extraLarge
        activeFocusOnTab: !disabled
        disabled: !root.recoveryAvailable
        icon: "arrow_back"
        text: qsTr("Return to recovery greeter")
        type: IconTextButton.Tonal
        inactiveColour: activeFocus ? Colours.palette.m3secondary : Colours.palette.m3secondaryContainer
        inactiveOnColour: activeFocus ? Colours.palette.m3onSecondary : Colours.palette.m3onSecondaryContainer
        onClicked: activate()

        Keys.onEnterPressed: activate()
        Keys.onReturnPressed: activate()
        Keys.onSpacePressed: activate()
    }
}
