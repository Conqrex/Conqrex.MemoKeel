import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T
import "../code/model.js" as Model
import "../code/grouping.js" as Grouping

// Dashboard mode: one overview of everything that matters right now — the most
// recent notes, the open to-dos and what is overdue or due today — so nothing
// has to be found by switching tabs. Each pane renders with the very same
// components its own mode uses (NoteCard, TodoRow, ReminderRow) and orders its
// items with the shared helpers in code/grouping.js, so the dashboard can never
// disagree with the tab it summarises.
ColumnLayout {
    id: view

    property var controller
    property double nowMs: 0
    property bool use24h: true
    property color accent: Kirigami.Theme.highlightColor

    signal modeRequested(string mode)
    signal openRequested(string id)
    // A tag chip in a pane filters *and* takes the user to the pane's mode —
    // the dashboard itself is an overview and does not filter.
    signal tagFilterRequested(string tagId, string mode)

    spacing: Kirigami.Units.smallSpacing

    // The controller may have no document yet (still loading, or a blocked
    // legacy import), so every derived list has to tolerate a null doc.
    readonly property var doc: controller ? controller.doc : null

    // How many items a pane shows before it defers to its own tab. Keeps a
    // stacked pane short enough that all three stay reachable by scrolling.
    readonly property int maxItems: 6

    // Measured, not guessed. A to-do row's chrome (status circle, four action
    // buttons, margins) is a constant 6.7 gridUnits whatever the width, and the
    // rest of the row is the task's text; at roughly 7.6px per character a pane
    // needs ~10 gridUnits of text before a title stops being a fragment. So one
    // usable pane is ~16.8 gridUnits, and three of them plus the two column
    // gaps come to ~51 — below that the panes stack into one scrolling column
    // instead. The popup's default (32) and minimum (21) widths are both under
    // it, so stacked is the normal case and side by side is what a widened
    // popup or a desktop widget gets.
    readonly property real stackBelow: Kirigami.Units.gridUnit * 51
    readonly property bool stacked: width > 0 && width < view.stackBelow

    // ---- data ---------------------------------------------------------------
    // Archived items are deliberately never on the dashboard, whatever the
    // "show archived" toggle says: this is the at-a-glance view of live work,
    // and Model.visibleItems is the same exclusion the mode views use.
    function computeNotes(d) {
        if (!d) return [];
        return Model.sortNotes(Model.visibleItems(d.notes, { showArchived: false }), "updated", true);
    }
    function computeTodos(d) {
        if (!d) return [];
        return Grouping.sortTodos(Grouping.openTodos(Model.visibleItems(d.todos, { showArchived: false })));
    }

    readonly property var noteItems: computeNotes(view.doc)
    readonly property var todoItems: computeTodos(view.doc)
    readonly property var buckets: Grouping.reminderBuckets(view.doc, { nowMs: view.nowMs })
    readonly property var overdueItems: buckets.overdue
    readonly property var todayItems: buckets.today
    readonly property int dueCount: overdueItems.length + todayItems.length

    function head(list) { return list.slice(0, view.maxItems); }
    function tagsMap() { return view.doc ? view.doc.tags : ({}); }

    // ---- add intents --------------------------------------------------------
    // The panes add straight through the controller (the same intents the quick
    // add bar drives), so a dashboard add is indistinguishable from one made on
    // the mode's own tab.
    function addNoteFrom(p) {
        if (!view.doc || ((!p.text || p.text === "") && p.tagNames.length === 0)) return;
        var id = view.controller.addNote({ title: p.text });
        if (id && p.tagNames.length) view.controller.applyTagNames("notes", id, p.tagNames);
    }
    function addTodoFrom(p) {
        if (!view.doc || ((!p.text || p.text === "") && p.tagNames.length === 0)) return;
        var id = view.controller.addTodo({ text: p.text, priority: p.priority, dueAt: p.dueAt });
        if (id && p.tagNames.length) view.controller.applyTagNames("todos", id, p.tagNames);
    }

    // ---- shared bits --------------------------------------------------------
    // "Show N more" foot of a truncated pane; goes to the pane's own tab.
    component MoreLink: PlasmaComponents.Label {
        id: more
        property int extra: 0
        property string mode: ""
        visible: extra > 0
        text: i18np("Show %1 more", "Show %1 more", more.extra)
        font: Kirigami.Theme.smallFont
        color: moreHover.hovered ? view.accent : T.QN.textDim
        HoverHandler { id: moreHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: view.modeRequested(more.mode) }
    }

    // Sub-heading inside the due pane (Overdue / Today), mirroring the group
    // headers of the Reminders mode: a coloured dot, a bold label and a count.
    component SectionLabel: RowLayout {
        id: section
        property string label: ""
        property color dot: Kirigami.Theme.negativeTextColor
        property int count: 0
        spacing: Kirigami.Units.smallSpacing * 0.6
        Rectangle { width: Kirigami.Units.gridUnit * 0.4; height: width; radius: width / 2; color: section.dot }
        PlasmaComponents.Label {
            text: i18nc("@title reminder group with its item count", "%1 (%2)", section.label, section.count)
            font.bold: true
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: T.QN.text
        }
        Item { Layout.fillWidth: true }
    }

    // ---- layout -------------------------------------------------------------
    QQC2.ScrollView {
        id: outer
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        // Only the stacked form scrolls as a whole; side by side each pane
        // scrolls its own body.
        QQC2.ScrollBar.vertical.policy: view.stacked ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
        clip: true

        GridLayout {
            id: grid
            width: outer.availableWidth
            height: view.stacked ? implicitHeight : outer.availableHeight
            columns: view.stacked ? 1 : 3
            columnSpacing: Kirigami.Units.smallSpacing * 1.5
            rowSpacing: Kirigami.Units.smallSpacing * 1.5

            // Equal preferred widths + fillWidth = three equal columns; in one
            // column it simply fills the width.
            DashboardPane {
                Layout.fillWidth: true
                Layout.fillHeight: !view.stacked
                Layout.preferredWidth: 1
                bodyScrolls: !view.stacked
                title: i18n("Notes")
                iconName: "view-pim-notes"
                tint: view.accent
                count: view.noteItems.length
                onTitleActivated: view.modeRequested("notes")
                adder: notesAdder
                bodyComponent: notesBody
            }
            DashboardPane {
                Layout.fillWidth: true
                Layout.fillHeight: !view.stacked
                Layout.preferredWidth: 1
                bodyScrolls: !view.stacked
                title: i18n("To-Do")
                iconName: "view-pim-tasks"
                tint: view.accent
                count: view.todoItems.length
                onTitleActivated: view.modeRequested("todo")
                adder: todoAdder
                bodyComponent: todoBody
            }
            DashboardPane {
                Layout.fillWidth: true
                Layout.fillHeight: !view.stacked
                Layout.preferredWidth: 1
                bodyScrolls: !view.stacked
                title: i18n("Due")
                iconName: "appointment-reminder"
                // Overdue work is the one thing that should shout, so this pane
                // wears the negative colour whenever something is late.
                tint: view.overdueItems.length > 0 ? Kirigami.Theme.negativeTextColor : view.accent
                count: view.dueCount
                onTitleActivated: view.modeRequested("reminders")
                bodyComponent: dueBody
            }
        }
    }

    // ---- pane contents ------------------------------------------------------
    Component {
        id: notesAdder
        QuickAddBar {
            enabled: !!view.doc
            placeholder: i18n("Add a note…  #tag")
            onAddRequested: (p) => view.addNoteFrom(p)
        }
    }
    Component {
        id: todoAdder
        QuickAddBar {
            enabled: !!view.doc
            placeholder: i18n("Add a task…  #tag !priority ^due")
            onAddRequested: (p) => view.addTodoFrom(p)
        }
    }

    Component {
        id: notesBody
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing * 0.6
            QN.EmptyState {
                Layout.fillWidth: true
                visible: view.noteItems.length === 0
                icon: "view-pim-notes"
                title: i18n("No notes yet")
                hint: i18n("Add one above — it shows up here and on the Notes tab.")
            }
            Repeater {
                model: view.head(view.noteItems)
                delegate: NoteCard {
                    required property var modelData
                    Layout.fillWidth: true
                    controller: view.controller
                    note: modelData
                    tagsMap: view.tagsMap()
                    nowMs: view.nowMs
                    use24h: view.use24h
                    accentFallback: view.accent
                    onOpenRequested: (id) => view.openRequested(id)
                    onTagActivated: (t) => view.tagFilterRequested(t, "notes")
                }
            }
            MoreLink {
                Layout.alignment: Qt.AlignHCenter
                extra: view.noteItems.length - view.maxItems
                mode: "notes"
            }
        }
    }

    Component {
        id: todoBody
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing * 0.6
            QN.EmptyState {
                Layout.fillWidth: true
                visible: view.todoItems.length === 0
                icon: "view-pim-tasks"
                title: i18n("Nothing to do")
                hint: i18n("Add a task above. Try #tag, !urgent or ^tomorrow.")
            }
            Repeater {
                model: view.head(view.todoItems)
                delegate: TodoRow {
                    required property var modelData
                    Layout.fillWidth: true
                    controller: view.controller
                    todo: modelData
                    tagsMap: view.tagsMap()
                    nowMs: view.nowMs
                    use24h: view.use24h
                    accentFallback: view.accent
                    onTagActivated: (t) => view.tagFilterRequested(t, "todo")
                }
            }
            MoreLink {
                Layout.alignment: Qt.AlignHCenter
                extra: view.todoItems.length - view.maxItems
                mode: "todo"
            }
        }
    }

    Component {
        id: dueBody
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing * 0.6
            QN.EmptyState {
                Layout.fillWidth: true
                visible: view.dueCount === 0
                icon: "appointment-reminder"
                title: i18n("Nothing due")
                hint: i18n("Reminders that are late or due today land here.")
            }

            // Overdue first, in the negative accent, then what is due today.
            SectionLabel {
                Layout.fillWidth: true
                visible: view.overdueItems.length > 0
                label: i18n("Overdue")
                dot: Kirigami.Theme.negativeTextColor
                count: view.overdueItems.length
            }
            Repeater {
                model: view.head(view.overdueItems)
                delegate: ReminderRow {
                    required property var modelData
                    Layout.fillWidth: true
                    controller: view.controller
                    reminder: modelData
                    nowMs: view.nowMs
                    use24h: view.use24h
                    accentFallback: view.accent
                    // No date picker lives on the dashboard; the Reminders tab
                    // owns that, and its rules are not worth a second copy.
                    canEditTime: false
                }
            }
            MoreLink {
                Layout.alignment: Qt.AlignHCenter
                extra: view.overdueItems.length - view.maxItems
                mode: "reminders"
            }

            SectionLabel {
                Layout.fillWidth: true
                visible: view.todayItems.length > 0
                label: i18n("Today")
                dot: Kirigami.Theme.neutralTextColor
                count: view.todayItems.length
            }
            Repeater {
                model: view.head(view.todayItems)
                delegate: ReminderRow {
                    required property var modelData
                    Layout.fillWidth: true
                    controller: view.controller
                    reminder: modelData
                    nowMs: view.nowMs
                    use24h: view.use24h
                    accentFallback: view.accent
                    canEditTime: false
                }
            }
            MoreLink {
                Layout.alignment: Qt.AlignHCenter
                extra: view.todayItems.length - view.maxItems
                mode: "reminders"
            }
        }
    }
}
