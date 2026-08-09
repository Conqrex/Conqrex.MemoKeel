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

// Notes mode: a filtered, sorted, pinned-first list of NoteCards.
ColumnLayout {
    id: view

    property var controller
    property double nowMs: 0
    property bool use24h: true
    property color accent: Kirigami.Theme.highlightColor
    property string query: ""
    property string tagFilter: ""

    signal openRequested(string id)
    signal tagActivated(string tagId)

    spacing: Kirigami.Units.smallSpacing

    function computeItems(doc, q, tag, sortBy, desc, showArchived) {
        if (!doc) return [];
        var list = Model.visibleItems(doc.notes, { showArchived: showArchived, tagId: tag });
        if (q && q.trim() !== "") return Search.rank(q, list, doc.tags);
        return Model.sortNotes(list, sortBy, desc);
    }
    readonly property var items: computeItems(controller ? controller.doc : null, query, tagFilter,
                                              Plasmoid.configuration.sortBy,
                                              Plasmoid.configuration.sortDescending,
                                              Plasmoid.configuration.showArchived)

    // toolbar
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        PlasmaComponents.Label {
            text: i18np("%1 note", "%1 notes", view.items.length)
            color: T.QN.textDim; font: Kirigami.Theme.smallFont
        }
        Item { Layout.fillWidth: true }
        QQC2.ToolButton {
            icon.name: "view-sort"
            flat: true
            text: ({ updated: i18n("Recent"), created: i18n("Created"), title: i18n("Title") })[Plasmoid.configuration.sortBy] || i18n("Sort")
            display: QQC2.AbstractButton.TextBesideIcon
            font: Kirigami.Theme.smallFont
            onClicked: sortMenu.open()
            QQC2.Menu {
                id: sortMenu
                QQC2.MenuItem { text: i18n("Recently updated"); onTriggered: Plasmoid.configuration.sortBy = "updated" }
                QQC2.MenuItem { text: i18n("Date created"); onTriggered: Plasmoid.configuration.sortBy = "created" }
                QQC2.MenuItem { text: i18n("Title"); onTriggered: Plasmoid.configuration.sortBy = "title" }
                QQC2.MenuSeparator {}
                QQC2.MenuItem {
                    text: Plasmoid.configuration.sortDescending ? i18n("Descending ↓") : i18n("Ascending ↑")
                    onTriggered: Plasmoid.configuration.sortDescending = !Plasmoid.configuration.sortDescending
                }
            }
        }
        QQC2.ToolButton {
            icon.name: "archive-insert"
            flat: true
            checkable: true
            checked: Plasmoid.configuration.showArchived
            onToggled: Plasmoid.configuration.showArchived = checked
            QQC2.ToolTip.text: i18n("Show archived"); QQC2.ToolTip.visible: hovered
        }
    }

    QN.EmptyState {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: view.items.length === 0
        icon: "view-pim-notes"
        title: view.query !== "" || view.tagFilter !== "" ? i18n("No matching notes") : i18n("No notes yet")
        hint: view.query !== "" || view.tagFilter !== "" ? i18n("Try a different search or tag.")
                                                          : i18n("Use the field above to add your first note. Markdown and [[links]] are supported.")
    }

    ListView {
        id: list
        visible: view.items.length > 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Kirigami.Units.smallSpacing
        model: view.items
        cacheBuffer: height * 2
        QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: nvBar }

        delegate: NoteCard {
            required property var modelData
            width: list.width - (nvBar.visible ? Kirigami.Units.gridUnit : 0)
            controller: view.controller
            note: modelData
            tagsMap: view.controller && view.controller.doc ? view.controller.doc.tags : ({})
            nowMs: view.nowMs
            use24h: view.use24h
            accentFallback: view.accent
            onOpenRequested: (id) => view.openRequested(id)
            onTagActivated: (t) => view.tagActivated(t)
        }
    }
}
