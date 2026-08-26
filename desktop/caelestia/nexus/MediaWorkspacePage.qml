pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.widgets
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var activePlayer: Players.active
    readonly property real trackLength: Number(activePlayer?.length ?? 0)
    readonly property bool hasValidLength: Number.isFinite(trackLength) && trackLength > 0 && trackLength <= 2147483647
    readonly property real trackPosition: {
        const position = Number(activePlayer?.position ?? 0);
        if (!Number.isFinite(position) || position < 0 || !root.hasValidLength)
            return 0;
        return Math.min(position, root.trackLength);
    }

    function formatDuration(seconds: real): string {
        if (!Number.isFinite(seconds) || seconds < 0)
            return qsTr("--:--");

        const totalSeconds = Math.floor(seconds);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const remainingSeconds = String(totalSeconds % 60).padStart(2, "0");

        if (hours > 0)
            return `${hours}:${String(minutes).padStart(2, "0")}:${remainingSeconds}`;
        return `${minutes}:${remainingSeconds}`;
    }

    title: qsTr("Media Workspace")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Now playing")
        }

        ConnectedRect {
            first: true
            last: true
            visible: root.activePlayer !== null
            Layout.fillWidth: true
            implicitHeight: nowPlayingLayout.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: nowPlayingLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.largeIncreased

                CoverArt {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: Math.min(Tokens.sizes.dashboard.mediaCoverArtSize, nowPlayingLayout.width / 3)
                    Layout.preferredHeight: Layout.preferredWidth
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: (root.activePlayer?.trackTitle ?? "") || qsTr("Unknown title")
                        font: Tokens.font.headline.small
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: (root.activePlayer?.trackArtist ?? "") || qsTr("Unknown artist")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.title.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: (root.activePlayer?.trackAlbum ?? "") || qsTr("Unknown album")
                        color: Colours.palette.m3outline
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.topMargin: Tokens.spacing.small
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "devices"
                            color: Colours.palette.m3secondary
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Players.getIdentity(root.activePlayer) || qsTr("Unknown player")
                            color: Colours.palette.m3secondary
                            font: Tokens.font.label.medium
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        ConnectedRect {
            first: true
            last: true
            visible: root.activePlayer === null
            Layout.fillWidth: true
            implicitHeight: emptyState.implicitHeight + Tokens.padding.extraLarge * 2

            ColumnLayout {
                id: emptyState

                anchors.centerIn: parent
                width: parent.width - Tokens.padding.extraLarge * 2
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "music_off"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.extraLarge
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Nothing is playing")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.title.medium
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Media will appear here when an MPRIS-capable player starts.")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
            }
        }

        SectionHeader {
            visible: root.activePlayer !== null
            text: qsTr("Playback progress")
        }

        ConnectedRect {
            first: true
            last: true
            visible: root.activePlayer !== null
            Layout.fillWidth: true
            implicitHeight: progressLayout.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: progressLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.small

                StyledProgressBar {
                    Layout.fillWidth: true
                    value: root.hasValidLength ? root.trackPosition / root.trackLength : 0
                    implicitHeight: Tokens.padding.small
                    fgColour: root.hasValidLength ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                    bgColour: Colours.palette.m3secondaryContainer
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: root.hasValidLength ? root.formatDuration(root.trackPosition) : qsTr("--:--")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: root.hasValidLength ? root.formatDuration(root.trackLength) : qsTr("Length unavailable")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }
                }
            }
        }

        SectionHeader {
            visible: root.activePlayer !== null
            text: qsTr("Playback controls")
        }

        ConnectedRect {
            first: true
            last: true
            visible: root.activePlayer !== null
            Layout.fillWidth: true
            implicitHeight: controls.implicitHeight + Tokens.padding.large * 2

            ButtonRow {
                id: controls

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.extraLarge
                spacing: Tokens.spacing.small

                IconButton {
                    type: IconButton.Tonal
                    icon: "skip_previous"
                    isRound: true
                    shapeMorph: true
                    font: Tokens.font.icon.large
                    disabled: !root.activePlayer?.canGoPrevious
                    onClicked: {
                        const active = Players.active;
                        if (active?.canGoPrevious)
                            active.previous();
                    }
                }

                IconButton {
                    fillWidth: true
                    icon: root.activePlayer?.isPlaying ? "pause" : "play_arrow"
                    isRound: true
                    shapeMorph: true
                    checked: root.activePlayer?.isPlaying ?? false
                    font: Tokens.font.icon.large
                    disabled: !root.activePlayer?.canTogglePlaying
                    onClicked: {
                        const active = Players.active;
                        if (active?.canTogglePlaying)
                            active.togglePlaying();
                    }
                }

                IconButton {
                    type: IconButton.Tonal
                    icon: "skip_next"
                    isRound: true
                    shapeMorph: true
                    font: Tokens.font.icon.large
                    disabled: !root.activePlayer?.canGoNext
                    onClicked: {
                        const active = Players.active;
                        if (active?.canGoNext)
                            active.next();
                    }
                }
            }
        }

        SectionHeader {
            visible: Players.list.length > 0
            text: qsTr("Player")
        }

        ConnectedRect {
            first: true
            last: true
            visible: Players.list.length > 0
            Layout.fillWidth: true
            implicitHeight: playerSelector.implicitHeight + Tokens.padding.large * 2

            SplitButton {
                id: playerSelector

                anchors.centerIn: parent
                type: SplitButton.Tonal
                disabled: !Players.list.length
                active: menuItems.find(item => item.modelData === Players.active) ?? menuItems[0] ?? null
                menu.onItemSelected: item => Players.manualActive = (item as PlayerItem).modelData

                menuItems: playerList.instances
                fallbackIcon: "music_off"
                fallbackText: qsTr("No players")
                minLeftWidth: Math.min(Tokens.sizes.nexus.popupWidth, root.cappedWidth - expandBtn.implicitWidth - spacing)

                label.Layout.maximumWidth: minLeftWidth - iconLabel.implicitWidth - textRow.spacing - horizontalPadding * 2
                label.elide: Text.ElideRight
                stateLayer.disabled: true
                menuOnTop: true

                Variants {
                    id: playerList

                    model: Players.list

                    PlayerItem {}
                }
            }
        }
    }

    component PlayerItem: MenuItem {
        required property MprisPlayer modelData

        icon: modelData === Players.active ? "check" : ""
        text: Players.getIdentity(modelData) || qsTr("Unknown player")
        activeIcon: "animated_images"
    }
}
