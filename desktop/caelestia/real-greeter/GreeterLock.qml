import QtQuick
import Quickshell
import qs.modules.lock

Scope {
    id: root

    required property var screen

    readonly property bool unlocking: false
    readonly property alias pam: pam

    signal cancelRequested
    signal submitRequested(string response)

    Pam {
        id: pam

        onCancelRequested: root.cancelRequested()
        onSubmitRequested: response => root.submitRequested(response)
    }
}
