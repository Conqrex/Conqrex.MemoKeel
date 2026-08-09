# Quick Notes Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Banner-style dark-neon theme system, fit-to-width Kanban with real drag mechanics, visual reminder time picker, polished nav/views/compact panel, OctoPulse-grade README.

**Architecture:** A writable QML singleton (`ui/theme/QN.qml`) becomes the single source of design tokens; `FullView.qml` feeds it system colors + the `followSystemTheme` config so every view reads only `QN.*`. Kanban and Reminders views are rebuilt on top of it. Data layer (`store.sh`, `model.js`, schema) is untouched except for using the already-existing `moveCardBefore` order parameter.

**Tech Stack:** QML (Qt 6.6+/Plasma 6), Kirigami, QtQuick.Controls (`MonthGrid` — in QQC2 since Qt 6.3), bash store broker (unchanged).

## Global Constraints

- No changes to `package/contents/code/store.sh`, `schema.js`, or the on-disk document format.
- `code/theme.js` neon palette keys stay exactly: `cyan sky violet lime amber rose slate`.
- All user-visible strings wrapped in `i18n()`.
- Default theme mode = custom dark (banner look); `followSystemTheme` default **false**.
- Verification tool: `plasmoidviewer -a ./package -f planar -l floating` (no unit-test framework exists for this plasmoid; each task ends with a scripted visual checklist run).
- The project is not yet a git repo — Task 0 creates it. Commit after every task.
- Commit trailer: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

---

### Task 0: Git init + baseline

**Files:** none created besides `.git`.

- [ ] **Step 1: Init and baseline commit**

```bash
cd /home/sancak/Conqrex/Projects/Cnq/Denemeler/Conqrex.QuickNotes
git init -b main
git add -A
git commit -m "chore: baseline before overhaul

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 2: Verify plasmoidviewer baseline runs**

Run: `timeout 15 plasmoidviewer -a ./package -f planar -l floating` (close window / let timeout kill it)
Expected: window opens showing current widget, no QML errors in stderr besides known noise.

---

### Task 1: Theme singleton + config key + NeonCard

**Files:**
- Create: `package/contents/ui/theme/qmldir`
- Create: `package/contents/ui/theme/QN.qml`
- Modify: `package/contents/config/main.xml` (add `followSystemTheme`)
- Modify: `package/contents/ui/configGeneral.qml` (checkbox)
- Modify: `package/contents/ui/FullView.qml` (wire singleton, background)
- Modify: `package/contents/ui/components/NeonCard.qml` (tokens)

**Interfaces:**
- Produces: singleton `QN` with color properties `bg, surface, surfaceHi, inputBg, border, borderHi, text, textDim, textFaint`, real properties `radiusS(6) radiusM(10) radiusL(14)`, bool `followSystem`, writable colors `sysWindow, sysView, sysText, sysHighlight`, function `alpha(c, a)`.
- Import pattern used by ALL later tasks: `import "theme" as T` then `T.QN.surface` (from `ui/`); from `ui/components/` it is `import "../theme" as T`.

- [ ] **Step 1: Create `package/contents/ui/theme/qmldir`**

```
singleton QN QN.qml
```

- [ ] **Step 2: Create `package/contents/ui/theme/QN.qml`**

```qml
pragma Singleton
import QtQuick

// Design tokens for the banner-style dark-neon look. FullView pushes the
// system palette + the followSystemTheme config in here at load; every view
// reads only these tokens, never Kirigami colors directly.
QtObject {
    id: t

    // fed by FullView (Kirigami.Theme is context-attached, unavailable here)
    property bool followSystem: false
    property color sysWindow: "#1b1e20"
    property color sysView: "#1b1e20"
    property color sysText: "#fcfcfc"
    property color sysHighlight: "#3daee9"

    // --- custom dark palette (banner) ---
    readonly property color _bg:        "#0a0e1a"
    readonly property color _surface:   "#111827"
    readonly property color _surfaceHi: "#1a2336"
    readonly property color _inputBg:   "#0d1322"
    readonly property color _text:      "#e6ecf7"

    // --- exposed tokens ---
    readonly property color bg:        followSystem ? sysWindow : _bg
    readonly property color surface:   followSystem ? Qt.lighter(sysView, 1.08) : _surface
    readonly property color surfaceHi: followSystem ? Qt.lighter(sysView, 1.18) : _surfaceHi
    readonly property color inputBg:   followSystem ? Qt.darker(sysView, 1.12) : _inputBg
    readonly property color text:      followSystem ? sysText : _text
    readonly property color textDim:   alpha(text, 0.65)
    readonly property color textFaint: alpha(text, 0.40)
    readonly property color border:    alpha(text, 0.08)
    readonly property color borderHi:  alpha(text, 0.18)

    readonly property real radiusS: 6
    readonly property real radiusM: 10
    readonly property real radiusL: 14

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
}
```

- [ ] **Step 3: Add config entry to `package/contents/config/main.xml`**

Inside the same `<group>` as the existing `accent` entry, after it:

```xml
        <entry name="followSystemTheme" type="Bool">
            <default>false</default>
        </entry>
```

- [ ] **Step 4: Add checkbox to `package/contents/ui/configGeneral.qml`**

Read the file first; match its existing `property alias cfg_<key>` + control pattern. Add:

```qml
    property alias cfg_followSystemTheme: followSystemThemeBox.checked
