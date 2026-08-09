import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T
import "../code/search.js" as Search
import "../code/model.js" as Model
import "../code/theme.js" as Theme
import "../code/markdown.js" as Md

// Global search: a tag cloud plus fuzzy results across every collection. Clicking
// a note opens the editor; other types jump to their mode; tags filter.
ColumnLayout {
    id: view

    property var controller
    property double nowMs: 0
    property bool use24h: true
    property color accent: Kirigami.Theme.highlightColor
    property string query: ""
    // The global tag filter. Search is where the Tags tab sends the user after
    // a chip is clicked, so this tab has to honour it — with or without a typed
    // query, otherwise that click lands on an empty page.
    property string tagFilter: ""

    signal openRequested(string id)
    signal tagActivated(string tagId)
    signal modeRequested(string mode)

    spacing: Kirigami.Units.smallSpacing

    readonly property var doc: controller ? controller.doc : null
    readonly property var counts: doc ? Model.tagCounts(doc) : ({})

    function tagName(id) { return (view.doc && view.doc.tags[id]) ? view.doc.tags[id].name : ""; }

    readonly property bool hasQuery: view.query.trim() !== ""
    readonly property bool browsing: !view.hasQuery && view.tagFilter !== ""

    function results(d, q, tagId) {
        if (!d) return [];
        var browse = (!q || q.trim() === "");
        // No query and no tag is the idle state: nothing to list.
        if (browse && !tagId) return [];
        var out = [];
        function add(items, type, mode) {
            var pool = items.filter(function (it) { return Search.hasTag(it, tagId); });
            // With a tag but no query there is nothing to rank against, so the
            // whole tagged set is listed most-recently-updated first.
            var picked = browse ? Model.sortItems(pool, "updated", true) : Search.rank(q, pool, d.tags);
            for (var i = 0; i < picked.length; i++) out.push({ item: picked[i], type: type, mode: mode });
        }
        add(d.notes, "note", "notes");
        add(d.todos, "todo", "todo");
        add(d.cards, "card", "kanban");
        add(d.reminders, "reminder", "reminders");
        return out;
    }
    readonly property var hits: results(doc, query, tagFilter)

    // tag cloud
    PlasmaComponents.Label {
        Layout.fillWidth: true
        text: i18n("Tags")
        font.bold: true; color: T.QN.text
        visible: view.doc && Object.keys(view.doc.tags).length > 0
    }
    Flow {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing * 0.6
        visible: view.doc && Object.keys(view.doc.tags).length > 0
        Repeater {
            model: view.doc ? Object.keys(view.doc.tags) : []
            delegate: QN.TagChip {
                required property var modelData
                readonly property var tag: view.doc.tags[modelData]
                tagName: tag ? tag.name : ""
                tagColor: tag ? Theme.accentFor(tag.color, view.accent) : view.accent
                count: view.counts[modelData] || 0
                active: view.tagFilter === modelData
                onClicked: view.tagActivated(modelData)
            }
        }
    }

    QN.EmptyState {
        Layout.fillWidth: true; Layout.fillHeight: true
        visible: view.hits.length === 0
        icon: "search"
        title: {
            if (view.browsing) return i18n("Nothing tagged #%1", view.tagName(view.tagFilter));
            if (!view.hasQuery) return i18n("Search everything");
            return i18n("No matches");
        }
        hint: {
            if (view.browsing) return i18n("Nothing carries this tag any more.");
            if (!view.hasQuery) return i18n("Type above to search notes, to-dos, cards and reminders. Click a tag to filter.");
            if (view.tagFilter !== "") return i18n("Nothing tagged #%1 matched “%2”.", view.tagName(view.tagFilter), view.query);
            return i18n("Nothing matched “%1”.", view.query);
        }
    }

    ListView {
        id: list
        visible: view.hits.length > 0
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; spacing: Kirigami.Units.smallSpacing * 0.6
        model: view.hits
        QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: svBar }

        delegate: QN.NeonCard {
            id: hit
            required property var modelData
            readonly property var it: modelData.item
            width: list.width - (svBar.visible ? Kirigami.Units.gridUnit : 0)
            implicitHeight: hl.implicitHeight + Kirigami.Units.smallSpacing * 1.4
            accent: Theme.accentFor(it.color, view.accent)
            hovered: hh.hovered
            HoverHandler { id: hh }
            TapHandler {
                onTapped: {
                    if (modelData.type === "note") view.openRequested(hit.it.id);
                    else view.modeRequested(modelData.mode);
                }
            }

            RowLayout {
                id: hl
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.smallSpacing * 1.6
                anchors.rightMargin: Kirigami.Units.smallSpacing
                anchors.topMargin: Kirigami.Units.smallSpacing * 0.7
                anchors.bottomMargin: Kirigami.Units.smallSpacing * 0.7
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: ({ note: "view-pim-notes", todo: "view-pim-tasks", card: "view-calendar-tasks", reminder: "appointment-reminder" })[modelData.type]
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    opacity: 0.8
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: hit.it.title || hit.it.text || i18n("Untitled")
                        elide: Text.ElideRight
                        font.bold: true
                        color: T.QN.text
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: hit.it.body ? Md.plainPreview(hit.it.body, 120) : ""
                        elide: Text.ElideRight
                        color: T.QN.textDim; font: Kirigami.Theme.smallFont
                    }
                }
                PlasmaComponents.Label {
                    text: ({ note: i18n("Note"), todo: i18n("To-Do"), card: i18n("Card"), reminder: i18n("Reminder") })[modelData.type]
                    color: T.QN.textFaint; font: Kirigami.Theme.smallFont
                }
            }
        }
    }
}
