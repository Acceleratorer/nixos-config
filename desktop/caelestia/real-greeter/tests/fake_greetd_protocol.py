#!/usr/bin/env python3

import argparse
import json
import os
import socket
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path


PASSWORD_SENTINEL = "phase13a-password-literal-must-not-appear"


def send_message(connection: socket.socket, message: dict) -> dict:
    payload = json.dumps(message, separators=(",", ":")).encode()
    connection.sendall(struct.pack("=I", len(payload)) + payload)

    header = connection.recv(4)
    if len(header) != 4:
        raise RuntimeError("fake greetd closed before sending a response header")

    expected = struct.unpack("=I", header)[0]
    chunks = bytearray()
    while len(chunks) < expected:
        chunk = connection.recv(expected - len(chunks))
        if not chunk:
            raise RuntimeError("fake greetd closed during a framed response")
        chunks.extend(chunk)

    return json.loads(chunks)


def read_message(connection: socket.socket) -> dict:
    header = connection.recv(4)
    if not header:
        raise EOFError
    if len(header) != 4:
        raise RuntimeError("controller closed during a request header")

    expected = struct.unpack("=I", header)[0]
    chunks = bytearray()
    while len(chunks) < expected:
        chunk = connection.recv(expected - len(chunks))
        if not chunk:
            raise RuntimeError("controller closed during a framed request")
        chunks.extend(chunk)

    return json.loads(chunks)


def write_message(connection: socket.socket, message: dict) -> None:
    payload = json.dumps(message, separators=(",", ":")).encode()
    connection.sendall(struct.pack("=I", len(payload)) + payload)


def connect() -> socket.socket:
    socket_path = os.environ.get("GREETD_SOCK")
    if not socket_path:
        raise RuntimeError("GREETD_SOCK is not set")

    connection = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    connection.connect(socket_path)
    return connection


def expect_auth(response: dict, message: str, echo: bool) -> None:
    assert response == {
        "type": "auth_message",
        "auth_message": message,
        "auth_message_type": "visible" if echo else "secret",
    }, response


def create_session(connection: socket.socket, username: str = "user") -> dict:
    return send_message(
        connection,
        {
            "type": "create_session",
            "username": username,
        },
    )


def authenticate(connection: socket.socket, challenge: str = "9") -> dict:
    response = create_session(connection)
    expect_auth(response, "Password:", False)

    response = send_message(
        connection,
        {
            "type": "post_auth_message_response",
            "response": "password",
        },
    )
    expect_auth(response, "7 + 2:", True)

    return send_message(
        connection,
        {
            "type": "post_auth_message_response",
            "response": challenge,
        },
    )


def test_authentication() -> int:
    with connect() as connection:
        response = authenticate(connection)
        assert response == {"type": "success"}, response
    return 0


def test_failure_retry() -> int:
    with connect() as connection:
        response = authenticate(connection, challenge="8")
        assert response == {
            "type": "error",
            "error_type": "auth_error",
            "description": "nope",
        }, response

        response = authenticate(connection)
        assert response == {"type": "success"}, response
    return 0


def test_success_start() -> int:
    command = ["@SESSION_COMMAND@"]
    environment = [
        "XDG_CURRENT_DESKTOP=Hyprland",
        "XDG_SESSION_DESKTOP=Hyprland",
        "XDG_SESSION_TYPE=wayland",
    ]

    with connect() as connection:
        response = authenticate(connection)
        assert response == {"type": "success"}, response

        response = send_message(
            connection,
            {
                "type": "start_session",
                "cmd": command,
                "env": environment,
            },
        )
        assert response == {"type": "success"}, response
    return 0


def test_cancel() -> int:
    with connect() as connection:
        response = create_session(connection)
        if response.get("type") not in {"auth_message", "success"}:
            raise AssertionError(f"unexpected create_session response: {response}")

        response = send_message(connection, {"type": "cancel_session"})
        if response.get("type") != "success":
            raise AssertionError(f"cancel_session did not succeed: {response}")
    return 0


