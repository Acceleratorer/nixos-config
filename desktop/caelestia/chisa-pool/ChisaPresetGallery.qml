pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.images
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: qsTr("Chisa presets")
    isSubPage: true
    focus: true

    property string pendingPresetId: ChisaPresets.selectedPresetId
    property bool hasPreview
    readonly property var pendingPreset: ChisaPresets.presets.find(preset => preset.id === root.pendingPresetId) ?? ChisaPresets.presets[0]
    readonly property bool canApply: root.hasPreview && root.pendingPreset

    function selectPreset(preset: var): void {
        if (!preset)
            return;

        pendingPresetId = preset.id;
        hasPreview = true;
        ChisaPresets.preview(preset);
        forceActiveFocus();
    }

    function moveSelection(step: int): void {
        const current = ChisaPresets.presets.findIndex(preset => preset.id === pendingPresetId);
        const next = (current + step + ChisaPresets.presets.length) % ChisaPresets.presets.length;
        selectPreset(ChisaPresets.presets[next]);
    }

    function applyPending(): void {
        if (!canApply)
            return;

        ChisaPresets.apply(pendingPreset);
        nState.closeSubPage();
    }

    Component.onCompleted: forceActiveFocus()
    Component.onDestruction: ChisaPresets.stopPreview()

    Keys.onEscapePressed: event => {
        nState.closeSubPage();
        event.accepted = true;
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
        case Qt.Key_Up:
            moveSelection(-1);
            event.accepted = true;
            break;
        case Qt.Key_Right:
        case Qt.Key_Down:
            moveSelection(1);
            event.accepted = true;
            break;
        case Qt.Key_Space:
            selectPreset(pendingPreset);
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (hasPreview)
                applyPending();
            else
                selectPreset(pendingPreset);
            event.accepted = true;
            break;
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Select a preset to preview it. Apply confirms the wallpaper and its Chisa accents.")
            color: ChisaPresets.muted
            font: Tokens.font.body.medium
            wrapMode: Text.WordWrap
        }

        StyledRect {
            Layout.fillWidth: true
            color: Qt.alpha(ChisaPresets.deepSurface, 0.9)
            radius: Tokens.rounding.extraLarge
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)
            implicitHeight: presetGrid.implicitHeight + Tokens.padding.large * 2

            GridLayout {
                id: presetGrid

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                columns: Math.max(1, Math.min(2, Math.floor(width / 280)))
                rowSpacing: Tokens.spacing.medium
                columnSpacing: Tokens.spacing.medium

                Repeater {
                    model: ChisaPresets.presets

                    ButtonBase {
                        id: tile

                        required property int index
                        required property var modelData

                        Layout.fillWidth: true
                        implicitWidth: 260
                        implicitHeight: tileContent.implicitHeight + Tokens.padding.medium * 2
                        checked: root.pendingPresetId === modelData.id
                        isRound: false
                        radiusMorph: false
                        type: ButtonBase.Tonal
                        activeColour: Qt.alpha(ChisaPresets.cyan, 0.18)
                        inactiveColour: Qt.alpha(ChisaPresets.deepSurface, 0.72)
                        activeOnColour: ChisaPresets.foreground
                        inactiveOnColour: ChisaPresets.foreground
                        border.width: checked ? (root.activeFocus ? 3 : 2) : 1
                        border.color: checked ? ChisaPresets.cyan : Qt.rgba(1, 1, 1, 0.14)

                        onClicked: root.selectPreset(modelData)

                        ColumnLayout {
                            id: tileContent

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            spacing: Tokens.spacing.small

                            StyledClippingRect {
                                Layout.fillWidth: true
                                implicitHeight: width * 960 / 2048
                                color: ChisaPresets.deepSurface
                                radius: Tokens.rounding.large

                                CachingImage {
                                    anchors.fill: parent
                                    anchors.margins: Tokens.padding.extraSmall
                                    path: tile.modelData.thumbnail
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    text: tile.checked ? "check_circle" : "wallpaper"
                                    color: tile.checked ? ChisaPresets.cyan : ChisaPresets.lavender
                                    fill: tile.checked ? 1 : 0
                                    fontStyle: Tokens.font.icon.medium
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: tile.modelData.name
                                        color: ChisaPresets.foreground
                                        font: Tokens.font.title.small
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: root.hasPreview && tile.checked ? qsTr("Preview selected") : ChisaPresets.selectedPresetId === tile.modelData.id ? qsTr("Applied") : qsTr("Select to preview")
                                        color: ChisaPresets.muted
                                        font: Tokens.font.label.medium
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        Behavior on border.width {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 180
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: hasPreview
            text: qsTr("Previewing %1. Apply to keep this wallpaper.").arg(pendingPreset.name)
            color: ChisaPresets.foreground
            font: Tokens.font.body.medium
            wrapMode: Text.WordWrap
        }

        IconTextButton {
            Layout.alignment: Qt.AlignRight
            icon: "check"
            text: qsTr("Apply")
            font: Tokens.font.body.large
            type: IconTextButton.Filled
            isRound: true
            disabled: !root.canApply
            inactiveColour: ChisaPresets.cyan
            inactiveOnColour: ChisaPresets.deepSurface
            activeColour: ChisaPresets.cyan
            activeOnColour: ChisaPresets.deepSurface
            onClicked: root.applyPending()
        }
    }
}
