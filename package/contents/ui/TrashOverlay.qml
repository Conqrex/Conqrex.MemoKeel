import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T
import "../code/format.js" as Fmt

// Recoverable trash: list deleted items, restore individually or empty the lot.
Rectangle {
    id: ov
    property var controller
    property double nowMs: 0
    signal closed()

    color: Qt.rgba(0, 0, 0, 0.55)
    MouseArea { anchors.fill: parent; onClicked: ov.closed() }

    QN.NeonCard {
        anchors.centerIn: parent
        width: Math.min(parent.width - Kirigami.Units.gridUnit, Kirigami.Units.gridUnit * 22)
        height: Math.min(parent.height - Kirigami.Units.gridUnit, Kirigami.Units.gridUnit * 22)
        accent: Kirigami.Theme.negativeTextColor
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.smallSpacing
            anchors.topMargin: Kirigami.Units.smallSpacing
            anchors.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: "user-trash"; Layout.preferredWidth: Kirigami.Units.iconSizes.medium; Layout.preferredHeight: Kirigami.Units.iconSizes.medium }
                Kirigami.Heading { level: 4; text: i18n("Trash"); Layout.fillWidth: true; color: T.QN.text }
                QQC2.ToolButton {
                    icon.name: "trash-empty"; text: i18n("Empty"); display: QQC2.AbstractButton.TextBesideIcon
                    flat: true; font: Kirigami.Theme.smallFont
                    visible: ov.controller && ov.controller.doc && ov.controller.doc.trash.length > 0
                    onClicked: ov.controller.emptyTrash()
                }
                QQC2.ToolButton { icon.name: "window-close"; flat: true; onClicked: ov.closed() }
            }

            QN.EmptyState {
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: !ov.controller || !ov.controller.doc || ov.controller.doc.trash.length === 0
                icon: "user-trash"; title: i18n("Trash is empty")
            }

            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: Kirigami.Units.smallSpacing * 0.5
                visible: ov.controller && ov.controller.doc && ov.controller.doc.trash.length > 0
                model: ov.controller && ov.controller.doc ? ov.controller.doc.trash : []
                QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: row.implicitHeight + Kirigami.Units.smallSpacing
                    radius: Kirigami.Units.smallSpacing
                    color: T.QN.alpha(T.QN.text, 0.06)
                    RowLayout {
                        id: row
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            source: ({ note: "view-pim-notes", todo: "view-pim-tasks", card: "view-calendar-tasks",
                                       column: "view-calendar-tasks", reminder: "appointment-reminder" })[modelData.item.type] || "edit-delete"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: modelData.item.title || modelData.item.text || i18n("(untitled %1)", modelData.item.type)
                            elide: Text.ElideRight
                            color: T.QN.text
                        }
                        PlasmaComponents.Label {
                            text: Fmt.dateTimeShort(modelData.deletedAt, true)
                            color: T.QN.textFaint; font: Kirigami.Theme.smallFont
                        }
                        QQC2.ToolButton {
                            icon.name: "edit-undo"; flat: true
                            onClicked: ov.controller.restoreItem(modelData.item.id)
                            QQC2.ToolTip.text: i18n("Restore"); QQC2.ToolTip.visible: hovered
                        }
                    }
                }
            }
        }
    }
}