```

and next to the existing accent control:

```qml
    QQC2.CheckBox {
        id: followSystemThemeBox
        Kirigami.FormData.label: i18n("Appearance:")
        text: i18n("Follow system theme instead of the dark Conqrex look")
    }
```

(If the file uses a different alias/id convention, match it exactly.)

- [ ] **Step 5: Wire singleton + background in `FullView.qml`**

Add import at top: `import "theme" as T`

Inside `Item { id: full`, add feeding block and background as the FIRST children:

```qml
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
```

- [ ] **Step 6: Retoken `components/NeonCard.qml`**

Replace file content:

```qml
import QtQuick
import org.kde.kirigami as Kirigami
import "../theme" as T

// A reusable glassy card surface on the QN token palette: dark elevated
// gradient, rounded corners, accent border that brightens on hover, and a
// left accent stripe. Children are placed directly inside; inset past stripe.
Rectangle {
    id: card

    property color accent: Kirigami.Theme.highlightColor
    property bool hovered: false
    property bool showStripe: true
    property real cardRadius: T.QN.radiusM

    radius: cardRadius
    antialiasing: true

    gradient: Gradient {
        GradientStop { position: 0.0; color: card.hovered ? T.QN.surfaceHi : T.QN.surface }
        GradientStop { position: 1.0; color: Qt.darker(T.QN.surface, card.hovered ? 1.02 : 1.12) }
    }

    border.width: 1
    border.color: T.QN.alpha(card.accent, card.hovered ? 0.65 : 0.25)
    Behavior on border.color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

    // left accent stripe
    Rectangle {
        visible: card.showStripe
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 1.5
        width: 3
        radius: width / 2
        color: card.accent
        opacity: card.hovered ? 0.95 : 0.7
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
    }
}
```

- [ ] **Step 7: Verify**

Run: `timeout 20 plasmoidviewer -a ./package -f planar -l floating 2>&1 | grep -iE "error|singleton" || true`
Expected: no `QN` / singleton / import errors. Visually: popup has dark navy backdrop; cards darker/steadier than before. Toggle "Follow system theme" in settings → surfaces flip live.

- [ ] **Step 8: Commit**

```bash
git add package/contents/ui/theme package/contents/config/main.xml package/contents/ui/configGeneral.qml package/contents/ui/FullView.qml package/contents/ui/components/NeonCard.qml
git commit -m "feat: QN theme singleton with banner dark palette and system-theme toggle

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Kanban rewrite — fit-to-width + pinned quick-add + drop indicator + card editor

**Files:**
- Modify: `package/contents/ui/KanbanView.qml` (rewrite layout)
- Modify: `package/contents/ui/KanbanCard.qml` (title → label, click opens editor)
- Create: `package/contents/ui/CardEditor.qml`
- Modify: `package/contents/ui/FullView.qml` (host card editor overlay)

**Interfaces:**
- Consumes: `T.QN` tokens (Task 1); `controller.moveCard(cardId, toCol, beforeId)` → `Model.moveCardBefore` (exists, `main.qml:227`); `Model.cardsOf(doc, colId)` returns order-sorted cards.
- Produces: `KanbanView` signal `editRequested(string cardId)`; `KanbanCard` signal `editRequested(string id)`; `CardEditor { controller, cardId, nowMs, use24h; signal closed() }`. FullView gets `property string editingCardId: ""`.

- [ ] **Step 1: Rewrite `KanbanView.qml` layout skeleton**

Add `import "theme" as T` at top. Keep the existing header/menu/WIP dialog code blocks; replace the `QQC2.ScrollView` + `RowLayout` block with:

```qml
    Flickable {
        id: hflick
        anchors.fill: parent
        visible: kroot.columns.length > 0
        contentWidth: colRow.width
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { id: hbar; policy: colRow.width > hflick.width ? QQC2.ScrollBar.AlwaysOn : QQC2.ScrollBar.AlwaysOff }

        readonly property int n: kroot.columns.length
        readonly property real gap: Kirigami.Units.smallSpacing
        readonly property real addW: Kirigami.Units.gridUnit * 2
        readonly property real minCol: Kirigami.Units.gridUnit * 10
        // fit-to-width: columns share space; never below minCol
        readonly property real colW: Math.max(minCol, (width - addW - gap * (n + 1)) / Math.max(1, n))

        Row {
            id: colRow
            height: hflick.height - (hbar.visible ? hbar.height + hflick.gap : 0)
            spacing: hflick.gap

            Repeater {
                model: kroot.columns
                delegate: Rectangle {
                    id: col
                    required property var modelData
                    readonly property string colId: modelData.id
                    readonly property var cards: kroot.colCards(colId)
                    readonly property bool overWip: modelData.wipLimit && cards.length > modelData.wipLimit
                    readonly property color colAccent: Theme.accentFor(modelData.color, kroot.accent)

                    width: hflick.colW
                    height: colRow.height
                    radius: T.QN.radiusM
                    color: drop.containsDrag ? T.QN.alpha(col.colAccent, 0.10) : T.QN.surface
                    border.width: 1
                    border.color: drop.containsDrag ? T.QN.alpha(col.colAccent, 0.7)
                                : col.overWip ? T.QN.alpha(Theme.PALETTE.rose, 0.6) : T.QN.border

                    // DropArea + dropIdx holder: Step 2
                    // ColumnLayout with header / ListView / quick-add: structure below
                }
            }

            // slim ghost add-column
            Rectangle {
                width: hflick.addW
                height: colRow.height
                radius: T.QN.radiusM
                color: "transparent"
                border.width: 1
                border.color: addHover.hovered ? T.QN.borderHi : T.QN.border
                Kirigami.Icon { anchors.centerIn: parent; source: "list-add"; opacity: addHover.hovered ? 1 : 0.5 }
                HoverHandler { id: addHover }
                TapHandler { onTapped: kroot.controller.addColumn({ title: i18n("New column") }) }
            }
        }
    }
```

Quick-add pinned fix: inside each column, the `ColumnLayout` (`anchors.fill: parent; anchors.margins: Kirigami.Units.smallSpacing`) has exactly three children in this order — header `RowLayout { Layout.fillWidth: true }` (existing code), `ListView { Layout.fillWidth: true; Layout.fillHeight: true }` (existing code + Step 2 additions), quick-add `QQC2.TextField { Layout.fillWidth: true }` (existing code). Because the column Rectangle now has a fixed `height: colRow.height`, the TextField keeps its implicit height and the ListView absorbs the rest — this removes the current clipping (the old `RowLayout { height: kroot.height }` inside a ScrollView let content exceed the viewport when the horizontal scrollbar appeared). Keep the shared `dragLayer` Item and the empty-board block unchanged.

- [ ] **Step 2: Drop-indicator + positional drop in the column**

Replace the column's `DropArea` with (and add the `dropIdx` holder):

```qml
                    QtObject { id: dropIdx; property int idx: -1 }

                    DropArea {
                        id: drop
                        anchors.fill: parent
                        onPositionChanged: (d) => { dropIdx.idx = cardList.insertIndexAt(d.y); }
                        onExited: dropIdx.idx = -1
                        onDropped: (d) => {
                            var s = d.source;
                            if (s && s.cardId) {
                                var i = cardList.insertIndexAt(d.y);
                                var before = (i >= 0 && i < col.cards.length) ? col.cards[i].id : null;
                                if (before === s.cardId) before = null;
                                kroot.controller.moveCard(s.cardId, col.colId, before);
                            }
                            dropIdx.idx = -1;
                            d.accept();
                        }
                    }
```

In the ListView add the mapping helper and the indicator as a child of the ListView (so coordinates match):

```qml
                            // map a y in column coords to an insertion index
                            function insertIndexAt(colY) {
                                var y = colY - cardList.mapToItem(col, 0, 0).y + cardList.contentY;
                                for (var i = 0; i < count; i++) {
                                    var it = itemAtIndex(i);
                                    if (it && y < it.y + it.height / 2) return i;
                                }
                                return count;
                            }

                            Rectangle {
                                id: dropLine
                                visible: drop.containsDrag && dropIdx.idx >= 0
                                x: 0; width: cardList.width
                                height: 2; radius: 1
                                color: col.colAccent
                                y: {
                                    if (dropIdx.idx <= 0) return 0;
                                    var it = cardList.itemAtIndex(Math.min(dropIdx.idx, cardList.count) - 1);
                                    return it ? it.y + it.height + cardList.spacing / 2 - cardList.contentY : 0;
                                }
                            }
```

- [ ] **Step 3: `KanbanCard.qml` — title becomes Label, whole card clickable**

Add `import "theme" as T` (KanbanCard sits in `ui/`). Add `signal editRequested(string id)` to the card root and:

```qml
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: card.editRequested(card.cardId)
    }
```

Replace the title `QQC2.TextField` with:

```qml
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: card.cardData.title || i18n("(untitled)")
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: T.QN.text
            }
```

Keep the ⋮ menu (move/priority/delete) as-is. In `KanbanView.qml`'s delegate wire `onEditRequested: (id) => kroot.editRequested(id)` and declare `signal editRequested(string id)` on `kroot`.

- [ ] **Step 4: Create `package/contents/ui/CardEditor.qml`**

```qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T
import "../code/theme.js" as Theme

// Modal card editor sheet: title, description, column, priority, due, color.
Rectangle {
    id: ed

    property var controller
    property string cardId: ""
    property double nowMs: 0
    property bool use24h: true
    signal closed()

    readonly property var doc: controller ? controller.doc : null
    readonly property var cardData: {
        if (!doc) return null;
        for (var i = 0; i < doc.cards.length; i++) if (doc.cards[i].id === cardId) return doc.cards[i];
        return null;
    }
    readonly property var columns: doc ? doc.columns.slice().sort(function (a, b) { return (a.order || 0) - (b.order || 0); }) : []

    color: T.QN.surface
    radius: T.QN.radiusL
    border.width: 1
    border.color: T.QN.borderHi
    visible: cardData !== null

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Heading { level: 4; text: i18n("Edit card"); color: T.QN.text }
            Item { Layout.fillWidth: true }
            QQC2.ToolButton { icon.name: "window-close"; flat: true; onClicked: ed.closed() }
        }

        QQC2.TextField {
            Layout.fillWidth: true
            text: ed.cardData ? ed.cardData.title : ""
            placeholderText: i18n("Title")
            onEditingFinished: if (ed.cardData && text !== ed.cardData.title) ed.controller.updateItem("cards", ed.cardId, { title: text })
        }

        QQC2.TextArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: (ed.cardData && ed.cardData.description) ? ed.cardData.description : ""
            placeholderText: i18n("Description")
            wrapMode: TextEdit.Wrap
            onEditingFinished: if (ed.cardData) ed.controller.updateItem("cards", ed.cardId, { description: text })
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            QQC2.ComboBox {
                Layout.fillWidth: true
                model: ed.columns.map(function (c) { return c.title; })
                currentIndex: {
                    for (var i = 0; i < ed.columns.length; i++)
                        if (ed.cardData && ed.columns[i].id === ed.cardData.columnId) return i;
                    return 0;
                }
                onActivated: (i) => ed.controller.moveCard(ed.cardId, ed.columns[i].id, null)
            }
            QQC2.ComboBox {
                model: [i18n("No priority"), i18n("Low"), i18n("Medium"), i18n("High"), i18n("Urgent")]
                currentIndex: ed.cardData ? (ed.cardData.priority || 0) : 0
                onActivated: (i) => ed.controller.setPriority("cards", ed.cardId, i)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            QN.DueBadge { iso: (ed.cardData && ed.cardData.dueAt) ? ed.cardData.dueAt : ""; nowMs: ed.nowMs; use24h: ed.use24h }
            Item { Layout.fillWidth: true }
            QN.ColorPicker {
                current: ed.cardData ? (ed.cardData.color || "") : ""
                onPicked: (key) => ed.controller.setColor("cards", ed.cardId, key)
            }
            QQC2.Button {
                icon.name: "edit-delete"; text: i18n("Delete")
                onClicked: { ed.controller.deleteItem("cards", ed.cardId); ed.closed(); }
            }
        }
    }
}
```

(Check `components/ColorPicker.qml` and `components/DueBadge.qml` property/signal names first — if they differ from `current`/`picked`/`iso`, match the real ones. Due editing gains the DateTimePopup in Task 3 Step 5.)

- [ ] **Step 5: Host editor overlay in `FullView.qml`**

Add `property string editingCardId: ""` next to `editingNoteId`. In the kanban component wiring add `onEditRequested: (id) => full.editingCardId = id`. Add overlay Loader (mirror of the note editor overlay, z: 55):

```qml
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
```

- [ ] **Step 6: WIP pulse + column move menu items**

In the column header menu add before "Delete column":

```qml
                                    QQC2.MenuItem { text: i18n("Move left");  enabled: kroot.columns.indexOf(col.modelData) > 0
                                        onTriggered: { var i = kroot.columns.indexOf(col.modelData); kroot.controller.updateItem("columns", col.colId, { order: (kroot.columns[i-1].order || 0) - 0.5 }); } }
                                    QQC2.MenuItem { text: i18n("Move right"); enabled: kroot.columns.indexOf(col.modelData) < kroot.columns.length - 1
                                        onTriggered: { var i = kroot.columns.indexOf(col.modelData); kroot.controller.updateItem("columns", col.colId, { order: (kroot.columns[i+1].order || 0) + 0.5 }); } }
```

On the existing WIP count Label, replace the static `opacity` binding with a pulse:

```qml
                                opacity: col.overWip ? 1 : 0.6
                                SequentialAnimation on opacity {
                                    running: col.overWip
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1; to: 0.4; duration: 700 }
                                    NumberAnimation { from: 0.4; to: 1; duration: 700 }
                                    onRunningChanged: if (!running) parent.opacity = col.overWip ? 1 : 0.6
                                }
```

- [ ] **Step 7: Verify**

Run: `timeout 30 plasmoidviewer -a ./package -f planar -l floating 2>&1 | grep -iE "error" || true`
Checklist: 3 columns fill width, no horizontal scrollbar at default 26gu popup; every column shows its "+ card" field fully; dragging a card over a column shows accent insert line and drops at that position; card click opens editor; editor column/priority/delete work; "Move left/right" reorders columns; WIP over-limit pulses count and tints column border rose.

- [ ] **Step 8: Commit**

```bash
git add package/contents/ui/KanbanView.qml package/contents/ui/KanbanCard.qml package/contents/ui/CardEditor.qml package/contents/ui/FullView.qml
git commit -m "feat: kanban fit-to-width, pinned quick-add, positional drag-drop, card editor

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Reminders — chip picker row + custom date/time popup

**Files:**
- Create: `package/contents/ui/components/DateTimePopup.qml`
- Create: `package/contents/ui/ReminderAddRow.qml`
- Modify: `package/contents/ui/FullView.qml` (swap QuickAddBar in reminders mode)
- Modify: `package/contents/ui/RemindersView.qml` (due badge click → popup, new empty hint)
- Modify: `package/contents/ui/CardEditor.qml` (due picker button)

**Interfaces:**
- Consumes: `controller.addReminder({text, dueAt, repeat})` (`main.qml:214`), `controller.updateItem("reminders", id, {dueAt, repeat, notified:false, ackedAt:null})`, `controller.setDue("cards", id, iso)`.
- Produces: `DateTimePopup { signal picked(date when, string repeat); function openFor(d, rep) }`; `ReminderAddRow { property var controller; signal added() }`.

- [ ] **Step 1: Create `components/DateTimePopup.qml`**

```qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "../theme" as T

// Calendar + time + repeat picker. openFor(date, repeatString) then emits
// picked(when, repeat) on Set.
QQC2.Popup {
    id: pop

    property date shown: new Date()      // month being displayed
    property date sel: new Date()        // selected day
    property string repeat: "none"
    signal picked(date when, string repeat)

    function openFor(d, rep) {
        var base = d && !isNaN(d.getTime()) ? new Date(d) : new Date(Date.now() + 3600000);
        sel = base;
        shown = new Date(base.getFullYear(), base.getMonth(), 1);
        hourBox.value = base.getHours();
        minBox.value = base.getMinutes();
        repeat = rep || "none";
        open();
    }

    modal: true
    padding: Kirigami.Units.largeSpacing
    background: Rectangle { color: T.QN.surface; radius: T.QN.radiusM; border.width: 1; border.color: T.QN.borderHi }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        // month header
        RowLayout {
            Layout.fillWidth: true
            QQC2.ToolButton { icon.name: "go-previous"; onClicked: pop.shown = new Date(pop.shown.getFullYear(), pop.shown.getMonth() - 1, 1) }
            QQC2.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(pop.shown, "MMMM yyyy")
                font.bold: true
                color: T.QN.text
            }
            QQC2.ToolButton { icon.name: "go-next"; onClicked: pop.shown = new Date(pop.shown.getFullYear(), pop.shown.getMonth() + 1, 1) }
        }

        QQC2.DayOfWeekRow { Layout.fillWidth: true; locale: grid.locale }

        QQC2.MonthGrid {
            id: grid
            Layout.fillWidth: true
            month: pop.shown.getMonth()
            year: pop.shown.getFullYear()
            delegate: Rectangle {
                required property var model
                implicitWidth: Kirigami.Units.gridUnit * 1.8
                implicitHeight: Kirigami.Units.gridUnit * 1.6
                radius: T.QN.radiusS
                readonly property bool isSel: model.day === pop.sel.getDate()
                                           && model.month === pop.sel.getMonth()
                                           && model.year === pop.sel.getFullYear()
                color: isSel ? T.QN.alpha(Kirigami.Theme.highlightColor, 0.35) : "transparent"
                opacity: model.month === grid.month ? 1 : 0.3
                QQC2.Label { anchors.centerIn: parent; text: model.day; color: T.QN.text }
                TapHandler { onTapped: pop.sel = new Date(model.year, model.month, model.day, pop.sel.getHours(), pop.sel.getMinutes()) }
            }
        }

        // time + repeat
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            QQC2.SpinBox { id: hourBox; from: 0; to: 23; value: 9;  wrap: true }
            QQC2.Label { text: ":"; color: T.QN.text }
            QQC2.SpinBox { id: minBox;  from: 0; to: 59; value: 0; wrap: true; stepSize: 5 }
            Item { Layout.fillWidth: true }
            QQC2.ComboBox {
                id: repBox
                model: [i18n("Does not repeat"), i18n("Daily"), i18n("Weekly"), i18n("Monthly")]
                currentIndex: Math.max(0, ["none", "daily", "weekly", "monthly"].indexOf(pop.repeat))
                onActivated: (i) => pop.repeat = ["none", "daily", "weekly", "monthly"][i]
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            QQC2.Button { text: i18n("Cancel"); onClicked: pop.close() }
            QQC2.Button {
                text: i18n("Set"); highlighted: true
                onClicked: {
                    var w = new Date(pop.sel.getFullYear(), pop.sel.getMonth(), pop.sel.getDate(), hourBox.value, minBox.value, 0, 0);
                    pop.picked(w, pop.repeat);
                    pop.close();
                }
            }
        }
    }
}
```

(`MonthGrid`/`DayOfWeekRow` are in QtQuick.Controls since Qt 6.3 — Plasma 6 ships ≥6.6. If the import fails at runtime, use `import Qt.labs.calendar` for those two types instead — verify in Step 6.)

- [ ] **Step 2: Create `ReminderAddRow.qml`**

```qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T

