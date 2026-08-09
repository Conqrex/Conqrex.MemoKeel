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
    // Fed by FullView (which alone has Plasmoid.configuration): the colour a
    // dashboard-added note should get, so a note added from here is identical
    // to one added from the Notes tab's own quick-add bar.
    property string defaultNoteColor: ""

    signal modeRequested(string mode)
    signal openRequested(string id)
    // A tag chip in a pane filters *and* takes the user to the pane's mode —
    // the dashboard itself is an overview and does not filter.
    signal tagFilterRequested(string tagId, string mode)

    spacing: Kirigami.Units.smallSpacing

    // The controller may have no document yet (still loading, or a blocked
    // legacy import), so every derived list has to tolerate a null doc.
    readonly property var doc: controller ? controller.doc : null

    // How many items a pane shows before it defers to its own tab. Side by
    // side there is room for the usual 6; stacked, every pane is full width
    // but competes for the same vertical scroll, so it is cut to 4.
    //
    // That 4 is measured, not guessed. Every figure below was read off the
    // real components at the default popup size (32x30 gridUnit = 576x540px,
    // with gridUnit = 18px and smallSpacing = 4px here) and can be re-derived
    // by instantiating them and printing their implicitHeight:
    //
    //   TodoRow / ReminderRow carrying a due badge   56px
    //   DashboardPane's title row                    22px
    //   a section label or a "show more" line        15px  (one smallFont line)
    //   this pane's own row spacing                   2.4px (smallSpacing * 0.6)
    //   DashboardPane's title-to-body spacing         2px   (smallSpacing * 0.5)
    //   the content area FullView leaves at 576x540  410px
    //
    // A stacked Due pane with an overdue section, a today section and a cap of
    // 4 rows therefore costs 22 + 2 + 2x15 + 4x56 + 15 + 6x2.4 ≈ 307px — well
    // inside 410, so the Due pane never has to be scrolled into view. Six rows
    // would cost 22 + 2 + 2x15 + 6x56 + 15 + 8x2.4 ≈ 424px, over the 410 the
    // popup actually has.
    readonly property int maxItems: view.stacked ? 4 : 6

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
    // Width starts at 0 during initial layout, before the first geometry pass;
    // treating that as "not stacked" made the grid build 3 columns and then
    // immediately relayout to 1, a visible flash. width < stackBelow is true at
    // width == 0 too, so stacked is now the correct answer from the first paint.
    readonly property bool stacked: width < view.stackBelow

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

    // To-dos that are overdue or due today belong in the Due pane too — it is
    // titled "Due", not "Reminders", so a low-priority overdue task must not
    // be invisible just because it lives in the To-Do pane's longer, lower
    // (status/priority/due) sorted list. This never removes them from the
    // To-Do pane; grouping.js's todoDueBuckets is purely additive there.
    function computeTodoDue(d) {
        if (!d) return { overdue: [], today: [] };
        return Grouping.todoDueBuckets(Model.visibleItems(d.todos, { showArchived: false }), { nowMs: view.nowMs });
    }
    readonly property var todoDueBuckets: computeTodoDue(view.doc)

    // One combined cap (view.maxItems) applies to the Due pane's whole content
    // — overdue reminders, overdue to-dos, today's reminders and today's
    // to-dos together — instead of separately capping each half as before
    // (which could show up to 2x the cap). Overdue is filled first since it is
    // the more urgent bucket; "extra" is the true remaining count across all
    // four lists, not just whichever ran over.
    function computeDuePane(reminderBuckets, todoBuckets) {
        var remaining = view.maxItems;
        function take(list) {
            if (remaining <= 0) return [];
            var n = Math.min(list.length, remaining);
            remaining -= n;
            return list.slice(0, n);
        }
        var overdueReminders = take(reminderBuckets.overdue);
        var overdueTodos = take(todoBuckets.overdue);
        var todayReminders = take(reminderBuckets.today);
        var todayTodos = take(todoBuckets.today);
        var overdueCount = reminderBuckets.overdue.length + todoBuckets.overdue.length;
        var todayCount = reminderBuckets.today.length + todoBuckets.today.length;
        var total = overdueCount + todayCount;
        // The overflow is counted per kind, not as one number, because the two
        // kinds have two different destination tabs: Reminders renders only
        // doc.reminders and To-Do only doc.todos, so a single "show N more"
        // could only ever be right about one of them.
        var reminderExtra = (reminderBuckets.overdue.length + reminderBuckets.today.length)
                          - (overdueReminders.length + todayReminders.length);
        var todoExtra = (todoBuckets.overdue.length + todoBuckets.today.length)
                      - (overdueTodos.length + todayTodos.length);
        return {
            overdueReminders: overdueReminders, overdueTodos: overdueTodos,
            todayReminders: todayReminders, todayTodos: todayTodos,
            overdueCount: overdueCount, todayCount: todayCount,
            total: total, reminderExtra: reminderExtra, todoExtra: todoExtra
        };
    }
    readonly property var duePane: computeDuePane(view.buckets, view.todoDueBuckets)

    function head(list) { return list.slice(0, view.maxItems); }
    function tagsMap() { return view.doc ? view.doc.tags : ({}); }

    // ---- add intents --------------------------------------------------------
    // The panes add straight through the controller (the same intents the quick
    // add bar drives), so a dashboard add is indistinguishable from one made on
    // the mode's own tab.
    function addNoteFrom(p) {
        if (!view.doc || ((!p.text || p.text === "") && p.tagNames.length === 0)) return;
        var id = view.controller.addNote({ title: p.text, color: view.defaultNoteColor });
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
        // Panes whose overflow needs naming (the Due pane's, which is split by
        // kind) pass their own wording; the rest take the generic one.
        property string label: ""
        visible: extra > 0
        text: more.label !== "" ? more.label
                                : i18np("Show one more", "Show %1 more", more.extra)
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
            // column it simply fills the width. Side by side the declaration
            // order (Notes, To-Do, Due) is the visual order, left to right —
            // explicit Layout.row/column below just spells that out. Stacked,
            // the order flips to Due, To-Do, Notes: the pane titled "Due" is
            // the one thing that must be visible without scrolling, so it goes
            // first instead of ending up ~1.5 screens down.
            DashboardPane {
                Layout.fillWidth: true
                Layout.fillHeight: !view.stacked
                Layout.preferredWidth: 1
                Layout.row: view.stacked ? 2 : 0
                Layout.column: view.stacked ? 0 : 0
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
                Layout.row: view.stacked ? 1 : 0
                Layout.column: view.stacked ? 0 : 1
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
                Layout.row: view.stacked ? 0 : 0
                Layout.column: view.stacked ? 0 : 2
                bodyScrolls: !view.stacked
                title: i18n("Due")
                iconName: "appointment-reminder"
                // Overdue work is the one thing that should shout, so this pane
                // wears the negative colour whenever something is late — a
                // to-do counts here exactly like a reminder does.
                tint: view.duePane.overdueCount > 0 ? Kirigami.Theme.negativeTextColor : view.accent
                count: view.duePane.total
                // No destination: this pane's count merges reminders and
                // to-dos, and no tab shows that union — Reminders would show
                // strictly fewer items than the badge promises. The two
                // kind-specific overflow links at the foot of the pane are the
                // honest way out of it.
                titleActivatable: false
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
                visible: view.duePane.total === 0
                icon: "appointment-reminder"
                title: i18n("Nothing due")
                hint: i18n("Reminders and to-dos that are late or due today land here.")
            }

            // Overdue first, in the negative accent, then what is due today.
            // Each section mixes reminders (ReminderRow) and to-dos (TodoRow,
            // reused as-is — it already carries its own priority/due badges)
            // under one combined cap, computed once by view.duePane so the
            // section counts and the single "show more" below always agree.
            SectionLabel {
                Layout.fillWidth: true
                visible: view.duePane.overdueCount > 0
                label: i18n("Overdue")
                dot: Kirigami.Theme.negativeTextColor
                count: view.duePane.overdueCount
            }
            Repeater {
                model: view.duePane.overdueReminders
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
            Repeater {
                model: view.duePane.overdueTodos
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

            SectionLabel {
                Layout.fillWidth: true
                visible: view.duePane.todayCount > 0
                label: i18n("Today")
                dot: Kirigami.Theme.neutralTextColor
                count: view.duePane.todayCount
            }
            Repeater {
                model: view.duePane.todayReminders
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
            Repeater {
                model: view.duePane.todayTodos
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

            // One link per kind, each advertising exactly what its destination
            // will show: the Reminders tab renders doc.reminders and the To-Do
            // tab doc.todos, so a merged count on a single link would send the
            // user somewhere that holds less than it promised.
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing * 1.5
                Item { Layout.fillWidth: true }
                MoreLink {
                    extra: view.duePane.reminderExtra
                    mode: "reminders"
                    label: i18np("Show one more reminder", "Show %1 more reminders",
                                 view.duePane.reminderExtra)
                }
                MoreLink {
                    extra: view.duePane.todoExtra
                    mode: "todo"
                    label: i18np("Show one more to-do", "Show %1 more to-dos",
                                 view.duePane.todoExtra)
                }
                Item { Layout.fillWidth: true }
            }
        }
    }
}
