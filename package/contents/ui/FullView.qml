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

// The popup shell: header, global search + quick-add, a left nav rail and a
// content loader that swaps the active mode. Overlays host the note editor and
// the trash. All data flows through `controller` (main.qml).
Item {
    id: full

    property var controller
    readonly property var doc: controller ? controller.doc : null
    readonly property double nowMs: controller ? controller.nowMs : 0
    readonly property bool use24h: controller ? controller.use24h : true
    readonly property color accent: Theme.accentFor(controller ? controller.accentKey : "cyan",
                                                     Kirigami.Theme.highlightColor)

    property string currentMode: "notes"
    property string searchText: ""
    property string tagFilter: ""
    property string editingNoteId: ""
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

    Layout.preferredWidth: Kirigami.Units.gridUnit * (controller ? Plasmoid.configuration.popupWidthUnits : 26)
    Layout.preferredHeight: Kirigami.Units.gridUnit * (controller ? Plasmoid.configuration.popupHeightUnits : 26)
    Layout.minimumWidth: Kirigami.Units.gridUnit * 19
    Layout.minimumHeight: Kirigami.Units.gridUnit * 16

    Component.onCompleted: {
        if (controller) full.currentMode = Plasmoid.configuration.lastMode || "notes";
        if (popupOpen) full.everOpened = true;
    }
    onCurrentModeChanged: if (controller && currentMode !== "search") Plasmoid.configuration.lastMode = currentMode

    // surface controller status messages as toasts
    Connections {
        target: controller
        function onStatusMessageChanged() {
            if (controller.statusMessage !== "") { toast.show(controller.statusMessage); controller.statusMessage = ""; }
        }
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
        if (!controller) return;
        if ((!p.text || p.text === "") && p.tagNames.length === 0) return;
        var id = "", coll = "notes";
        switch (full.currentMode) {
        case "todo":
            id = controller.addTodo({ text: p.text, priority: p.priority, dueAt: p.dueAt }); coll = "todos"; break;
        case "reminders":
            id = controller.addReminder({ text: p.text, dueAt: p.dueAt || new Date(Date.now() + 3600000).toISOString() }); coll = "reminders"; break;
        case "kanban":
            var colId = full.firstColumnId();
            if (!colId) colId = controller.addColumn({ title: i18n("To Do") });
            id = controller.addCard(colId, { title: p.text, priority: p.priority, dueAt: p.dueAt }); coll = "cards"; break;
        default:
            id = controller.addNote({ title: p.text, color: Plasmoid.configuration.defaultNoteColor }); coll = "notes"; break;
        }
        if (id && p.tagNames.length) controller.applyTagNames(coll, id, p.tagNames);
    }

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
            Kirigami.Icon {
                source: "com.conqrex.quicknotes"
                fallback: "view-pim-notes"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }
            Kirigami.Heading { level: 3; text: i18n("Quick Notes") }
            Item { Layout.fillWidth: true }

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

            QQC2.ToolButton {
                icon.name: "user-trash"
                flat: true
                visible: full.doc && full.doc.trash.length > 0
                onClicked: full.showTrash = true
                QQC2.ToolTip.text: i18n("Trash (%1)", full.doc ? full.doc.trash.length : 0)
                QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
                icon.name: "application-menu"
                flat: true
                onClicked: dataMenu.open()
                QQC2.ToolTip.text: i18n("Data")
                QQC2.ToolTip.visible: hovered
                QQC2.Menu {
                    id: dataMenu
                    QQC2.MenuItem { text: i18n("Export to JSON…"); icon.name: "document-export"; onTriggered: exportJsonDialog.open() }
                    QQC2.MenuItem { text: i18n("Export notes to Markdown…"); icon.name: "text-markdown"; onTriggered: exportMdDialog.open() }
                    QQC2.MenuItem { text: i18n("Import (merge)…"); icon.name: "document-import"; onTriggered: { full.importMode = "merge"; importDialog.open(); } }
                    QQC2.MenuItem { text: i18n("Import (replace all)…"); icon.name: "document-import"; onTriggered: { full.importMode = "replace"; importDialog.open(); } }
                    QQC2.MenuSeparator {}
                    QQC2.MenuItem { text: i18n("Back up now"); icon.name: "document-save"; onTriggered: full.controller.backupNow() }
                    QQC2.MenuItem { text: i18n("Clean up attachments"); icon.name: "edit-clear-history"; onTriggered: full.controller.runGc() }
                    QQC2.MenuItem { text: i18n("Open data folder"); icon.name: "folder-open"; onTriggered: Qt.openUrlExternally("file://" + full.controller.dataDir) }
                }
            }
            QQC2.ToolButton {
                icon.name: "configure"
                flat: true
                onClicked: { var a = Plasmoid.internalAction("configure"); if (a) a.trigger(); }
                QQC2.ToolTip.text: i18n("Settings")
                QQC2.ToolTip.visible: hovered
            }
        }

        // search ----------------------------------------------------------
        SearchBar {
            id: searchBar
            Layout.fillWidth: true
            onTextChanged: full.searchText = text
        }

        // quick add -------------------------------------------------------
        QuickAddBar {
            id: quickAdd
            Layout.fillWidth: true
            placeholder: {
                switch (full.currentMode) {
                case "todo": return i18n("Add a task…  #tag !priority ^due");
                case "reminders": return i18n("Remind me to…  ^3h ^tomorrow ^14:30");
                case "kanban": return i18n("Add a card…  #tag !priority");
                default: return i18n("Add a note…  #tag");
                }
            }
            onAddRequested: (p) => full.handleAdd(p)
        }

        // nav rail + content ----------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.smallSpacing

            NavRail {
                Layout.fillHeight: true
                currentMode: full.currentMode
                overdue: controller ? controller.overdueCount : 0
                accent: full.accent
                enableKanban: Plasmoid.configuration.enableKanban
                enableBoard: Plasmoid.configuration.enableBoard
                collapsed: Plasmoid.configuration.sidebarCollapsed
                onModeSelected: (m) => full.currentMode = m
                onCollapsedChanged: Plasmoid.configuration.sidebarCollapsed = collapsed
            }

            Loader {
                id: content
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: full.doc !== null && (full.everOpened || full.isDesktop)
                sourceComponent: {
                    if (!full.doc) return loadingComp;
                    switch (full.currentMode) {
                    case "todo": return todoComp;
                    case "kanban": return kanbanComp;
                    case "reminders": return remindersComp;
                    case "board": return boardComp;
                    case "search": return searchComp;
                    default: return notesComp;
                    }
                }
            }
        }

        // footer ----------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            PlasmaComponents.Label {
                Layout.fillWidth: true
                opacity: 0.55
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
            PlasmaComponents.Label {
                visible: controller && controller.lastSaved !== ""
                opacity: 0.5
                font: Kirigami.Theme.smallFont
                text: controller ? i18n("Saved %1", controller.lastSaved) : ""
            }
        }
    }

    // ---- content components -------------------------------------------------
    Component { id: loadingComp
        QN.EmptyState { anchors.centerIn: parent; icon: "view-refresh"; title: i18n("Loading…") }
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
            onOpenRequested: (id) => full.openNote(id)
        }
    }
    Component { id: boardComp
        BoardView { controller: full.controller; accent: full.accent }
    }
    Component { id: searchComp
        SearchView {
            controller: full.controller; nowMs: full.nowMs; use24h: full.use24h; accent: full.accent
            query: full.searchText
            onOpenRequested: (id) => full.openNote(id)
            onTagActivated: (t) => full.tagFilter = t
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
        currentFile: "file://quicknotes-backup.json"
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
