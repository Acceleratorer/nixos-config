pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var activeWindow: Hypr.activeToplevel
    readonly property var activeWindowState: activeWindow?.lastIpcObject
    readonly property string activeWindowTitle: activeWindow?.title || qsTr("No active window")
    readonly property string activeWindowClass: activeWindowState?.class || qsTr("Unknown")
    readonly property string currentWorkspace: {
        const workspace = Hypr.focusedWorkspace;
        if (!workspace)
            return qsTr("Unknown");

        const name = workspace.name || qsTr("Unknown");
        const id = workspace.id === undefined ? qsTr("Unknown") : String(workspace.id);
        return qsTr("%1 (%2)").arg(name).arg(id);
    }
    readonly property string focusedMonitor: Hypr.focusedMonitor?.name || qsTr("Unknown")
    readonly property string openToplevelCount: Hypr.toplevels?.values?.length === undefined ? qsTr("Unknown") : String(Hypr.toplevels.values.length)
    readonly property string workspaceCount: Hypr.workspaces?.values?.length === undefined ? qsTr("Unknown") : String(Hypr.workspaces.values.length)
    readonly property string monitorCount: Hypr.monitors?.values?.length === undefined ? qsTr("Unknown") : String(Hypr.monitors.values.length)
    readonly property string floatingState: {
        if (!root.activeWindowState)
            return qsTr("None");
        if (root.activeWindowState.floating === undefined)
            return qsTr("Unknown");
        return root.activeWindowState.floating ? qsTr("Yes") : qsTr("No");
    }
    readonly property string fullscreenState: {
        if (!root.activeWindowState)
            return qsTr("None");

        const fullscreen = root.activeWindowState.fullscreen;
        if (fullscreen === undefined)
            return qsTr("Unknown");
        if (fullscreen === 0)
            return qsTr("Off");
        if (fullscreen === 1)
            return qsTr("Maximised");
        return qsTr("On");
    }
    readonly property string pinnedState: {
        if (!root.activeWindowState)
            return qsTr("None");
        if (root.activeWindowState.pinned === undefined)
            return qsTr("Unknown");
        return root.activeWindowState.pinned ? qsTr("Yes") : qsTr("No");
    }
    readonly property string xwaylandState: {
        if (!root.activeWindowState)
            return qsTr("None");
        if (root.activeWindowState.xwayland === undefined)
            return qsTr("Unknown");
        return root.activeWindowState.xwayland ? qsTr("Yes") : qsTr("No");
    }

    title: qsTr("Focus Hub")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Current focus")
        }

        ConnectedRect {
            first: true
            last: true
            Layout.fillWidth: true
            implicitHeight: focusSummary.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: focusSummary

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    Layout.alignment: Qt.AlignTop
                    color: Colours.palette.m3primary
                    text: "desktop_windows"
                    fontStyle: Tokens.font.icon.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: root.activeWindowTitle
                        font: Tokens.font.title.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.activeWindowClass
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                }
            }
        }

        InfoRow {
            first: true
            label: qsTr("Active window title")
            value: root.activeWindowTitle
            icon: "web_asset"
            iconColour: Colours.palette.m3primary
        }

        InfoRow {
            label: qsTr("Window class / app id")
            value: root.activeWindowClass
            icon: "category"
            iconColour: Colours.palette.m3secondary
        }

        InfoRow {
            label: qsTr("Workspace")
            value: root.currentWorkspace
            icon: "workspaces"
            iconColour: Colours.palette.m3tertiary
        }

        InfoRow {
            last: true
            label: qsTr("Focused monitor")
            value: root.focusedMonitor
            icon: "desktop_windows"
            iconColour: Colours.palette.m3primary
        }

        SectionHeader {
            text: qsTr("Session snapshot")
        }

        InfoRow {
            first: true
            label: qsTr("Open toplevels")
            value: root.openToplevelCount
            icon: "web_asset"
            iconColour: Colours.palette.m3primary
        }

        InfoRow {
            label: qsTr("Workspaces")
            value: root.workspaceCount
            icon: "workspaces"
            iconColour: Colours.palette.m3secondary
        }

        InfoRow {
            label: qsTr("Monitors")
            value: root.monitorCount
            icon: "desktop_windows"
            iconColour: Colours.palette.m3tertiary
        }

        InfoRow {
            last: true
            label: qsTr("Focused workspace")
            value: root.currentWorkspace
            icon: "dashboard"
            iconColour: Colours.palette.m3primary
        }

        SectionHeader {
            text: qsTr("Window state")
        }

        InfoRow {
            first: true
            label: qsTr("Floating")
            value: root.floatingState
            icon: "picture_in_picture_center"
            iconColour: Colours.palette.m3primary
        }

        InfoRow {
            label: qsTr("Fullscreen")
            value: root.fullscreenState
            icon: "fullscreen"
            iconColour: Colours.palette.m3secondary
        }

        InfoRow {
            label: qsTr("Pinned")
            value: root.pinnedState
            icon: "keep"
            iconColour: Colours.palette.m3tertiary
        }

        InfoRow {
            last: true
            label: qsTr("XWayland")
            value: root.xwaylandState
            icon: "gradient"
            iconColour: Colours.palette.m3primary
        }
    }
}
