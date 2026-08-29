pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.images
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: qsTr("Theme packs")
    isSubPage: true
    subPageCloseEnabled: !applying
    focus: true

    readonly property string runtimeRoot: "@THEME_RUNTIME_ROOT@"
    property list<var> packs: []
    property int selectedIndex
    readonly property var selectedPack: packs[selectedIndex] ?? null
    property string requestedPreviewId
    property string previewedPackId
    property string previewSchemeData
    property string committedPackId
    property bool previewLoading
    property bool applying
    property bool applyProcessExited
    property string feedback
    property bool feedbackIsError
    readonly property bool hasPreview: previewedPackId.length > 0
    readonly property bool canApply: !applying && !previewLoading && selectedPack !== null && previewedPackId === selectedPack.id && isSupportedPackId(selectedPack.id)

    function isSupportedPackId(packId: string): bool {
        return packId === "neutral" || packId === "cryoforge-denia";
    }

    function inferCommittedPackId(): string {
        const packId = Colours.cryoforgePackId;
        return Colours.scheme === "cryoforge-pack" && Colours.flavour === packId && isSupportedPackId(packId) ? packId : "";
    }

    function schemePath(pack: var): string {
        return `${runtimeRoot}/schemes/${pack.id}.json`;
    }

    function assetPath(relativePath: var): string {
        return relativePath ? `${runtimeRoot}/${relativePath}` : "";
    }

    function cancelPreview(): void {
        requestedPreviewId = "";
        previewedPackId = "";
        previewSchemeData = "";
        previewLoading = false;
        previewSchemeFile.path = "";
        Wallpapers.stopPreview();
        Wallpapers.previewColourLock = false;
        Colours.showPreview = false;
    }

    function closeWithoutApplying(): void {
        if (applying)
            return;

        cancelPreview();
        nState.closeSubPage();
    }

    function selectIndex(index: int, preview: bool): void {
        if (applying || index < 0 || index >= packs.length)
            return;

        selectedIndex = index;
        feedback = "";
        feedbackIsError = false;
        if (preview)
            requestPreview(selectedPack);
        forceActiveFocus();
    }

    function moveSelection(step: int): void {
        if (!packs.length)
            return;

        selectIndex(Math.max(0, Math.min(packs.length - 1, selectedIndex + step)), false);
    }

    function requestPreview(pack: var): void {
        if (applying || !pack || !isSupportedPackId(pack.id))
            return;

        requestedPreviewId = pack.id;
        previewedPackId = "";
        previewSchemeData = "";
        previewLoading = true;
        feedback = qsTr("Loading preview…");
        feedbackIsError = false;
        previewSchemeFile.path = schemePath(pack);
    }

    function applyPending(): void {
        if (!canApply)
            return;

        applying = true;
        applyProcessExited = false;
        feedback = qsTr("Applying %1…").arg(selectedPack.displayName);
        feedbackIsError = false;
        applyProcess.exec(["@THEME_APPLY_HELPER@", selectedPack.id]);
    }

    function reportApplyFailure(message: string): void {
        applying = false;
        feedback = message || qsTr("Could not apply this theme pack.");
        feedbackIsError = true;
        forceActiveFocus();
    }

    Component.onCompleted: forceActiveFocus()
    Component.onDestruction: cancelPreview()

    Keys.onEscapePressed: event => {
        closeWithoutApplying();
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
            requestPreview(selectedPack);
            event.accepted = true;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (canApply)
                applyPending();
            else
                requestPreview(selectedPack);
            event.accepted = true;
            break;
        }
    }

    property Connections schemeObserver: Connections {
        function onSchemeChanged(): void {
            root.committedPackId = root.inferCommittedPackId();
        }

        function onFlavourChanged(): void {
            root.committedPackId = root.inferCommittedPackId();
        }

        function onCryoforgePackIdChanged(): void {
            root.committedPackId = root.inferCommittedPackId();
        }

        target: Colours
    }

    property Connections subPageObserver: Connections {
        function onSubPageClosed(): void {
            root.cancelPreview();
        }

        target: root.nState
    }

    property FileView registrySource: FileView {
        id: registryFile

        path: `${root.runtimeRoot}/registry.json`
        printErrors: false
        onLoaded: {
            try {
                const registry = JSON.parse(text());
                const loadedPacks = registry.packs ?? [];
                const valid = registry.schemaVersion === 1 && registry.defaultPackId === "neutral" && loadedPacks.length === 2 && loadedPacks[0]?.id === "neutral" && loadedPacks[1]?.id === "cryoforge-denia";
                if (!valid)
                    throw new Error("unexpected registry");

                root.packs = loadedPacks;
                root.selectedIndex = Math.max(0, loadedPacks.findIndex(pack => pack.id === root.inferCommittedPackId()));
                root.committedPackId = root.inferCommittedPackId();
                root.feedback = "";
                root.feedbackIsError = false;
            } catch (error) {
                root.packs = [];
                root.feedback = qsTr("Theme packs are unavailable.");
                root.feedbackIsError = true;
            }
        }
        onLoadFailed: {
            root.packs = [];
            root.feedback = qsTr("Theme packs are unavailable.");
            root.feedbackIsError = true;
        }
    }

    property FileView previewSchemeSource: FileView {
        id: previewSchemeFile

        printErrors: false
        onLoaded: {
            const pack = root.packs.find(candidate => candidate.id === root.requestedPreviewId);
            if (!pack || path !== root.schemePath(pack))
                return;

            try {
                const data = text();
                const scheme = JSON.parse(data);
                if (scheme.mode !== "dark" || !scheme.colours)
                    throw new Error("invalid fixed scheme");

                Wallpapers.previewColourLock = true;
                if (pack.wallpaper)
                    Wallpapers.preview(root.assetPath(pack.wallpaper));
                else
                    Wallpapers.stopPreview();

                Colours.load(data, true);
                Colours.showPreview = true;
                root.previewSchemeData = data;
                root.previewedPackId = pack.id;
                root.previewLoading = false;
                root.feedback = pack.wallpaper ? qsTr("Previewing %1. Apply to keep its wallpaper and palette.").arg(pack.displayName) : qsTr("Previewing %1. Neutral keeps the current wallpaper.").arg(pack.displayName);
                root.feedbackIsError = false;
            } catch (error) {
                root.cancelPreview();
                root.feedback = qsTr("Could not load this fixed preview.");
                root.feedbackIsError = true;
            }
        }
        onLoadFailed: {
            root.cancelPreview();
            root.feedback = qsTr("Could not load this fixed preview.");
            root.feedbackIsError = true;
        }
    }

    property Process applyRunner: Process {
        id: applyProcess

        stdout: StdioCollector {
            id: applyOutput
        }

        stderr: StdioCollector {
            id: applyError
        }

        onRunningChanged: {
            if (running) {
                root.applyProcessExited = false;
                return;
            }
            if (root.applying && !root.applyProcessExited)
                root.reportApplyFailure(qsTr("Could not start the theme apply helper."));
        }

        onExited: code => { // qmllint disable signal-handler-parameters
            root.applyProcessExited = true;
            if (code !== 0) {
                const detail = applyError.text.trim();
                root.reportApplyFailure(detail ? detail.replace(/^cryoforge-theme-error:\s*/, "") : qsTr("Could not apply this theme pack."));
                return;
            }

            try {
                const result = JSON.parse(applyOutput.text.trim());
                if (!result.ok || result.packId !== root.previewedPackId)
                    throw new Error("unexpected helper result");

                Colours.load(root.previewSchemeData, false);
                root.committedPackId = result.packId;
                root.applying = false;
                root.cancelPreview();
                root.nState.closeSubPage();
            } catch (error) {
                root.reportApplyFailure(qsTr("The theme helper returned an invalid result."));
            }
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Choose a pack to preview its fixed palette. Nothing is saved until you explicitly apply it.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
            wrapMode: Text.WordWrap
        }

        GridLayout {
            id: packGrid

            Layout.fillWidth: true
            columns: Math.max(1, Math.min(2, Math.floor(width / 280)))
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.medium

            Repeater {
                model: root.packs

                ButtonBase {
                    id: tile

                    required property int index
                    required property var modelData
                    readonly property bool selected: root.selectedIndex === index
                    readonly property bool previewed: root.previewedPackId === modelData.id
                    readonly property bool applied: root.committedPackId === modelData.id

                    Layout.fillWidth: true
                    implicitWidth: 260
                    implicitHeight: tileContent.implicitHeight + Tokens.padding.medium * 2
                    checked: selected
                    isRound: false
                    radiusMorph: false
                    type: ButtonBase.Tonal
                    activeColour: Colours.tPalette.m3surfaceContainerHigh
                    inactiveColour: Colours.tPalette.m3surfaceContainer
                    activeOnColour: Colours.palette.m3onSurface
                    inactiveOnColour: Colours.palette.m3onSurface
                    border.width: selected ? (root.activeFocus ? 3 : 2) : 1
                    border.color: selected ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                    disabled: root.applying

                    onClicked: root.selectIndex(index, true)

                    ColumnLayout {
                        id: tileContent

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.small

                        StyledClippingRect {
                            Layout.fillWidth: true
                            implicitHeight: width * 0.48
                            color: Colours.tPalette.m3surfaceContainerLow
                            radius: Tokens.rounding.large

                            CachingImage {
                                anchors.fill: parent
                                anchors.margins: Tokens.padding.extraSmall
                                visible: tile.modelData.preview.thumbnail !== null
                                path: root.assetPath(tile.modelData.preview.thumbnail)
                                fillMode: Image.PreserveAspectFit
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width - Tokens.padding.large * 2
                                visible: tile.modelData.preview.thumbnail === null
                                spacing: Tokens.spacing.extraSmall

                                MaterialIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "wallpaper"
                                    color: Colours.palette.m3secondary
                                    fontStyle: Tokens.font.icon.extraLarge
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: qsTr("Keeps current wallpaper")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.medium
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: tile.applied ? "verified" : tile.previewed ? "visibility" : "palette"
                                color: tile.applied ? Colours.palette.m3primary : tile.previewed ? Colours.palette.m3secondary : Colours.palette.m3outline
                                fill: tile.applied || tile.previewed ? 1 : 0
                                fontStyle: Tokens.font.icon.medium
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: tile.modelData.displayName
                                    color: Colours.palette.m3onSurface
                                    font: Tokens.font.title.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: tile.applied ? qsTr("Applied") : tile.previewed ? qsTr("Preview loaded") : tile.selected ? qsTr("Press Space to preview") : qsTr("Select to preview")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.medium
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: tile.modelData.preview.description
                            color: Colours.palette.m3outline
                            font: Tokens.font.body.small
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.extraSmall

                            Repeater {
                                model: tile.modelData.preview.swatches

                                StyledRect {
                                    required property string modelData

                                    implicitWidth: Tokens.padding.large
                                    implicitHeight: implicitWidth
                                    radius: Tokens.rounding.full
                                    color: tile.modelData.palette[modelData]
                                    border.width: 1
                                    border.color: Colours.palette.m3outline
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.feedback.length > 0
            text: root.feedback
            color: root.feedbackIsError ? Colours.palette.m3error : Colours.palette.m3onSurface
            font: Tokens.font.body.medium
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: Tokens.spacing.small

            IconTextButton {
                icon: "close"
                text: qsTr("Cancel")
                font: Tokens.font.body.large
                type: IconTextButton.Tonal
                isRound: true
                disabled: root.applying
                onClicked: root.closeWithoutApplying()
            }

            IconTextButton {
                icon: root.applying ? "hourglass_top" : "check"
                text: root.applying ? qsTr("Applying…") : qsTr("Apply")
                font: Tokens.font.body.large
                type: IconTextButton.Filled
                isRound: true
                disabled: !root.canApply
                onClicked: root.applyPending()
            }
        }
    }
}