// Reminder add row: text + time chips + custom picker. No token syntax needed.
ColumnLayout {
    id: row

    property var controller
    signal added()

    property int chipIndex: 0                 // default = In 1h
    property date customWhen: new Date(NaN)   // valid only after picker used
    property string customRepeat: "none"

    spacing: Kirigami.Units.smallSpacing * 0.6

    function chipDue(i) {
        var d = new Date();
        switch (i) {
        case 0: return new Date(Date.now() + 3600000);            // In 1h
        case 1: return new Date(Date.now() + 3 * 3600000);        // In 3h
        case 2: d.setHours(20, 0, 0, 0); if (d.getTime() < Date.now()) d.setDate(d.getDate() + 1); return d; // Tonight 20:00
        case 3: d.setDate(d.getDate() + 1); d.setHours(9, 0, 0, 0); return d;   // Tomorrow 9:00
        default: return row.customWhen;                            // Custom
        }
    }

    function submit() {
        var text = field.text.trim();
        if (text === "") return;
        var due = chipDue(row.chipIndex);
        if (isNaN(due.getTime())) { picker.openFor(new Date(Date.now() + 3600000), row.customRepeat); return; }
        row.controller.addReminder({ text: text, dueAt: due.toISOString(),
                                     repeat: row.chipIndex === 4 ? row.customRepeat : "none" });
        field.text = "";
        row.added();
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        QQC2.TextField {
            id: field
            Layout.fillWidth: true
            placeholderText: i18n("Remind me to…")
            selectByMouse: true
            onAccepted: row.submit()
        }
        QQC2.Button { icon.name: "list-add"; text: i18n("Add"); highlighted: true; onClicked: row.submit() }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing * 0.6
        Repeater {
            model: [i18n("In 1h"), i18n("In 3h"), i18n("Tonight 20:00"), i18n("Tomorrow 9:00"), i18n("Custom…")]
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool active: row.chipIndex === index
                implicitWidth: chipLabel.implicitWidth + Kirigami.Units.smallSpacing * 3
                implicitHeight: chipLabel.implicitHeight + Kirigami.Units.smallSpacing * 1.4
                radius: height / 2
                color: active ? T.QN.alpha(Kirigami.Theme.highlightColor, 0.25) : T.QN.inputBg
                border.width: 1
                border.color: active ? Kirigami.Theme.highlightColor : T.QN.border
                QQC2.Label {
                    id: chipLabel
                    anchors.centerIn: parent
                    font: Kirigami.Theme.smallFont
                    color: active ? T.QN.text : T.QN.textDim
                    text: index === 4 && !isNaN(row.customWhen.getTime())
                          ? Qt.formatDateTime(row.customWhen, "ddd d MMM hh:mm")
                          : modelData
                }
                TapHandler {
                    onTapped: {
                        if (index === 4) picker.openFor(isNaN(row.customWhen.getTime()) ? new Date(Date.now() + 3600000) : row.customWhen, row.customRepeat);
                        else row.chipIndex = index;
                    }
                }
            }
        }
        Item { Layout.fillWidth: true }
    }

    QN.DateTimePopup {
        id: picker
        onPicked: (when, repeat) => { row.customWhen = when; row.customRepeat = repeat; row.chipIndex = 4; }
    }
}
```

- [ ] **Step 3: Swap add bar per mode in `FullView.qml`**

Replace the single `QuickAddBar` block with:

```qml
        QuickAddBar {
            id: quickAdd
            Layout.fillWidth: true
            visible: full.currentMode !== "reminders"
            placeholder: {
                switch (full.currentMode) {
                case "todo": return i18n("Add a task…  #tag !priority ^due");
                case "kanban": return i18n("Add a card…  #tag !priority");
                default: return i18n("Add a note…  #tag");
                }
            }
            onAddRequested: (p) => full.handleAdd(p)
        }
        ReminderAddRow {
            Layout.fillWidth: true
            visible: full.currentMode === "reminders"
            controller: full.controller
        }
