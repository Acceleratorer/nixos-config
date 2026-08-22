pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Scope {
    id: root

    enum PamState {
        None,
        Error,
        MaxTries,
        Failed
    }

    readonly property alias passwd: passwd
    readonly property alias fprint: fprint
    readonly property alias howdy: howdy

    property string lockMessage
    property int state: Pam.None
    property string buffer

    signal cancelRequested
    signal flashMsg
    signal submitRequested(string response)

    function handleKey(event: KeyEvent): void {
        if (passwd.active || state === Pam.MaxTries)
            return;

        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            passwd.start();
        } else if (event.key === Qt.Key_Escape) {
            root.cancelRequested();
        } else if (event.key === Qt.Key_Backspace) {
            buffer = event.modifiers & Qt.ControlModifier ? "" : buffer.slice(0, -1);
        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
            buffer += event.text;
        }
    }

    function reset(): void {
        buffer = "";
        lockMessage = "";
        state = Pam.None;
        passwd.active = false;
        passwd.message = "";
    }

    function fail(message: string): void {
        buffer = "";
        passwd.active = false;
        passwd.message = message;
        state = Pam.Failed;
        flashMsg();
    }

    function error(message: string): void {
        buffer = "";
        passwd.active = false;
        passwd.message = message;
        state = Pam.Error;
        flashMsg();
    }

    QtObject {
        id: passwd

        property bool active
        property string message

        function start(): void {
            if (active)
                return;

            const response = root.buffer;
            root.buffer = "";
            active = true;
            root.state = Pam.None;
            root.lockMessage = "";
            root.submitRequested(response);
        }

        function abort(): void {
            active = false;
        }
    }

    QtObject {
        id: fprint

        readonly property bool active: false
        readonly property bool available: false
        readonly property bool canAttempt: false
        readonly property string message: ""
        readonly property int state: Pam.None
        readonly property int tries: 0
    }

    QtObject {
        id: howdy

        readonly property bool active: false
        readonly property bool available: false
        readonly property bool canAttempt: false
        readonly property string message: ""
        readonly property int state: Pam.None
        readonly property int tries: 0
    }
}