class ControllerServer:
    def __init__(self, scenario: str):
        self.scenario = scenario
        self.stage = "inactive"
        self.cancel_requests = 0
        self.failure_responses = 0
        self.start_requests = 0
        self.started_after_cancel = False

    def reset(self) -> None:
        self.stage = "inactive"

    def handle(self, connection: socket.socket, request: dict) -> None:
        request_type = request.get("type")

        if request_type == "create_session":
            assert self.stage == "inactive", request_type
            assert request.get("username") == "user", request_type
            self.stage = "password"
            write_message(
                connection,
                {
                    "type": "auth_message",
                    "auth_message": "Password:",
                    "auth_message_type": "secret",
                },
            )
        elif request_type == "post_auth_message_response":
            self.handle_auth_response(connection, request)
        elif request_type == "start_session":
            self.start_requests += 1
            self.started_after_cancel = self.started_after_cancel or self.cancel_requests > 0
            assert self.stage == "authenticated", request_type
            assert request.get("cmd") == ["test-session"], request_type

            if self.scenario != "cancel-late-start-session":
                write_message(connection, {"type": "success"})
                self.stage = "launched"
        elif request_type == "cancel_session":
            self.handle_cancel(connection)
        else:
            raise AssertionError(f"unexpected controller request type: {request_type}")

    def handle_auth_response(self, connection: socket.socket, request: dict) -> None:
        response = request.get("response")

        if self.stage == "password":
            assert response == PASSWORD_SENTINEL, "secret response did not match the test sentinel"
            self.stage = "challenge"
            write_message(
                connection,
                {
                    "type": "auth_message",
                    "auth_message": "7 + 2:",
                    "auth_message_type": "visible",
                },
            )
        elif self.stage == "challenge" and response == "8":
            self.failure_responses += 1
            self.reset()
            write_message(
                connection,
                {
                    "type": "error",
                    "error_type": "auth_error",
                    "description": "nope",
                },
            )
        elif self.stage == "challenge" and response == "9":
            if self.scenario in {
                "cancel-late-success",
                "cancel-late-failure",
                "cancel-late-auth-message",
                "cancel-late-duplicate",
                "recovery-late-success",
            }:
                self.stage = "auth-pending"
            else:
                self.stage = "authenticated"
                write_message(connection, {"type": "success"})
        else:
            raise AssertionError("unexpected authentication response stage")

    def handle_cancel(self, connection: socket.socket) -> None:
        self.cancel_requests += 1

        if self.scenario == "cancel-late-failure":
            write_message(
                connection,
                {
                    "type": "error",
                    "error_type": "auth_error",
                    "description": "stale failure",
                },
            )
        elif self.scenario == "cancel-late-auth-message":
            write_message(
                connection,
                {
                    "type": "auth_message",
                    "auth_message": "stale prompt",
                    "auth_message_type": "secret",
                },
            )
        elif self.scenario == "cancel-late-duplicate":
            write_message(connection, {"type": "success"})
            write_message(connection, {"type": "success"})
        elif self.scenario == "cancel-late-start-session":
            write_message(connection, {"type": "success"})
            write_message(connection, {"type": "success"})
        elif self.scenario == "recovery-late-success":
            write_message(connection, {"type": "success"})
            write_message(connection, {"type": "success"})
        else:
            write_message(connection, {"type": "success"})

        if self.scenario in {
            "cancel-late-success",
            "cancel-late-failure",
            "cancel-late-auth-message",
            "cancel-late-duplicate",
        }:
            write_message(connection, {"type": "success"})

        self.reset()

    def assert_complete(self) -> None:
        if self.scenario == "success":
            assert self.start_requests == 1, "success did not request start_session"
        elif self.scenario == "failure-retry":
            assert self.failure_responses == 1, "failure/retry did not observe one failure"
            assert self.start_requests == 1, "failure/retry did not launch after retry"
        elif self.scenario == "cancel-fresh-success":
            assert self.cancel_requests == 1, "fresh-login scenario did not cancel once"
            assert self.start_requests == 1, "fresh transaction did not start a session"
        elif self.scenario == "recovery-launching-rejected":
            assert self.cancel_requests == 0, "unsafe recovery request reached greetd"
            assert self.start_requests == 1, "launching recovery request interrupted the session"
        else:
            assert self.cancel_requests == 1, "cancel request was not observed"
            expected_starts = 1 if self.scenario == "cancel-late-start-session" else 0
            assert self.start_requests == expected_starts, (
                f"unexpected start_session count after cancel: {self.start_requests}"
            )
            assert not self.started_after_cancel, "start_session was requested after cancellation"