```

(The `reminders` case in `handleAdd` becomes dead code; remove it.)

- [ ] **Step 4: RemindersView — due button opens picker; new empty hint**

In `RemindersView.qml`: change the empty-state hint to `i18n("Pick a time chip and add your first reminder.")`. Add at view level:

```qml
    QN.DateTimePopup {
        id: duePicker
        property string forId: ""
        onPicked: (when, repeat) => view.controller.updateItem("reminders", forId,
            { dueAt: when.toISOString(), repeat: repeat, notified: false, ackedAt: null })
    }
```

Replace the `appointment-new` ToolButton's `dueM` menu with a direct open, and DELETE the separate repeat ToolButton (`repM`) — the picker covers repeat now:

```qml
                                    QQC2.ToolButton {
                                        icon.name: "appointment-new"; flat: true
                                        icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                                        onClicked: { duePicker.forId = rrow.modelData.id;
                                                     duePicker.openFor(new Date(view.effDue(rrow.modelData)), rrow.modelData.repeat || "none"); }
                                        QQC2.ToolTip.text: i18n("Change time"); QQC2.ToolTip.visible: hovered
                                    }
```

- [ ] **Step 5: Card due date via same popup**

In `CardEditor.qml` add:

```qml
    QN.DateTimePopup {
        id: cardDue
        onPicked: (when, repeat) => ed.controller.setDue("cards", ed.cardId, when.toISOString())
    }
