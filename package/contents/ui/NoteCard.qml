import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
import "../code/theme.js" as Theme
import "../code/markdown.js" as Md

// A single note in the list: glassy card tinted by the note's color, with a
// title, markdown preview, checklist progress, tag chips, attachment count and
// a hover toolbar (pin / color / archive / delete).
QN.NeonCard {
    id: card

    property var controller
    property var note
    property var tagsMap: ({})
    property double nowMs: 0
    property bool use24h: true
    property color accentFallback: Kirigami.Theme.highlightColor

    signal openRequested(string id)
    signal tagActivated(string tagId)

    readonly property var progress: Md.checklistProgress(note.body)
    accent: Theme.accentFor(note.color, accentFallback)
    hovered: hover.hovered
    implicitHeight: layout.implicitHeight + Kirigami.Units.smallSpacing * 2
    opacity: note.archived ? 0.6 : 1

    HoverHandler { id: hover }
    TapHandler { onTapped: card.openRequested(card.note.id) }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing * 1.8
        anchors.rightMargin: Kirigami.Units.smallSpacing
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.bottomMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing * 0.6

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                visible: card.note.pinned
                source: "bookmarks"
                color: card.accent
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: card.note.title !== "" ? card.note.title : i18n("Untitled")
                font.bold: true
                opacity: card.note.title !== "" ? 1 : 0.5
                elide: Text.ElideRight
            }
            // hover toolbar
            Row {
                spacing: 0
                opacity: hover.hovered ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                QQC2.ToolButton {
                    icon.name: card.note.pinned ? "bookmark-remove" : "bookmarks"
                    flat: true; icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                    onClicked: card.controller.togglePin(card.note.id)
                    QQC2.ToolTip.text: card.note.pinned ? i18n("Unpin") : i18n("Pin"); QQC2.ToolTip.visible: hovered
                }
                QQC2.ToolButton {
                    icon.name: "color-management"
                    flat: true; icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                    onClicked: colorMenu.open()
                    QQC2.ToolTip.text: i18n("Color"); QQC2.ToolTip.visible: hovered
                    QQC2.Popup {
                        id: colorMenu
                        y: parent.height; width: contentItem.implicitWidth + Kirigami.Units.smallSpacing * 2
                        QN.ColorPicker {
                            selected: card.note.color
                            onPicked: (k) => { card.controller.setColor("notes", card.note.id, k); colorMenu.close(); }
                        }
                    }
                }
                QQC2.ToolButton {
                    icon.name: card.note.archived ? "archive-remove" : "archive-insert"
                    flat: true; icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                    onClicked: card.controller.setArchived("notes", card.note.id, !card.note.archived)
                    QQC2.ToolTip.text: card.note.archived ? i18n("Unarchive") : i18n("Archive"); QQC2.ToolTip.visible: hovered
                }
                QQC2.ToolButton {
                    icon.name: "edit-delete"
                    flat: true; icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                    onClicked: card.controller.deleteItem("notes", card.note.id)
                    QQC2.ToolTip.text: i18n("Delete"); QQC2.ToolTip.visible: hovered
                }
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: Md.plainPreview(card.note.body, 200)
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            opacity: 0.75
            font: Kirigami.Theme.smallFont
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: card.progress.total > 0 || (card.note.attachmentIds && card.note.attachmentIds.length > 0)

            RowLayout {
                visible: card.progress.total > 0
                spacing: 3
                Kirigami.Icon { source: "checkbox"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small; opacity: 0.7 }
                PlasmaComponents.Label {
                    text: card.progress.done + "/" + card.progress.total
                    font: Kirigami.Theme.smallFont; opacity: 0.7
                    color: card.progress.done === card.progress.total ? Theme.PALETTE.lime : Kirigami.Theme.textColor
                }
            }
            RowLayout {
                visible: card.note.attachmentIds && card.note.attachmentIds.length > 0
                spacing: 3
                Kirigami.Icon { source: "mail-attachment"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small; opacity: 0.7 }
                PlasmaComponents.Label { text: card.note.attachmentIds.length; font: Kirigami.Theme.smallFont; opacity: 0.7 }
            }
            Item { Layout.fillWidth: true }
        }

        // tag chips
        Flow {
            Layout.fillWidth: true
            visible: card.note.tagIds && card.note.tagIds.length > 0
            spacing: Kirigami.Units.smallSpacing * 0.6
            Repeater {
                model: card.note.tagIds || []
                delegate: QN.TagChip {
                    required property var modelData
                    readonly property var tag: card.tagsMap[modelData]
                    visible: !!tag
                    tagName: tag ? tag.name : ""
                    tagColor: tag ? Theme.accentFor(tag.color, card.accentFallback) : card.accentFallback
                    onClicked: card.tagActivated(modelData)
                }
            }
        }
    }
}
