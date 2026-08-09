import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T
import "../code/model.js" as Model
import "../code/search.js" as Search
import "../code/theme.js" as Theme
import "../code/format.js" as Fmt

// To-Do mode: status-cycling checklist with priority, due dates and tags.
ColumnLayout {
    id: view

    property var controller
    property double nowMs: 0
    property bool use24h: true
    property color accent: Kirigami.Theme.highlightColor
    property string query: ""
    property string tagFilter: ""

    signal tagActivated(string tagId)

    spacing: Kirigami.Units.smallSpacing

    function statusRank(s) { return s === "done" ? 2 : (s === "doing" ? 0 : 1); }
    function computeItems(doc, q, tag, showArchived) {
        if (!doc) return [];
        var list = Model.visibleItems(doc.todos, { showArchived: showArchived, tagId: tag });
        if (q && q.trim() !== "") return Search.rank(q, list, doc.tags);
        return list.slice().sort(function (a, b) {
            var sr = statusRank(a.status) - statusRank(b.status);
            if (sr !== 0) return sr;
            if ((b.priority || 0) !== (a.priority || 0)) return (b.priority || 0) - (a.priority || 0);
            var ad = a.dueAt ? new Date(a.dueAt).getTime() : 8640000000000000;
            var bd = b.dueAt ? new Date(b.dueAt).getTime() : 8640000000000000;
            if (ad !== bd) return ad - bd;
            return new Date(b.updatedAt) - new Date(a.updatedAt);
        });
    }
    readonly property var items: computeItems(controller ? controller.doc : null, query, tagFilter,
                                              Plasmoid.configuration.showArchived)
    readonly property int openCount: {
        var n = 0;
        for (var i = 0; i < items.length; i++) if (items[i].status !== "done") n++;
        return n;
    }

    RowLayout {
        Layout.fillWidth: true
        PlasmaComponents.Label {
            text: i18np("%1 open", "%1 open", view.openCount)
            color: T.QN.textDim; font: Kirigami.Theme.smallFont
        }
        Item { Layout.fillWidth: true }
        QQC2.ToolButton {
            icon.name: "archive-insert"; flat: true; checkable: true
            checked: Plasmoid.configuration.showArchived
            onToggled: Plasmoid.configuration.showArchived = checked
            QQC2.ToolTip.text: i18n("Show archived"); QQC2.ToolTip.visible: hovered
        }
    }

    QN.EmptyState {
        Layout.fillWidth: true; Layout.fillHeight: true
        visible: view.items.length === 0
        icon: "view-pim-tasks"
        title: view.query !== "" || view.tagFilter !== "" ? i18n("No matching to-dos") : i18n("Nothing to do")
        hint: i18n("Add a task above. Try #tag, !urgent or ^tomorrow.")
    }

    ListView {
        id: list
        visible: view.items.length > 0
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; spacing: Kirigami.Units.smallSpacing * 0.6
        model: view.items
        QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: tvBar }

        delegate: QN.NeonCard {
            id: row
            required property var modelData
            readonly property bool done: modelData.status === "done"
            width: list.width - (tvBar.visible ? Kirigami.Units.gridUnit : 0)
            implicitHeight: rl.implicitHeight + Kirigami.Units.smallSpacing * 1.5
            accent: modelData.priority > 0 ? Theme.priorityColor(modelData.priority, view.accent)
                                           : Theme.accentFor(modelData.color, view.accent)
            hovered: rowHover.hovered
            opacity: done ? 0.6 : 1
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
                                 : (row.modelData.status === "doing" ? Theme.PALETTE.amber : view.accent)
                    Rectangle {
                        visible: row.modelData.status === "doing"
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
                    TapHandler { onTapped: view.controller.cycleTodo(row.modelData.id) }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    QQC2.TextField {
                        Layout.fillWidth: true
                        text: row.modelData.text
                        background: null
                        color: T.QN.text
                        placeholderTextColor: T.QN.textFaint
                        font.strikeout: row.done
                        onEditingFinished: if (text !== row.modelData.text) view.controller.updateItem("todos", row.modelData.id, { text: text })
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing * 0.6
                        visible: modelData.priority > 0 || modelData.dueAt || (modelData.tagIds && modelData.tagIds.length > 0)
                        QN.PriorityBadge { priority: row.modelData.priority }
                        QN.DueBadge { iso: row.modelData.dueAt || ""; nowMs: view.nowMs; use24h: view.use24h }
                        Repeater {
                            model: row.modelData.tagIds || []
                            delegate: QN.TagChip {
                                required property var modelData
                                readonly property var tag: view.controller.doc.tags[modelData]
                                visible: !!tag
                                tagName: tag ? tag.name : ""
                                tagColor: tag ? Theme.accentFor(tag.color, view.accent) : view.accent
                                onClicked: view.tagActivated(modelData)
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
                            QQC2.MenuItem { text: i18n("Urgent"); onTriggered: view.controller.setPriority("todos", row.modelData.id, 4) }
                            QQC2.MenuItem { text: i18n("High"); onTriggered: view.controller.setPriority("todos", row.modelData.id, 3) }
                            QQC2.MenuItem { text: i18n("Medium"); onTriggered: view.controller.setPriority("todos", row.modelData.id, 2) }
                            QQC2.MenuItem { text: i18n("Low"); onTriggered: view.controller.setPriority("todos", row.modelData.id, 1) }
                            QQC2.MenuItem { text: i18n("None"); onTriggered: view.controller.setPriority("todos", row.modelData.id, 0) }
                        }
                    }
                    QQC2.ToolButton {
                        icon.name: "appointment-new"; flat: true
                        icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                        onClicked: dueMenu.open()
                        QQC2.Menu {
                            id: dueMenu
                            QQC2.MenuItem { text: i18n("In 1 hour"); onTriggered: view.controller.setDue("todos", row.modelData.id, new Date(Date.now() + 3600000).toISOString()) }
                            QQC2.MenuItem { text: i18n("This evening"); onTriggered: { var d = new Date(); d.setHours(18, 0, 0, 0); view.controller.setDue("todos", row.modelData.id, d.toISOString()); } }
                            QQC2.MenuItem { text: i18n("Tomorrow"); onTriggered: { var d = new Date(); d.setDate(d.getDate() + 1); d.setHours(9, 0, 0, 0); view.controller.setDue("todos", row.modelData.id, d.toISOString()); } }
                            QQC2.MenuItem { text: i18n("Next week"); onTriggered: { var d = new Date(); d.setDate(d.getDate() + 7); d.setHours(9, 0, 0, 0); view.controller.setDue("todos", row.modelData.id, d.toISOString()); } }
                            QQC2.MenuSeparator {}
                            QQC2.MenuItem { text: i18n("Clear due date"); onTriggered: view.controller.setDue("todos", row.modelData.id, null) }
                        }
                    }
                    QQC2.ToolButton {
                        icon.name: row.modelData.archived ? "archive-remove" : "archive-insert"; flat: true
                        icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                        opacity: rowHover.hovered ? 1 : 0
                        onClicked: view.controller.setArchived("todos", row.modelData.id, !row.modelData.archived)
                    }
                    QQC2.ToolButton {
                        icon.name: "edit-delete"; flat: true
                        icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                        opacity: rowHover.hovered ? 1 : 0
                        onClicked: view.controller.deleteItem("todos", row.modelData.id)
                    }
                }
            }
        }
    }
}