```

and next to the DueBadge:

```qml
            QQC2.Button {
                icon.name: "appointment-new"; text: i18n("Due…")
                onClicked: cardDue.openFor(ed.cardData && ed.cardData.dueAt ? new Date(ed.cardData.dueAt) : new Date(Date.now() + 86400000), "none")
            }
```

- [ ] **Step 6: Verify**

Run: `timeout 30 plasmoidviewer -a ./package -f planar -l floating 2>&1 | grep -iE "error|MonthGrid" || true`
Checklist: Reminders mode shows chip row instead of token placeholder; "buy milk" + default chip → reminder due in 1h under Upcoming; Custom… opens calendar, date+time+Weekly creates repeating reminder; clock button on existing reminder opens picker pre-filled; empty state shows new hint; other modes still show QuickAddBar.

- [ ] **Step 7: Commit**

```bash
git add package/contents/ui/components/DateTimePopup.qml package/contents/ui/ReminderAddRow.qml package/contents/ui/FullView.qml package/contents/ui/RemindersView.qml package/contents/ui/CardEditor.qml
git commit -m "feat: visual reminder time picker with chips and calendar popup

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Nav rail, view polish, compact panel

**Files:**
- Modify: `package/contents/ui/NavRail.qml`
- Modify: `package/contents/ui/FullView.qml` (chrome tokens, popup minimum, pass openTodos)
- Modify: `package/contents/ui/main.qml` (tooltip next-reminder preview)
- Modify: `package/contents/ui/QuickAddBar.qml`, `package/contents/ui/SearchBar.qml`, `package/contents/ui/ReminderAddRow.qml` (dark input styling)

