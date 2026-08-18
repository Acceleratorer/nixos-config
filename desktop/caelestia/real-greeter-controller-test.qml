pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "real-greeter"
import "real-greeter/adapters" as Adapters

ShellRoot {
    id: root

    readonly property string scenario: Quickshell.env("CAELESTIA_CONTROLLER_SCENARIO") || "success"
    readonly property string testPassword: Quickshell.env("CAELESTIA_TEST_PASSWORD") || "password"
    readonly property bool cancelWithAuthPending: ["cancel-late-success", "cancel-late-failure", "cancel-late-auth-message", "cancel-late-duplicate"].includes(scenario)
    readonly property bool recoveryScenario: scenario.startsWith("recovery")
    property int phase
    property bool retrying
    property bool cancelled

    Timer {
        id: cancelExit

        interval: 750
        onTriggered: {
            if (controller.launching || lock.pam.passwd.message !== "") {
                console.error("cancelled transaction changed state");
                Qt.exit(1);
            } else {
                Qt.exit(0);
            }
        }
    }

    Timer {
        id: freshAttempt

        interval: 50
        repeat: true
        onTriggered: {
            if (controller.connected && !controller.cancelling) {
                stop();
                root.phase = 3;
                controller.submit(root.testPassword);
            }
        }
    }

    GreeterLock {
        id: lock

        screen: Quickshell.screens[0]
    }

    Adapters.GreetdController {
        id: controller

        pam: lock.pam
        username: "user"
        sessionCommand: ["test-session"]
    }

    Timer {
        running: true
        interval: 50
        repeat: true
        onTriggered: {
            const cancelScenario = root.scenario.startsWith("cancel");
            const cancelAtPrompt = cancelScenario && !root.cancelWithAuthPending && root.scenario !== "cancel-late-start-session";

            if (root.scenario === "recovery-initial" && !root.cancelled && controller.connected && controller.inactive) {
                root.cancelled = true;
                controller.requestRecovery();
            } else if (root.scenario === "recovery-launching-rejected" && !root.cancelled && controller.launching) {
                root.cancelled = true;
                controller.requestRecovery();
            } else if (root.scenario === "cancel-late-start-session" && !root.cancelled && controller.launching) {
                root.cancelled = true;
                root.phase = 2;
                controller.cancel();
                cancelExit.start();
            } else if (root.scenario === "recovery-late-success" && !root.cancelled && root.phase === 3 && controller.authenticating && !controller.awaitingResponse) {
                root.cancelled = true;
                root.phase = 2;
                controller.requestRecovery();
            } else if (root.cancelWithAuthPending && !root.cancelled && root.phase === 3 && controller.authenticating && !controller.awaitingResponse) {
                root.cancelled = true;
                root.phase = 2;
                controller.cancel();
                cancelExit.start();
            } else if (root.scenario === "recovery" && !root.cancelled && controller.awaitingResponse && lock.pam.passwd.message === "7 + 2:") {
                root.cancelled = true;
                root.phase = 2;
                controller.requestRecovery();
            } else if (cancelAtPrompt && !root.cancelled && controller.awaitingResponse && lock.pam.passwd.message === "7 + 2:") {
                root.cancelled = true;
                root.phase = 2;
                controller.cancel();

                if (root.scenario === "cancel-fresh-success")
                    freshAttempt.start();
                else
                    cancelExit.start();
            } else if (controller.connected && controller.inactive && root.phase === 0) {
                root.phase = 1;
                controller.submit(root.testPassword);
            } else if (controller.awaitingResponse && lock.pam.passwd.message === "7 + 2:") {
                if (root.scenario === "failure-retry" && !root.retrying) {
                    root.phase = 2;
                    controller.submit("8");
                } else if (!cancelScenario || root.cancelWithAuthPending || root.scenario === "cancel-fresh-success" || root.scenario === "cancel-late-start-session" || root.scenario === "recovery" || root.scenario === "recovery-late-success" || root.scenario === "recovery-launching-rejected") {
                    root.phase = 3;
                    controller.submit("9");
                }
            } else if (root.scenario === "failure-retry" && root.retrying && controller.inactive) {
                root.phase = 4;
                controller.submit(root.testPassword);
            }
        }
    }

    Connections {
        function onLaunchingChanged(): void {
            if (root.scenario === "recovery-launching-rejected" && controller.launching && !root.cancelled) {
                root.cancelled = true;
                controller.requestRecovery();
            }
        }

        function onError(error: string): void {
            console.error(error);
            Qt.exit(1);
        }

        function onAuthFailure(message: string): void {
            if (root.scenario === "failure-retry" && !root.retrying) {
                root.retrying = true;
                return;
            }

            console.error("unexpected authentication failure");
            Qt.exit(1);
        }

        function onLaunched(): void {
            if ((root.scenario.startsWith("cancel") && root.scenario !== "cancel-fresh-success") || (root.recoveryScenario && root.scenario !== "recovery-launching-rejected")) {
                console.error("cancel scenario launched unexpectedly");
                Qt.exit(1);
            } else {
                Qt.exit(0);
            }
        }

        target: controller
    }
}
