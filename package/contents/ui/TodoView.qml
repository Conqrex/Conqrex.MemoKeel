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
import "../code/grouping.js" as Grouping

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

    function computeItems(doc, q, tag, showArchived) {
        if (!doc) return [];
        var list = Model.visibleItems(doc.todos, { showArchived: showArchived, tagId: tag });
        if (q && q.trim() !== "") return Search.rank(q, list, doc.tags);
        return Grouping.sortTodos(list);
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

        delegate: TodoRow {
            required property var modelData
            width: list.width - (tvBar.visible ? Kirigami.Units.gridUnit : 0)
            controller: view.controller
            todo: modelData
            tagsMap: view.controller && view.controller.doc ? view.controller.doc.tags : ({})
            nowMs: view.nowMs
            use24h: view.use24h
            accentFallback: view.accent
            onTagActivated: (t) => view.tagActivated(t)
        }
    }
}