**Interfaces:**
- Consumes: `T.QN` tokens; `controller.openTodoCount`, `controller.overdueCount` (exist in `main.qml`).
- Produces: NavRail gains `property int openTodos: 0` (FullView passes `controller.openTodoCount`).

- [ ] **Step 1: NavRail badges + neon active state**

Add `property int openTodos: 0` and `import "theme" as T`. Surface: `color: T.QN.alpha(T.QN.surface, 0.6)`. Inside the item delegate, add a soft glow ring for the active mode:

```qml
                Rectangle {
                    visible: item.active
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: T.QN.alpha(rail.accent, 0.25)
                    scale: 1.06
                    opacity: 0.6
                }
```

Duplicate the existing overdue-badge Rectangle for To-Do: `visible: item.modelData.id === "todo" && rail.openTodos > 0`, `color: rail.accent`, inner Text `color: "#0b0f1a"`, `text: rail.openTodos > 9 ? "9+" : rail.openTodos`. Labels: `color: item.active ? rail.accent : T.QN.textDim`.

In `FullView.qml` NavRail instantiation add `openTodos: controller ? controller.openTodoCount : 0`.

- [ ] **Step 2: FullView chrome tokens + popup minimum**

- Header `Kirigami.Heading` → add `color: T.QN.text`.
- Footer labels → `color: T.QN.textFaint`, remove their `opacity` hacks.
- Change `Layout.minimumWidth` from `gridUnit * 19` to `Kirigami.Units.gridUnit * 21`.

