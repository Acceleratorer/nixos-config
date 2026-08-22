pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import Caelestia.Config
import "adapters" as Adapters

Window {
    id: root

    property bool candidateReady

    readonly property alias pam: lock.pam
    readonly property alias screenModel: lock.screen

    visible: true
    visibility: Window.FullScreen
    color: "transparent"
    flags: Qt.FramelessWindowHint

    onFrameSwapped: {
        if (!candidateReady) {
            candidateReady = true;
            controller.markReady();
        }
    }

    contentItem.Config.screen: lock.screen.name
    contentItem.Tokens.screen: lock.screen.name

    GreeterLock {
        id: lock

        screen: Quickshell.screens[0]
        onCancelRequested: controller.requestRecovery()
        onSubmitRequested: response => controller.submit(response)
    }

    Adapters.GreetdController {
        id: controller

        pam: lock.pam
        username: Quickshell.env("CAELESTIA_GREETER_USER") || "@GREETER_USER@"
    }

    GreeterContent {
        anchors.fill: parent
        lock: lock
        recoveryAvailable: controller.recoveryAvailable
        onRecoveryRequested: controller.requestRecovery()
    }
}
