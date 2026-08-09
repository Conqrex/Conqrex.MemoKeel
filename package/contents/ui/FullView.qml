import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Qt.labs.platform as Platform
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T
import "../code/theme.js" as Theme

// The popup shell: header, a top tab strip, an optional search bar, the add
// bar and a full-width content loader that swaps the active mode. Overlays
// host the note editor, the card editor and the trash. All data flows through
// `controller` (main.qml).
Item {
    id: full

    property var controller
    readonly property var doc: controller ? controller.doc : null
    // A blocked legacy import leaves the controller with no document on
    // purpose; everything that would act on one has to stand down.
    readonly property bool migrationBlocked: !!controller && controller.migrationBlocked
    readonly property bool hasDoc: full.doc !== null
    readonly property double nowMs: controller ? controller.nowMs : 0
    readonly property bool use24h: controller ? controller.use24h : true
    readonly property color accent: Theme.accentFor(controller ? controller.accentKey : "cyan",
                                                     Kirigami.Theme.highlightColor)

    property string currentMode: "dashboard"
    // The search *bar* is a collapsible filter over every mode. The Search
    // *tab* has no field of its own, so the bar is pinned open while that tab
    // is active — otherwise the tab would be a dead end with nothing to type
    // into. `searchRequested` is the user's explicit toggle; `searchVisible`
    // stays a pure binding so the toggle button can bind to it safely.
    property bool searchRequested: false
    readonly property bool searchPinned: full.currentMode === "search"
    readonly property bool searchVisible: full.searchRequested || full.searchPinned
    property string searchText: ""
    property string tagFilter: ""
    property string editingNoteId: ""
    property string editingCardId: ""
    property bool showTrash: false
    property string importMode: "merge"

    // Build the (heavy, themed) view content lazily. In a panel, Plasma pre-creates
    // the full representation on startup (for sizing/tooltip) while the popup window
    // isn't on a real, theme-ready window yet; on Plasma 6.7.1 instantiating these
    // themed views during that pre-attach re-enters KirigamiPlasmaStyle's color sync
    // and segfaults plasmashell (setNeutralTextColor — only reproducible with a dark
    // color scheme). `expanded` is false during that pre-creation and true once the
    // popup is genuinely open, so gate on it; once opened we keep the views alive so
    // reopening is instant. On the desktop (Planar) there is no popup pre-creation —
    // the widget is shown directly in a ready window — so always build there.
    readonly property bool isDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property bool popupOpen: !!controller && controller.expanded
    property bool everOpened: false
    onPopupOpenChanged: if (popupOpen) everOpened = true

    Layout.preferredWidth: Kirigami.Units.gridUnit * (controller ? Plasmoid.configuration.popupWidthUnits : 32)
    Layout.preferredHeight: Kirigami.Units.gridUnit * (controller ? Plasmoid.configuration.popupHeightUnits : 30)
    Layout.minimumWidth: Kirigami.Units.gridUnit * 21
    Layout.minimumHeight: Kirigami.Units.gridUnit * 16

    // A toast is only worth showing once there is somewhere to show it: inside an
    // open popup, or on the desktop where the view is permanently visible.
    readonly property bool canToast: full.everOpened || full.isDesktop

    Component.onCompleted: {
        if (controller) full.currentMode = Plasmoid.configuration.lastMode || "dashboard";
        // The stored mode may name a tab the user has since switched off.
        full.ensureModeAvailable();
        if (popupOpen) full.everOpened = true;
        full.drainPendingStatus();
    }
    onCurrentModeChanged: {
        if (controller && full.currentMode !== "search") Plasmoid.configuration.lastMode = full.currentMode;
        // The Search tab's only input is the shared bar above it.
        if (full.currentMode === "search") searchBar.focusField();
    }

    // The tab model drops the modes the user turned off, so it is the authority
    // on what may be shown — both for the mode restored at startup and for a
    // mode that disappears because Kanban/Board was switched off while open.
    function defaultTabMode() {
        var d = controller ? ("" + Plasmoid.configuration.defaultMode) : "";
        if (d !== "" && tabBar.indexOfMode(d) >= 0) return d;
        if (tabBar.indexOfMode("dashboard") >= 0) return "dashboard";
        return tabBar.modeAt(0);
    }
    function ensureModeAvailable() {
        if (tabBar.indexOfMode(full.currentMode) < 0) full.selectMode(full.defaultTabMode());
    }
    Connections {
        target: tabBar
        function onModesChanged() { full.ensureModeAvailable(); }
    }

    // surface controller status messages as toasts
    Connections {
        target: controller
        function onStatusMessageChanged() {
            if (controller.statusMessage !== "") { toast.show(controller.statusMessage); controller.statusMessage = ""; }
        }
        function onPendingStatusMessageChanged() { full.drainPendingStatus(); }
    }

    // Messages raised at startup (the legacy-import notice) are parked in
    // controller.pendingStatusMessage rather than statusMessage, because at that
    // point either this item does not exist yet or the popup is shut and the
    // toast would animate unseen. Drain it the first time we can actually show
    // one; clearing it is what makes it show exactly once, not on every open.
    onCanToastChanged: full.drainPendingStatus()
    function drainPendingStatus() {
        if (!controller || !full.canToast) return;
        var msg = "" + controller.pendingStatusMessage;
        if (msg === "") return;
        controller.pendingStatusMessage = "";
        toast.show(msg);
    }

    function openNote(id) { full.editingNoteId = id; }
    function tagName(id) { return (doc && doc.tags[id]) ? doc.tags[id].name : ""; }
    function firstColumnId() {
        if (!doc || doc.columns.length === 0) return "";
        var cols = doc.columns.slice().sort(function (a, b) { return (a.order || 0) - (b.order || 0); });
        return cols[0].id;
    }

    // route the quick-add bar to the active mode
    function handleAdd(p) {
        // No document means every intent below would patch `null`.
        if (!controller || !full.hasDoc) return;
        if ((!p.text || p.text === "") && p.tagNames.length === 0) return;
        var id = "", coll = "notes";
        switch (full.currentMode) {
        case "todo":
            id = controller.addTodo({ text: p.text, priority: p.priority, dueAt: p.dueAt }); coll = "todos"; break;
        case "kanban":
            var colId = full.firstColumnId();
            if (!colId) colId = controller.addColumn({ title: i18n("To Do") });
            id = controller.addCard(colId, { title: p.text, priority: p.priority, dueAt: p.dueAt }); coll = "cards"; break;
        case "reminders":
            // Reminders are added by ReminderAddRow, which owns its own parsing
            // and chip-based due time. Never fall through to creating a note.
            return;
        default:
            id = controller.addNote({ title: p.text, color: Plasmoid.configuration.defaultNoteColor }); coll = "notes"; break;
        }
        if (id && p.tagNames.length) controller.applyTagNames(coll, id, p.tagNames);
    }

    // ---- navigation / shortcut helpers --------------------------------------
    function selectMode(m) { if (m !== "") full.currentMode = m; }
    // Ctrl+1…7 address tab positions, so resolve them through the tab bar's
    // model, which has already dropped the modes the user turned off.
    function selectTabIndex(i) { full.selectMode(tabBar.modeAt(i)); }

    // Switch to a mode and put the caret in the field that adds to it.
    function focusAdd(mode) {
        full.selectMode(mode);
        if (!full.hasDoc) return;
        if (mode === "reminders") reminderAdd.focusField();
        else quickAdd.focusField();
    }

    function showSearch() { full.searchRequested = true; searchBar.focusField(); }
    // Collapsing is not "cancel": the query survives, so re-opening the bar
    // (or landing on the Search tab) shows what the user last typed. Only
    // Escape clears the text, and only as its own separate step.
    function hideSearch() { full.searchRequested = false; }
    function toggleSearch() {
        // On the Search tab the bar cannot be collapsed, so the toggle just
        // puts the caret back in it — without arming `searchRequested`, which
        // would leave the bar open after the user moves to another tab.
        if (full.searchPinned) { searchBar.focusField(); return; }
        if (full.searchVisible) full.hideSearch(); else full.showSearch();
    }

    // Escape unwinds one layer at a time: overlays first, then the search text,
    // then the search bar itself.
    function handleEscape() {
        if (full.showTrash) { full.showTrash = false; return; }
        if (full.editingCardId !== "") { full.editingCardId = ""; return; }
        if (full.editingNoteId !== "") { full.editingNoteId = ""; return; }
        if (full.searchText !== "") { searchBar.clear(); return; }
        if (full.searchRequested && !full.searchPinned) full.searchRequested = false;
    }

    // Qt.WindowShortcut keeps these scoped to the window this view lives in.
    // In a panel that window is the popup, which is only ours while it is
    // open — hence the extra gate, so a closed widget never eats the desktop's
    // Ctrl+F. Every binding carries a modifier, so a bare letter typed into a
    // field is never swallowed: the add fields keep receiving "n", "t", "k".
    readonly property bool shortcutsActive: full.popupOpen || full.isDesktop

    Shortcut { sequence: "Ctrl+N"; context: Qt.WindowShortcut; enabled: full.shortcutsActive; onActivated: full.focusAdd("notes") }
    Shortcut { sequence: "Ctrl+T"; context: Qt.WindowShortcut; enabled: full.shortcutsActive; onActivated: full.focusAdd("todo") }
    Shortcut {
        sequence: "Ctrl+K"
        context: Qt.WindowShortcut
        enabled: full.shortcutsActive && Plasmoid.configuration.enableKanban
        onActivated: full.focusAdd("kanban")
    }
    Shortcut { sequence: "Ctrl+R"; context: Qt.WindowShortcut; enabled: full.shortcutsActive; onActivated: full.focusAdd("reminders") }
    Shortcut { sequence: "Ctrl+F"; context: Qt.WindowShortcut; enabled: full.shortcutsActive; onActivated: full.toggleSearch() }
    // Only claim Escape when there is a layer to unwind; otherwise it must keep
    // falling through to Plasma, which closes the popup with it.
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: full.shortcutsActive
                 && (full.showTrash || full.editingCardId !== "" || full.editingNoteId !== ""
                     || full.searchText !== ""
                     || (full.searchRequested && !full.searchPinned))
        onActivated: full.handleEscape()
    }
    Shortcut { sequence: "Ctrl+1"; context: Qt.WindowShortcut; enabled: full.shortcutsActive && tabBar.modeAt(0) !== ""; onActivated: full.selectTabIndex(0) }
    Shortcut { sequence: "Ctrl+2"; context: Qt.WindowShortcut; enabled: full.shortcutsActive && tabBar.modeAt(1) !== ""; onActivated: full.selectTabIndex(1) }
    Shortcut { sequence: "Ctrl+3"; context: Qt.WindowShortcut; enabled: full.shortcutsActive && tabBar.modeAt(2) !== ""; onActivated: full.selectTabIndex(2) }
    Shortcut { sequence: "Ctrl+4"; context: Qt.WindowShortcut; enabled: full.shortcutsActive && tabBar.modeAt(3) !== ""; onActivated: full.selectTabIndex(3) }
    Shortcut { sequence: "Ctrl+5"; context: Qt.WindowShortcut; enabled: full.shortcutsActive && tabBar.modeAt(4) !== ""; onActivated: full.selectTabIndex(4) }
    Shortcut { sequence: "Ctrl+6"; context: Qt.WindowShortcut; enabled: full.shortcutsActive && tabBar.modeAt(5) !== ""; onActivated: full.selectTabIndex(5) }
    Shortcut { sequence: "Ctrl+7"; context: Qt.WindowShortcut; enabled: full.shortcutsActive && tabBar.modeAt(6) !== ""; onActivated: full.selectTabIndex(6) }

    // feed the theme singleton: system palette + mode
    Binding { target: T.QN; property: "followSystem"; value: Plasmoid.configuration.followSystemTheme }
    Binding { target: T.QN; property: "sysWindow";    value: Kirigami.Theme.backgroundColor }
    Binding { target: T.QN; property: "sysView";      value: Kirigami.Theme.backgroundColor }
    Binding { target: T.QN; property: "sysText";      value: Kirigami.Theme.textColor }
    Binding { target: T.QN; property: "sysHighlight"; value: Kirigami.Theme.highlightColor }

    // opaque themed backdrop for the whole popup
    Rectangle {
        anchors.fill: parent
        z: -1
        radius: T.QN.radiusM
        color: T.QN.bg
        border.width: 1
        border.color: T.QN.border
    }

    // ----------------------------------------------------------------- layout
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // header ----------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.ToolButton {
                icon.name: "application-menu"
                flat: true
                onClicked: dataMenu.open()
                QQC2.ToolTip.text: i18n("Data")
                QQC2.ToolTip.visible: hovered
                QQC2.Menu {
                    id: dataMenu
                    QQC2.MenuItem { text: i18n("Export to JSON…"); icon.name: "document-export"; enabled: full.hasDoc; onTriggered: exportJsonDialog.open() }
                    QQC2.MenuItem { text: i18n("Export notes to Markdown…"); icon.name: "text-markdown"; enabled: full.hasDoc; onTriggered: exportMdDialog.open() }
                    QQC2.MenuItem { text: i18n("Import (merge)…"); icon.name: "document-import"; enabled: full.hasDoc; onTriggered: { full.importMode = "merge"; importDialog.open(); } }
                    QQC2.MenuItem { text: i18n("Import (replace all)…"); icon.name: "document-import"; enabled: full.hasDoc; onTriggered: { full.importMode = "replace"; importDialog.open(); } }
                    QQC2.MenuSeparator {}
                    QQC2.MenuItem { text: i18n("Back up now"); icon.name: "document-save"; enabled: full.hasDoc; onTriggered: full.controller.backupNow() }
                    QQC2.MenuItem { text: i18n("Clean up attachments"); icon.name: "edit-clear-history"; enabled: full.hasDoc; onTriggered: full.controller.runGc() }
                    QQC2.MenuItem { text: i18n("Open data folder"); icon.name: "folder-open"; onTriggered: Qt.openUrlExternally("file://" + full.controller.dataDir) }
                }
            }
            Kirigami.Icon {
                source: "com.conqrex.memokeel"
                fallback: "view-pim-notes"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }
            Kirigami.Heading { level: 3; text: i18n("MemoKeel"); color: T.QN.text }

            // The active tag filter belongs beside the title, not out with the
            // badges — so the spacer comes after it.
            QN.TagChip {
                visible: full.tagFilter !== "" && full.doc && full.doc.tags[full.tagFilter]
                tagName: full.tagName(full.tagFilter)
                tagColor: (full.doc && full.doc.tags[full.tagFilter])
                          ? Theme.accentFor(full.doc.tags[full.tagFilter].color, full.accent) : full.accent
                active: true
                removable: true
                onRemoveClicked: full.tagFilter = ""
                onClicked: full.tagFilter = ""
            }

            Item { Layout.fillWidth: true }

            // overdue reminders — jumps to the Reminders tab
            QQC2.ToolButton {
                icon.name: "appointment-reminder"
                flat: true
                visible: (controller ? controller.overdueCount : 0) > 0
                onClicked: full.selectMode("reminders")
                QQC2.ToolTip.text: i18np("%1 reminder due", "%1 reminders due",
                                         controller ? controller.overdueCount : 0)
                QQC2.ToolTip.visible: hovered
                CountBadge {
                    count: controller ? controller.overdueCount : 0
                    bg: Kirigami.Theme.negativeTextColor
                    fg: "white"
                }
            }
            // open to-dos — jumps to the To-Do tab
            QQC2.ToolButton {
                icon.name: "view-pim-tasks"
                flat: true
                visible: (controller ? controller.openTodoCount : 0) > 0
                onClicked: full.selectMode("todo")
                QQC2.ToolTip.text: i18np("%1 open to-do", "%1 open to-dos",
                                         controller ? controller.openTodoCount : 0)
                QQC2.ToolTip.visible: hovered
                CountBadge {
                    count: controller ? controller.openTodoCount : 0
                    bg: full.accent
                    fg: "#0b0f1a"
                }
            }
            QQC2.ToolButton {
                icon.name: "search"
                flat: true
                // Deliberately NOT checkable: a checkable button owns `checked`
                // and would fight the binding below. Here `checked` is a pure
                // one-way read of the state, and the click only ever changes
                // the state, so the two can never disagree.
                checkable: false
                checked: full.searchVisible
                onClicked: full.toggleSearch()
                QQC2.ToolTip.text: i18n("Search (Ctrl+F)")
                QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
                icon.name: "overflow-menu"
                flat: true
                onClicked: moreMenu.open()
                QQC2.ToolTip.text: i18n("More")
                QQC2.ToolTip.visible: hovered
                QQC2.Menu {
                    id: moreMenu
                    QQC2.MenuItem {
                        id: archivedItem
                        text: i18n("Show archived items")
                        icon.name: "archive-insert"
                        // Checkable, because a menu entry needs its check mark —
                        // so `checked` is held by a Binding rather than an inline
                        // one, and the handler writes the config, never `checked`.
                        // The config is the single source both mirrors read.
                        checkable: true
                        enabled: full.hasDoc
                        onTriggered: Plasmoid.configuration.showArchived = !Plasmoid.configuration.showArchived
                        Binding {
                            target: archivedItem
                            property: "checked"
                            value: Plasmoid.configuration.showArchived
                            restoreMode: Binding.RestoreBindingOrValue
                        }
                    }
                    QQC2.MenuItem {
                        text: i18n("Trash (%1)", full.doc ? full.doc.trash.length : 0)
                        icon.name: "user-trash"
                        enabled: full.hasDoc
                        onTriggered: full.showTrash = true
                    }
                    QQC2.MenuSeparator {}
                    QQC2.MenuItem {
                        text: i18n("Settings…")
                        icon.name: "configure"
                        onTriggered: { var a = Plasmoid.internalAction("configure"); if (a) a.trigger(); }
                    }
                }
            }
        }

        // tabs --------------------------------------------------------------
        TabBar {
            id: tabBar
            Layout.fillWidth: true
            currentMode: full.currentMode
            overdue: controller ? controller.overdueCount : 0
            openTodos: controller ? controller.openTodoCount : 0
            accent: full.accent
            enableKanban: Plasmoid.configuration.enableKanban
            enableBoard: Plasmoid.configuration.enableBoard
            onModeSelected: (m) => full.selectMode(m)
        }

        // search (collapsible) ----------------------------------------------
        SearchBar {
            id: searchBar
            Layout.fillWidth: true
            visible: full.searchVisible
            onTextChanged: full.searchText = text
        }

        // quick add -------------------------------------------------------
        QuickAddBar {
            id: quickAdd
            Layout.fillWidth: true
            // The dashboard carries its own per-pane add rows, and the
            // reminders mode has ReminderAddRow; a third field above either
            // would just be one more place the same text could go.
            visible: full.currentMode !== "reminders" && full.currentMode !== "dashboard"
            // Without a document every add intent would patch `null`.
            enabled: full.hasDoc
            hint: {
                switch (full.currentMode) {
                case "todo": return i18n("Ctrl+T");
                case "kanban": return i18n("Ctrl+K");
                default: return i18n("Ctrl+N");
                }
            }
            placeholder: {
                switch (full.currentMode) {
                case "todo": return i18n("Add a task…  #tag !priority ^due");
                case "kanban": return i18n("Add a card…  #tag !priority ^due");
                default: return i18n("Add a note…  #tag");
                }
            }
            onAddRequested: (p) => full.handleAdd(p)
        }
        ReminderAddRow {
            id: reminderAdd
            Layout.fillWidth: true
            visible: full.currentMode === "reminders"
            enabled: full.hasDoc
            hint: i18n("Ctrl+R")
            controller: full.controller
            onAdded: toast.show(i18n("Reminder added"))
        }

        // content -----------------------------------------------------------
        Loader {
            id: content
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Gate only on the lazy-instantiation guard: the no-document states
            // have their own components below, and must actually render.
            active: full.everOpened || full.isDesktop
            sourceComponent: {
                if (full.migrationBlocked) return blockedComp;
                if (!full.doc) return loadingComp;
                switch (full.currentMode) {
                case "todo": return todoComp;
                case "kanban": return kanbanComp;
                case "reminders": return remindersComp;
                case "board": return boardComp;
                case "search": return searchComp;
                case "dashboard": return dashboardComp;
                case "tags": return tagsComp;
                default: return notesComp;
                }
            }
        }

        // footer ----------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                color: T.QN.textFaint
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
                text: {
                    if (!full.doc) return "";
                    var bits = [];
                    if (full.doc.notes.length) bits.push(i18np("%1 note", "%1 notes", full.doc.notes.length));
                    if (controller && controller.openTodoCount) bits.push(i18np("%1 to-do", "%1 to-dos", controller.openTodoCount));
                    return bits.join("  ·  ");
                }
            }
            QQC2.ToolButton {
                icon.name: "archive-insert"
                flat: true
                // Same reasoning as the search toggle: `checked` is a pure read
                // of the config, the click only writes the config, so this
                // button and the ⋮ menu entry can never drift apart.
                checkable: false
                enabled: full.hasDoc
                checked: Plasmoid.configuration.showArchived
                onClicked: Plasmoid.configuration.showArchived = !Plasmoid.configuration.showArchived
                QQC2.ToolTip.text: i18n("Show archived items")
                QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
                icon.name: "user-trash"
                flat: true
                enabled: full.hasDoc && full.doc.trash.length > 0
                onClicked: full.showTrash = true
                QQC2.ToolTip.text: i18n("Trash (%1)", full.doc ? full.doc.trash.length : 0)
                QQC2.ToolTip.visible: hovered
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents.Label {
                visible: controller && controller.lastSaved !== ""
                color: T.QN.textFaint
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
                text: controller ? i18n("Saved %1", controller.lastSaved) : ""
            }
            QQC2.ToolButton {
                icon.name: "folder-open"
                flat: true
                onClicked: Qt.openUrlExternally("file://" + full.controller.dataDir)
                QQC2.ToolTip.text: i18n("Open data folder")
                QQC2.ToolTip.visible: hovered
            }
        }
    }

    // A small count bubble pinned to the top-right of a header button — the
    // same shape the nav rail used on its Reminders and To-Do entries.
    component CountBadge: Rectangle {
        property int count: 0
        property color bg: Kirigami.Theme.negativeTextColor
        property color fg: "white"

        visible: count > 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Kirigami.Units.smallSpacing * 0.5
        width: Kirigami.Units.gridUnit * 0.8
        height: width
        radius: width / 2
        color: bg
        Text {
            anchors.centerIn: parent
            text: parent.count > 9 ? i18n("9+") : parent.count
            color: parent.fg
            font.pixelSize: parent.height * 0.6
            font.bold: true
        }
    }

    // ---- content components -------------------------------------------------
    Component { id: loadingComp
        QN.EmptyState {
            anchors.centerIn: parent
            width: parent ? parent.width : 0
            icon: "view-refresh"
            title: i18n("Loading…")
            hint: i18n("Reading your notes from disk.")
        }
    }
    // Persistent explanation while a legacy import is stuck: there is no
    // document to show and none may be invented. The wording is the
    // controller's, so this and the startup toast can never drift apart.
    Component { id: blockedComp
        QN.EmptyState {
            anchors.centerIn: parent
            width: parent ? parent.width : 0
            icon: "dialog-warning"
            title: i18n("Your notes could not be imported yet")
            hint: full.controller ? full.controller.migrationBlockedMessage : ""
        }
    }
    Component { id: dashboardComp
        DashboardView {
            controller: full.controller; nowMs: full.nowMs; use24h: full.use24h; accent: full.accent
            defaultNoteColor: Plasmoid.configuration.defaultNoteColor
            onModeRequested: (m) => full.selectMode(m)
            onOpenRequested: (id) => full.openNote(id)
            onTagFilterRequested: (t, m) => { full.tagFilter = t; full.selectMode(m); }
        }
    }
    Component { id: tagsComp
        TagsView {
            controller: full.controller; accent: full.accent
            // A chip in the cloud is a filter, not a mode of its own: set the
            // global tag filter and hand the user to Search, which is the tab
            // that lists items across every collection.
            onTagActivated: (t) => { full.tagFilter = t; full.selectMode("search"); }
        }
    }
    Component { id: notesComp
        NotesView {
            controller: full.controller; nowMs: full.nowMs; use24h: full.use24h; accent: full.accent
            query: full.searchText; tagFilter: full.tagFilter
            onOpenRequested: (id) => full.openNote(id)
            onTagActivated: (t) => full.tagFilter = (full.tagFilter === t ? "" : t)
        }
    }
    Component { id: todoComp
        TodoView {
            controller: full.controller; nowMs: full.nowMs; use24h: full.use24h; accent: full.accent
            query: full.searchText; tagFilter: full.tagFilter
            onTagActivated: (t) => full.tagFilter = (full.tagFilter === t ? "" : t)
        }
    }
    Component { id: remindersComp
        RemindersView {
            controller: full.controller; nowMs: full.nowMs; use24h: full.use24h; accent: full.accent
            query: full.searchText; tagFilter: full.tagFilter
        }
    }
    Component { id: kanbanComp
        KanbanView {
            controller: full.controller; nowMs: full.nowMs; use24h: full.use24h; accent: full.accent
            query: full.searchText; tagFilter: full.tagFilter
            onEditRequested: (id) => full.editingCardId = id
        }
    }
    Component { id: boardComp
        BoardView { controller: full.controller; accent: full.accent }
    }
    Component { id: searchComp
        SearchView {
            controller: full.controller; nowMs: full.nowMs; use24h: full.use24h; accent: full.accent
            query: full.searchText; tagFilter: full.tagFilter
            onOpenRequested: (id) => full.openNote(id)
            onTagActivated: (t) => full.tagFilter = (full.tagFilter === t ? "" : t)
            onModeRequested: (m) => full.currentMode = m
        }
    }

    // ---- note editor overlay ------------------------------------------------
    Loader {
        anchors.fill: parent
        active: full.editingNoteId !== ""
        z: 50
        sourceComponent: Rectangle {
            color: Qt.rgba(0, 0, 0, 0.55)
            MouseArea { anchors.fill: parent; onClicked: full.editingNoteId = "" }
            NoteEditor {
                anchors.centerIn: parent
                width: Math.min(parent.width - Kirigami.Units.gridUnit, Kirigami.Units.gridUnit * 24)
                height: Math.min(parent.height - Kirigami.Units.gridUnit, Kirigami.Units.gridUnit * 24)
                controller: full.controller
                noteId: full.editingNoteId
                nowMs: full.nowMs
                use24h: full.use24h
                onClosed: full.editingNoteId = ""
                onTagActivated: (t) => { full.tagFilter = t; full.editingNoteId = ""; full.currentMode = "notes"; }
                onOpenNote: (id) => full.editingNoteId = id
            }
        }
    }

    // ---- card editor overlay ------------------------------------------------
    Loader {
        anchors.fill: parent
        active: full.editingCardId !== ""
        z: 55
        sourceComponent: Rectangle {
            color: Qt.rgba(0, 0, 0, 0.55)
            MouseArea { anchors.fill: parent; onClicked: full.editingCardId = "" }
            CardEditor {
                anchors.centerIn: parent
                width: Math.min(parent.width - Kirigami.Units.gridUnit, Kirigami.Units.gridUnit * 22)
                height: Math.min(parent.height - Kirigami.Units.gridUnit, Kirigami.Units.gridUnit * 18)
                controller: full.controller
                cardId: full.editingCardId
                nowMs: full.nowMs
                use24h: full.use24h
                onClosed: full.editingCardId = ""
            }
        }
    }

    // ---- trash overlay ------------------------------------------------------
    Loader {
        anchors.fill: parent
        active: full.showTrash
        z: 60
        sourceComponent: TrashOverlay {
            controller: full.controller
            nowMs: full.nowMs
            onClosed: full.showTrash = false
        }
    }

    // ---- toast --------------------------------------------------------------
    Toast {
        id: toast
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Kirigami.Units.gridUnit * 2
        z: 100
    }

    // ---- data file dialogs --------------------------------------------------
    Platform.FileDialog {
        id: exportJsonDialog
        fileMode: Platform.FileDialog.SaveFile
        nameFilters: [i18n("JSON backup (*.json)")]
        currentFile: "file://memokeel-backup.json"
        onAccepted: if (full.controller) full.controller.exportJson(("" + file).replace(/^file:\/\//, ""))
    }
    Platform.FolderDialog {
        id: exportMdDialog
        onAccepted: if (full.controller) full.controller.exportMarkdown(("" + folder).replace(/^file:\/\//, ""))
    }
    Platform.FileDialog {
        id: importDialog
        fileMode: Platform.FileDialog.OpenFile
        nameFilters: [i18n("JSON backup (*.json)"), i18n("All files (*)")]
        onAccepted: if (full.controller) full.controller.importFile(("" + file).replace(/^file:\/\//, ""), full.importMode)
    }
}
