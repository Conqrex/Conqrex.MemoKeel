import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
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

    signal openRequested(string id)
    signal tagActivated(string tagId)
    signal modeRequested(string mode)

    spacing: Kirigami.Units.smallSpacing

    readonly property var doc: controller ? controller.doc : null
    readonly property var counts: doc ? Model.tagCounts(doc) : ({})

    function results(d, q) {
        if (!d) return [];
        if (!q || q.trim() === "") return [];
        var out = [];
        function add(items, type, mode) {
            var ranked = Search.rank(q, items, d.tags);
            for (var i = 0; i < ranked.length; i++) out.push({ item: ranked[i], type: type, mode: mode });
        }
        add(d.notes, "note", "notes");
        add(d.todos, "todo", "todo");
        add(d.cards, "card", "kanban");
        add(d.reminders, "reminder", "reminders");
        return out;
    }
    readonly property var hits: results(doc, query)

    // tag cloud
    PlasmaComponents.Label {
        Layout.fillWidth: true
        text: i18n("Tags")
        font.bold: true; opacity: 0.7
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
                onClicked: view.tagActivated(modelData)
            }
        }
    }

    QN.EmptyState {
        Layout.fillWidth: true; Layout.fillHeight: true
        visible: view.query.trim() === "" || view.hits.length === 0
        icon: "search"
        title: view.query.trim() === "" ? i18n("Search everything") : i18n("No matches")
        hint: view.query.trim() === "" ? i18n("Type above to search notes, to-dos, cards and reminders. Click a tag to filter.")
                                       : i18n("Nothing matched “%1”.", view.query)
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
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: hit.it.body ? Md.plainPreview(hit.it.body, 120) : ""
                        elide: Text.ElideRight
                        opacity: 0.6; font: Kirigami.Theme.smallFont
                    }
                }
                PlasmaComponents.Label {
                    text: ({ note: i18n("Note"), todo: i18n("To-Do"), card: i18n("Card"), reminder: i18n("Reminder") })[modelData.type]
                    opacity: 0.45; font: Kirigami.Theme.smallFont
                }
            }
        }
    }
}