def test_controller(scenario: str, command: list[str]) -> int:
    if not command:
        raise RuntimeError("controller test requires a command after --")

    server = ControllerServer(scenario)
    socket_dir = Path(tempfile.mkdtemp(prefix=f"phase13a1-{scenario}-"))
    socket_path = socket_dir / "greetd.sock"
    log_path = Path(os.environ.get("CAELESTIA_CONTROLLER_LOG", socket_dir / "controller.log"))
    environment = os.environ.copy()
    environment["GREETD_SOCK"] = str(socket_path)
    environment["CAELESTIA_CONTROLLER_SCENARIO"] = scenario
    environment["CAELESTIA_TEST_PASSWORD"] = PASSWORD_SENTINEL
    control_directory = socket_dir / "control"
    control_directory.mkdir(mode=0o700)
    environment["CAELESTIA_GREETER_CONTROL_DIR"] = str(control_directory)

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
        listener.bind(str(socket_path))
        listener.listen()
        listener.settimeout(0.1)

        with log_path.open("wb") as log:
            process = subprocess.Popen(command, env=environment, stdout=log, stderr=subprocess.STDOUT)

        connection = None
        deadline = time.monotonic() + 15
        try:
            while process.poll() is None and time.monotonic() < deadline:
                if connection is None:
                    try:
                        connection, _ = listener.accept()
                        connection.settimeout(0.1)
                    except TimeoutError:
                        continue

                try:
                    request = read_message(connection)
                except TimeoutError:
                    continue
                except (BrokenPipeError, ConnectionResetError, EOFError):
                    connection.close()
                    connection = None
                    continue

                server.handle(connection, request)

            if process.poll() is None:
                process.terminate()
                process.wait(timeout=2)
                raise RuntimeError("controller test timed out")
        finally:
            if connection is not None:
                connection.close()

    expected_returncode = 42 if scenario in {"recovery", "recovery-initial", "recovery-late-success"} else 0
    if process.returncode != expected_returncode:
        raise AssertionError(f"controller exited with {process.returncode}; log: {log_path}")

    server.assert_complete()
    if scenario in {"recovery", "recovery-initial", "recovery-late-success"}:
        assert (control_directory / "recovery-requested").read_text() == "recovery-requested-v1", (
            "recovery request was not recorded before cancellation"
        )
        assert (control_directory / "cancel-ack").read_text() == "cancel-ack-v1", (
            "recovery exit was not backed by an acknowledged cancellation"
        )
        assert not (control_directory / "session-started").exists(), (
            "recovery transaction recorded a successful session handoff"
        )
    elif scenario in {"success", "failure-retry", "cancel-fresh-success", "recovery-launching-rejected"}:
        assert (control_directory / "session-started").read_text() == "session-started-v1", (
            "successful transaction did not record its session handoff"
        )

    if scenario != "recovery-initial":
        assert (control_directory / "auth-began").read_text() == "auth-began-v1", (
            "authentication did not record its pre-recovery state"
        )

    log_text = log_path.read_text(errors="replace")
    assert PASSWORD_SENTINEL not in log_text, "password sentinel appeared in controller logs"
    assert "unexpected greetd response" not in log_text.lower(), "unexpected-success diagnostic appeared"
    assert "launched unexpectedly" not in log_text.lower(), "cancelled transaction launched"
    print(f"{scenario}: pass log={log_path}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "scenario",
        choices=(
            "auth",
            "failure-retry",
            "success-start",
            "cancel",
            "controller-success",
            "controller-failure-retry",
            "controller-cancel",
            "controller-cancel-late-success",
            "controller-cancel-late-failure",
            "controller-cancel-late-auth-message",
            "controller-cancel-late-duplicate",
            "controller-cancel-late-start-session",
            "controller-cancel-fresh-success",
            "controller-recovery",
            "controller-recovery-initial",
            "controller-recovery-late-success",
            "controller-recovery-launching-rejected",
        ),
    )
    parser.add_argument("command", nargs=argparse.REMAINDER)
    arguments = parser.parse_args()

    if arguments.scenario.startswith("controller-"):
        command = arguments.command
        if command and command[0] == "--":
            command = command[1:]
        return test_controller(arguments.scenario.removeprefix("controller-"), command)
    if arguments.scenario == "auth":
        return test_authentication()
    if arguments.scenario == "failure-retry":
        return test_failure_retry()
    if arguments.scenario == "success-start":
        return test_success_start()
    return test_cancel()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, RuntimeError) as error:
        print(f"fake-greetd test failed: {error}", file=sys.stderr)
        raise SystemExit(1)