- [ ] **Step 3: Dark inputs for QuickAddBar + SearchBar + ReminderAddRow**

In each file add `import "theme" as T` and give each TextField:

```qml
        background: Rectangle {
            color: T.QN.inputBg
            radius: T.QN.radiusS
            border.width: 1
            border.color: parent.activeFocus ? T.QN.alpha(Kirigami.Theme.highlightColor, 0.6) : T.QN.border
        }
        color: T.QN.text
        placeholderTextColor: T.QN.textFaint
```

- [ ] **Step 4: Panel tooltip preview in `main.qml`**

Replace `toolTipSubText` binding with:

```qml
    toolTipSubText: {
        if (!loaded) return i18n("Loading…");
        var parts = [];
        if (doc && doc.reminders.length) {
            var next = null;
            for (var i = 0; i < doc.reminders.length; i++) {
                var r = doc.reminders[i];
                if (r.ackedAt && (!r.repeat || r.repeat === "none")) continue;
                var due = new Date(r.snoozeUntil || r.dueAt).getTime();
                if (due > nowMs && (!next || due < next.due)) next = { due: due, text: r.text };
            }
            if (next) parts.push(i18n("Next: %1 (%2)", next.text,
                Qt.formatDateTime(new Date(next.due), use24h ? "ddd hh:mm" : "ddd h:mm AP")));
        }
        if (openTodoCount > 0) parts.push(i18np("%1 open to-do", "%1 open to-dos", openTodoCount));
        if (overdueCount > 0) parts.push(i18np("%1 reminder due", "%1 reminders due", overdueCount));
        if (doc && doc.notes.length > 0) parts.push(i18np("%1 note", "%1 notes", doc.notes.length));
        return parts.length ? parts.join("  ·  ") : i18n("No notes yet — click to add one");
    }
```

- [ ] **Step 5: Verify**

Run: `timeout 30 plasmoidviewer -a ./package -f planar -l floating` and `timeout 20 plasmoidviewer -a ./package -f horizontal -l topedge`
Checklist: rail shows To-Do count badge + overdue badge; active mode glows; inputs dark with focus ring; popup can't shrink below 21gu wide; panel tooltip shows "Next: <reminder> (<time>)".

- [ ] **Step 6: Commit**

```bash
git add package/contents/ui/NavRail.qml package/contents/ui/FullView.qml package/contents/ui/main.qml package/contents/ui/QuickAddBar.qml package/contents/ui/SearchBar.qml package/contents/ui/ReminderAddRow.qml
git commit -m "feat: nav rail badges, dark inputs, popup minimums, tooltip preview

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: README rewrite

**Files:**
- Modify: `README.md` (full rewrite, keep all factual content)

- [ ] **Step 1: Rewrite `README.md`**

Structure copied from OctoPulse's README (`../Conqrex.OctoPulse/README.md`), content from the current QuickNotes README. Sections marked "keep verbatim" are copied from `git show HEAD:README.md` — nothing factual dropped, no literal ellipses left in the final file.

```markdown
<p align="center">
  <img src="package/contents/icons/quick-notes-banner.png" alt="Conqrex Quick Notes" width="720">
