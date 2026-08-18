pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

Scope {
    id: root

    required property var pam

    property string username: "@GREETER_USER@"
    property list<string> sessionCommand: ["@SESSION_COMMAND@"]
    property list<string> sessionEnvironment: ["XDG_CURRENT_DESKTOP=Hyprland", "XDG_SESSION_DESKTOP=Hyprland", "XDG_SESSION_TYPE=wayland"]
    property string socketPath: Quickshell.env("GREETD_SOCK") || ""
    property string controlDirectory: Quickshell.env("CAELESTIA_GREETER_CONTROL_DIR") || ""

    property string queuedResponse
    property bool hasQueuedResponse
    property bool awaitingResponse
    property int transactionGeneration
    property int activeGeneration
    property int cancelledGeneration
    property bool transactionCancelled
    property string transactionState: "inactive"
    property var pendingRequests: []
    property var pendingFrames: []
    property int receivedBytes
    property bool socketEnabled: socketPath !== ""
    property bool cancellationPending
    property bool recoveryPending

    readonly property bool connected: greetdSocket.connected
    readonly property bool inactive: transactionState === "inactive"
    readonly property bool authenticating: transactionState === "authenticating"
    readonly property bool launching: transactionState === "launching"
    readonly property bool cancelling: cancellationPending
    readonly property bool recoveryAvailable: controlDirectory !== "" && !launching && !recoveryPending && !cancellationPending

    signal authFailure(string message)
    signal error(string message)
    signal launched

    function writeMarker(marker: var, value: string): bool {
        marker.setText(value);
        marker.reload();
        return marker.text() === value;
    }

    function exitCandidateFailure(message: string): void {
        failProtocol(message);
        Qt.callLater(() => Qt.exit(72));
    }

    function markReady(): void {
        if (!writeMarker(readyMarker, "ready-v1"))
            exitCandidateFailure(qsTr("Unable to record candidate readiness."));
    }

    function clearResponse(): void {
        queuedResponse = "";
        hasQueuedResponse = false;
        awaitingResponse = false;
    }

    function utf8Length(text: string): int {
        let length = 0;

        for (let index = 0; index < text.length; ++index) {
            const code = text.charCodeAt(index);

            if (code < 0x80) {
                length += 1;
            } else if (code < 0x800) {
                length += 2;
            } else if (code >= 0xd800 && code <= 0xdbff && index + 1 < text.length) {
                const next = text.charCodeAt(index + 1);
                if (next >= 0xdc00 && next <= 0xdfff) {
                    length += 4;
                    ++index;
                } else {
                    length += 3;
                }
            } else {
                length += 3;
            }
        }

        return length;
    }

    function frameRequest(request: var): string {
        let payload = JSON.stringify(request);
        let length = utf8Length(payload);

        while ((length & 0x80) !== 0 || (length & 0x8000) !== 0 || (length & 0x800000) !== 0 || (length & 0x80000000) !== 0) {
            payload += " ";
            ++length;
        }

        const header = String.fromCharCode(length & 0xff, (length >>> 8) & 0xff, (length >>> 16) & 0xff, (length >>> 24) & 0xff);
        return header + payload;
    }

    function sendRequest(request: var, generation: int, kind: string): void {
        pendingRequests = pendingRequests.concat([
            {
                "generation": generation,
                "kind": kind
            }
        ]);

        const frame = frameRequest(request);
        if (greetdSocket.connected) {
            greetdSocket.write(frame);
            greetdSocket.flush();
        } else {
            pendingFrames = pendingFrames.concat([frame]);
        }
    }

    function flushFrames(): void {
        const frames = pendingFrames;
        pendingFrames = [];

        for (const frame of frames)
            greetdSocket.write(frame);

        greetdSocket.flush();
    }

    function respond(response: string): void {
        if (activeGeneration === 0)
            return;

        sendRequest({
            "type": "post_auth_message_response",
            "response": response
        }, activeGeneration, "authenticate");
        awaitingResponse = false;
        queuedResponse = "";
        hasQueuedResponse = false;
    }

    function submit(response: string): void {
        if (launching || cancellationPending)
            return;

        pam.state = 0;
        pam.lockMessage = "";
        pam.passwd.message = "";

        if (activeGeneration === 0) {
            if (!writeMarker(authBeganMarker, "auth-began-v1")) {
                exitCandidateFailure(qsTr("Unable to record authentication state."));
                return;
            }

            ++transactionGeneration;
            activeGeneration = transactionGeneration;
            transactionCancelled = false;
            transactionState = "authenticating";
            queuedResponse = response;
            hasQueuedResponse = true;
            sendRequest({
                "type": "create_session",
                "username": username
            }, activeGeneration, "authenticate");
        } else if (awaitingResponse) {
            respond(response);
        } else {
            pam.passwd.active = false;
        }
    }

    function cancel(): void {
        const generation = activeGeneration;

        if (generation === 0) {
            clearResponse();
            pam.reset();
            return;
        }

        cancelledGeneration = generation;
        transactionCancelled = true;
        activeGeneration = 0;
        transactionState = "inactive";
        cancellationPending = true;

        clearResponse();
        pam.reset();

        sendRequest({
            "type": "cancel_session"
        }, generation, "cancel");
    }

    function requestRecovery(): void {
        if (!recoveryAvailable)
            return;

        if (!writeMarker(recoveryRequestedMarker, "recovery-requested-v1")) {
            exitCandidateFailure(qsTr("Unable to record the recovery request."));
            return;
        }

        let generation = activeGeneration;
        if (generation === 0) {
            ++transactionGeneration;
            generation = transactionGeneration;
        }

        cancelledGeneration = generation;
        transactionCancelled = true;
        activeGeneration = 0;
        transactionState = "inactive";
        cancellationPending = true;
        recoveryPending = true;

        clearResponse();
        pam.reset();

        sendRequest({
            "type": "cancel_session"
        }, generation, "recovery-cancel");
        recoveryCancelTimeout.restart();
    }

    function retireCancelledConnection(): void {
        cancellationPending = false;
        pendingRequests = [];
        pendingFrames = [];
        socketEnabled = false;
        reconnectTimer.restart();
    }

    function failAuthentication(message: string): void {
        const failure = message || qsTr("Incorrect password. Please try again.");

        activeGeneration = 0;
        transactionState = "inactive";
        clearResponse();
        pam.fail(failure);
        authFailure(failure);
    }

    function failProtocol(message: string): void {
        activeGeneration = 0;
        transactionState = "inactive";
        clearResponse();
        pam.error(message);
        error(message);
    }

    function decodeUtf8(bytes: var, start: int, length: int): string {
        const end = start + length;
        let result = "";

        for (let index = start; index < end; ) {
            const first = bytes[index++];
            let codepoint;

            if (first < 0x80) {
                codepoint = first;
            } else if ((first & 0xe0) === 0xc0 && index < end) {
                codepoint = ((first & 0x1f) << 6) | (bytes[index++] & 0x3f);
            } else if ((first & 0xf0) === 0xe0 && index + 1 < end) {
                codepoint = ((first & 0x0f) << 12) | ((bytes[index++] & 0x3f) << 6) | (bytes[index++] & 0x3f);
            } else if ((first & 0xf8) === 0xf0 && index + 2 < end) {
                codepoint = ((first & 0x07) << 18) | ((bytes[index++] & 0x3f) << 12) | ((bytes[index++] & 0x3f) << 6) | (bytes[index++] & 0x3f);
            } else {
                throw new Error("Invalid UTF-8 in greetd response.");
            }

            if (codepoint <= 0xffff) {
                result += String.fromCharCode(codepoint);
            } else {
                codepoint -= 0x10000;
                result += String.fromCharCode(0xd800 + (codepoint >>> 10), 0xdc00 + (codepoint & 0x3ff));
            }
        }

        return result;
    }

    function consumeResponses(data: var): void {
        const bytes = new Uint8Array(data);
        let offset = receivedBytes;

        if (offset > bytes.length)
            offset = 0;

        while (bytes.length - offset >= 4) {
            const length = bytes[offset] + bytes[offset + 1] * 0x100 + bytes[offset + 2] * 0x10000 + bytes[offset + 3] * 0x1000000;

            if (bytes.length - offset - 4 < length)
                break;

            let response;
            try {
                response = JSON.parse(decodeUtf8(bytes, offset + 4, length));
            } catch (parseError) {
                failProtocol(parseError.toString());
                return;
            }

            offset += 4 + length;
            handleResponse(response);
        }

        receivedBytes = offset;
    }

    function handleResponse(response: var): void {
        if (pendingRequests.length === 0) {
            if (activeGeneration === 0 || transactionCancelled)
                return;

            failProtocol(qsTr("greetd sent a response without a pending request."));
            return;
        }

        const request = pendingRequests[0];
        pendingRequests = pendingRequests.slice(1);

        if (request.kind === "recovery-cancel" && request.generation === cancelledGeneration) {
            recoveryCancelTimeout.stop();

            if (response.type !== "success") {
                recoveryPending = false;
                retireCancelledConnection();
                failProtocol(qsTr("greetd did not acknowledge recovery cancellation."));
                return;
            }

            if (!writeMarker(cancelAckMarker, "cancel-ack-v1")) {
                exitCandidateFailure(qsTr("Unable to record recovery cancellation."));
                return;
            }

            socketEnabled = false;
            Qt.callLater(() => Qt.exit(42));
            return;
        }

        if (request.kind === "cancel" && request.generation === cancelledGeneration) {
            retireCancelledConnection();
            return;
        }

        if (request.generation !== activeGeneration || activeGeneration === 0)
            return;

        if (response.type === "auth_message") {
            handleAuthMessage(response);
        } else if (response.type === "success") {
            handleSuccess(request.kind);
        } else if (response.type === "error") {
            if (response.error_type === "auth_error")
                failAuthentication(response.description);
            else
                failProtocol(response.description || qsTr("greetd authentication failed."));
        } else {
            failProtocol(qsTr("greetd returned an invalid response."));
        }
    }

    function handleAuthMessage(response: var): void {
        const message = response.auth_message || "";
        const messageType = response.auth_message_type || "";
        const responseRequired = messageType === "visible" || messageType === "secret";
        const echoResponse = messageType !== "secret";

        pam.passwd.message = message;

        if (messageType === "error")
            pam.error(message);

        awaitingResponse = responseRequired;
        if (!responseRequired) {
            sendRequest({
                "type": "post_auth_message_response"
            }, activeGeneration, "authenticate");
        } else if (echoResponse && message.toLowerCase().includes("user")) {
            respond(username);
        } else if (hasQueuedResponse) {
            respond(queuedResponse);
        } else {
            pam.passwd.active = false;
        }
    }

    function handleSuccess(kind: string): void {
        if (kind === "authenticate") {
            if (transactionCancelled || activeGeneration === 0)
                return;

            transactionState = "launching";
            clearResponse();
            sendRequest({
                "type": "start_session",
                "cmd": sessionCommand,
                "env": sessionEnvironment
            }, activeGeneration, "start-session");
        } else if (kind === "start-session") {
            if (transactionCancelled || activeGeneration === 0)
                return;

            if (!writeMarker(sessionStartedMarker, "session-started-v1")) {
                exitCandidateFailure(qsTr("Unable to record the session handoff."));
                return;
            }

            activeGeneration = 0;
            transactionState = "launched";
            launched();
            Qt.callLater(() => Qt.exit(0));
        } else {
            failProtocol(qsTr("greetd returned success for an invalid request."));
        }
    }

    Socket {
        id: greetdSocket

        path: root.socketPath
        connected: root.socketEnabled

        parser: StdioCollector {
            id: responseCollector

            waitForEnd: false
            onDataChanged: root.consumeResponses(responseCollector.data)
        }

        onConnectionStateChanged: {
            if (connected) {
                root.receivedBytes = 0;
                root.flushFrames();
            } else if (root.cancellationPending) {
                root.retireCancelledConnection();
            } else if (root.activeGeneration !== 0) {
                root.failProtocol(qsTr("Disconnected from greetd."));
            }
        }

        onError: error => {
            if (root.activeGeneration !== 0)
                root.failProtocol(qsTr("Unable to communicate with greetd (%1).").arg(error));
        }
    }

    Timer {
        id: reconnectTimer

        interval: 25
        onTriggered: root.socketEnabled = root.socketPath !== ""
    }

    Timer {
        id: recoveryCancelTimeout

        interval: 5000
        onTriggered: root.exitCandidateFailure(qsTr("Timed out waiting for greetd to cancel authentication."))
    }

    FileView {
        id: readyMarker

        path: root.controlDirectory === "" ? "" : `${root.controlDirectory}/ready`
        preload: false
        blockLoading: true
        blockWrites: true
        printErrors: false
    }

    FileView {
        id: authBeganMarker

        path: root.controlDirectory === "" ? "" : `${root.controlDirectory}/auth-began`
        preload: false
        blockLoading: true
        blockWrites: true
        printErrors: false
    }

    FileView {
        id: cancelAckMarker

        path: root.controlDirectory === "" ? "" : `${root.controlDirectory}/cancel-ack`
        preload: false
        blockLoading: true
        blockWrites: true
        printErrors: false
    }

    FileView {
        id: recoveryRequestedMarker

        path: root.controlDirectory === "" ? "" : `${root.controlDirectory}/recovery-requested`
        preload: false
        blockLoading: true
        blockWrites: true
        printErrors: false
    }

    FileView {
        id: sessionStartedMarker

        path: root.controlDirectory === "" ? "" : `${root.controlDirectory}/session-started`
        preload: false
        blockLoading: true
        blockWrites: true
        printErrors: false
    }
}
