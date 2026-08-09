import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T
import "../code/theme.js" as Theme

// One to-do: status circle (todo → doing → done), inline-editable text, the
// priority / due / tag strip and the hover actions. Shared verbatim by the
// To-Do mode list and the dashboard's to-do pane, so a task looks and behaves
// the same wherever it is shown.
QN.NeonCard {
    id: row

    property var controller
    property var todo
    // id -> tag record; the row never reaches into the document itself.
    property var tagsMap: ({})
    property double nowMs: 0
    property bool use24h: true
    property color accentFallback: Kirigami.Theme.highlightColor

    signal tagActivated(string tagId)

    readonly property bool done: todo.status === "done"

    implicitHeight: rl.implicitHeight + Kirigami.Units.smallSpacing * 1.5
    accent: todo.priority > 0 ? Theme.priorityColor(todo.priority, row.accentFallback)
                              : Theme.accentFor(todo.color, row.accentFallback)
    hovered: rowHover.hovered
    opacity: row.done ? 0.6 : 1
    HoverHandler { id: rowHover }

    RowLayout {
        id: rl
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing * 1.6
        anchors.rightMargin: Kirigami.Units.smallSpacing
        anchors.topMargin: Kirigami.Units.smallSpacing * 0.75
        anchors.bottomMargin: Kirigami.Units.smallSpacing * 0.75
        spacing: Kirigami.Units.smallSpacing

        // status circle: todo (empty) -> doing (amber dot) -> done (lime check)
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: Kirigami.Units.iconSizes.smallMedium
            height: width
            radius: width / 2
            color: row.done ? Theme.PALETTE.lime : "transparent"
            border.width: 2
            border.color: row.done ? Theme.PALETTE.lime
                         : (row.todo.status === "doing" ? Theme.PALETTE.amber : row.accentFallback)
            Rectangle {
                visible: row.todo.status === "doing"
                anchors.centerIn: parent
                width: parent.width * 0.5; height: width; radius: width / 2
                color: Theme.PALETTE.amber
            }
            Text {
                anchors.centerIn: parent
                visible: row.done
                text: "✓"; color: "#0b0f1a"; font.bold: true
                font.pixelSize: parent.height * 0.7
            }
            TapHandler { onTapped: row.controller.cycleTodo(row.todo.id) }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            QQC2.TextField {
                Layout.fillWidth: true
                text: row.todo.text
                background: null
                color: T.QN.text
                placeholderTextColor: T.QN.textFaint
                font.strikeout: row.done
                onEditingFinished: if (text !== row.todo.text) row.controller.updateItem("todos", row.todo.id, { text: text })
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing * 0.6
                visible: row.todo.priority > 0 || row.todo.dueAt || (row.todo.tagIds && row.todo.tagIds.length > 0)
                QN.PriorityBadge { priority: row.todo.priority }
                QN.DueBadge { iso: row.todo.dueAt || ""; nowMs: row.nowMs; use24h: row.use24h }
                Repeater {
                    model: row.todo.tagIds || []
                    delegate: QN.TagChip {
                        required property var modelData
                        readonly property var tag: row.tagsMap[modelData]
                        visible: !!tag
                        tagName: tag ? tag.name : ""
                        tagColor: tag ? Theme.accentFor(tag.color, row.accentFallback) : row.accentFallback
                        onClicked: row.tagActivated(modelData)
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }

        // actions
        Row {
            spacing: 0
            QQC2.ToolButton {
                icon.name: "flag"; flat: true
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                onClicked: prioMenu.open()
                QQC2.Menu {
                    id: prioMenu
                    QQC2.MenuItem { text: i18n("Urgent"); onTriggered: row.controller.setPriority("todos", row.todo.id, 4) }
                    QQC2.MenuItem { text: i18n("High"); onTriggered: row.controller.setPriority("todos", row.todo.id, 3) }
                    QQC2.MenuItem { text: i18n("Medium"); onTriggered: row.controller.setPriority("todos", row.todo.id, 2) }
                    QQC2.MenuItem { text: i18n("Low"); onTriggered: row.controller.setPriority("todos", row.todo.id, 1) }
                    QQC2.MenuItem { text: i18n("None"); onTriggered: row.controller.setPriority("todos", row.todo.id, 0) }
                }
            }
            QQC2.ToolButton {
                icon.name: "appointment-new"; flat: true
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                onClicked: dueMenu.open()
                QQC2.Menu {
                    id: dueMenu
                    QQC2.MenuItem { text: i18n("In 1 hour"); onTriggered: row.controller.setDue("todos", row.todo.id, new Date(Date.now() + 3600000).toISOString()) }
                    QQC2.MenuItem { text: i18n("This evening"); onTriggered: { var d = new Date(); d.setHours(18, 0, 0, 0); row.controller.setDue("todos", row.todo.id, d.toISOString()); } }
                    QQC2.MenuItem { text: i18n("Tomorrow"); onTriggered: { var d = new Date(); d.setDate(d.getDate() + 1); d.setHours(9, 0, 0, 0); row.controller.setDue("todos", row.todo.id, d.toISOString()); } }
                    QQC2.MenuItem { text: i18n("Next week"); onTriggered: { var d = new Date(); d.setDate(d.getDate() + 7); d.setHours(9, 0, 0, 0); row.controller.setDue("todos", row.todo.id, d.toISOString()); } }
                    QQC2.MenuSeparator {}
                    QQC2.MenuItem { text: i18n("Clear due date"); onTriggered: row.controller.setDue("todos", row.todo.id, null) }
                }
            }
            QQC2.ToolButton {
                icon.name: row.todo.archived ? "archive-remove" : "archive-insert"; flat: true
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                opacity: rowHover.hovered ? 1 : 0
                onClicked: row.controller.setArchived("todos", row.todo.id, !row.todo.archived)
            }
            QQC2.ToolButton {
                icon.name: "edit-delete"; flat: true
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                opacity: rowHover.hovered ? 1 : 0
                onClicked: row.controller.deleteItem("todos", row.todo.id)
            }
        }
    }
}