</p>

<p align="center">
  <b>Capture. Organize. Get things done.</b><br>
  A professional, all-in-one quick-noting widget for KDE Plasma 6 —
  notes, to-dos, kanban, reminders and search in one panel popup,
  with your data safe in a single local JSON file.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-3b82f6?style=flat-square" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/KDE-Plasma%206-1d99f3?style=flat-square&logo=kde&logoColor=white" alt="KDE Plasma 6">
  <img src="https://img.shields.io/badge/Made%20with-QML-41cd52?style=flat-square&logo=qt&logoColor=white" alt="QML">
</p>

<p align="center">
  <a href="#-install">Install</a> ·
  <a href="#-features">Features</a> ·
  <a href="#%EF%B8%8F-quick-add-tokens">Quick-add</a> ·
  <a href="#-where-your-data-lives">Data</a> ·
  <a href="#%EF%B8%8F-development">Development</a>
</p>

---

## ✨ Features

|     |     |
| --- | --- |
| 📝 **Notes** | Markdown bodies (bold/italic/code/lists/links), inline `- [ ]` checklists, per-note neon colors, pin, archive, recoverable trash, Obsidian-style `[[wiki-links]]` with backlinks. |
| ✅ **To-Do** | Status cycling (To Do → In Progress → Done), priorities, due dates, tags, quick-add. |
| 📋 **Kanban** | Fit-to-width columns with WIP limits, positional drag & drop, card editor, per-column quick-add. |
| ⏰ **Reminders** | Time-chip picker (In 1h · Tonight · Tomorrow · Custom calendar), repeats, native notifications, snooze, overdue badges. |
| 🔎 **Search** | Global fuzzy search across everything + tag cloud; rename-safe tags filter every mode at once. |
| 🖼 **Attachments** | Drag-drop images/files; content-addressed, deduplicated, reference-counted storage. |
| 🧊 **Conqrex dark look** | Banner-style navy-neon theme out of the box; one toggle to follow your system theme. |
| 🛟 **Data safety** | Atomic flock-serialized saves, rolling backups, crash-recovery journal, JSON/Markdown export, merge/replace import. |

The panel icon shows live badges for **overdue reminders** and **open to-dos**,
and its tooltip previews your next reminder.

## 📦 Install

```sh
git clone <repo-url>
cd Conqrex.QuickNotes
./install.sh            # installs or upgrades, per-user (no sudo)
```

Right-click your desktop or panel → **Add Widgets** → search **Conqrex Quick Notes**.

<details>
<summary>Reload Plasma after upgrading a local install</summary>

```sh
kquitapp6 plasmashell && kstart plasmashell
```

</details>

Package id: `com.conqrex.quicknotes`

## ⌨️ Quick-add tokens

[keep verbatim: the existing "Quick-add tokens" section — code example + the #tag/!priority/^due bullet list — plus one added closing line: "Tokens are optional power-user shortcuts; Reminders has a visual time picker."]

## 🗃 Where your data lives

[keep verbatim: the existing "Where your data lives" section — directory tree, atomicity paragraph, ⋮ Data menu paragraph, reminders-while-running blockquote]

## 🛠️ Development

[keep verbatim: the existing "Develop / preview" section — store.sh broker examples, plasmoidviewer commands, plasmawindowed]

## 🏛 Architecture

[keep verbatim: the existing "Architecture" paragraph]

## 🐙 Sibling projects

[**Conqrex.OctoPulse**](https://github.com/Conqrex/Conqrex.OctoPulse) — every GitHub Actions run in one panel widget.
[**Conqrex.Dockswain**](https://github.com/Conqrex/Conqrex.Dockswain) — manage Docker hosts over SSH from your panel.

## 📄 License

MIT © S. Aydin Icen
```

- [ ] **Step 2: Verify**

Run: `grep -c "keep verbatim" README.md` → Expected: `0` (all placeholders replaced with real content). Check anchors match emoji-heading slugs; banner path resolves.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: OctoPulse-style README with banner, badges and feature table

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Self-Review Notes

- Spec coverage: theme (T1), kanban layout+mechanics+editor (T2), reminders picker+edit reuse+empty hint (T3), nav/views/compact/tooltip/popup-min (T4), README (T5). Column reorder shipped as menu Move left/right per spec fallback. WIP glow → rose border + pulsing count (T2 S1/S6).
- Types: `moveCard(cardId, toCol, beforeId)` matches `main.qml:227`; `addReminder` fields flow through `Model.addReminder(doc, fields)`; `T.QN` import path differs by directory (`theme` from `ui/`, `../theme` from `ui/components/`) — stated in T1 interfaces.
- Known risk: `MonthGrid` import origin (QQC2 vs Qt.labs.calendar) — verification step T3 S6 catches it; fallback documented.
- Known risk: `ColorPicker`/`DueBadge` property names assumed (`current`/`picked`/`iso`) — T2 S4 instructs executor to read those components first and match reality.
- No automated tests exist in this project; every task carries a plasmoidviewer checklist instead of unit tests.
