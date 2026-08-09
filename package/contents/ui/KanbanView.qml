import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T
import "../code/model.js" as Model
import "../code/search.js" as Search
import "../code/theme.js" as Theme

// Kanban mode: columns share the available width (fit-to-width) and only scroll
// horizontally once they would go below a readable minimum. Each column pins its
// quick-add field to the bottom; dragging a card shows an accent insert line and
// drops it at that position. Clicking a card opens the card editor.
Item {
    id: kroot

    property var controller
    property double nowMs: 0
    property bool use24h: true
    property color accent: Kirigami.Theme.highlightColor
    property string query: ""
    property string tagFilter: ""

    signal editRequested(string id)

    readonly property var doc: controller ? controller.doc : null
    readonly property var columns: doc ? doc.columns.slice().sort(function (a, b) { return (a.order || 0) - (b.order || 0); }) : []

    function colCards(colId) {
        if (!doc) return [];
        var list = Model.cardsOf(doc, colId);
        if (kroot.tagFilter) list = list.filter(function (c) { return (c.tagIds || []).indexOf(kroot.tagFilter) >= 0; });
        if (kroot.query && kroot.query.trim() !== "") list = Search.rank(kroot.query, list, doc.tags);
        return list;
    }

    // empty board
    QN.EmptyState {
        anchors.centerIn: parent
        width: parent.width
        visible: kroot.columns.length === 0
        icon: "view-calendar-tasks"
        title: i18n("No board yet")
        hint: i18n("Create a starter board to organize cards into columns.")
    }
    QQC2.Button {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Kirigami.Units.gridUnit * 4
        visible: kroot.columns.length === 0
        icon.name: "list-add"
        text: i18n("Create board")
        highlighted: true
        onClicked: {
            kroot.controller.addColumn({ title: i18n("To Do"), order: 1 });
            kroot.controller.addColumn({ title: i18n("In Progress"), order: 2, color: "amber" });
            kroot.controller.addColumn({ title: i18n("Done"), order: 3, color: "lime" });
        }
    }

    Flickable {
        id: hflick
        anchors.fill: parent
        visible: kroot.columns.length > 0
        contentWidth: colRow.width
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar {
            id: hbar
            policy: colRow.width > hflick.width ? QQC2.ScrollBar.AlwaysOn : QQC2.ScrollBar.AlwaysOff
        }

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
                    readonly property int colIndex: kroot.columns.indexOf(modelData)

                    width: hflick.colW
                    height: colRow.height
                    radius: T.QN.radiusM
                    color: drop.containsDrag ? T.QN.alpha(col.colAccent, 0.10) : T.QN.surface
                    border.width: 1
                    border.color: drop.containsDrag ? T.QN.alpha(col.colAccent, 0.7)
                                : col.overWip ? T.QN.alpha(Theme.PALETTE.rose, 0.6) : T.QN.border

                    // pending insertion index while a card hovers over this column
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

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing * 0.6

                        // column header
                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle { width: 3; height: Kirigami.Units.gridUnit; radius: 1.5; color: col.colAccent }
                            QQC2.TextField {
                                Layout.fillWidth: true
                                text: col.modelData.title
                                background: null
                                font.bold: true
                                color: T.QN.text
                                onEditingFinished: if (text !== col.modelData.title) kroot.controller.updateItem("columns", col.colId, { title: text })
                            }
                            PlasmaComponents.Label {
                                id: wipLabel
                                property real pulse: 1
                                text: col.modelData.wipLimit ? (col.cards.length + "/" + col.modelData.wipLimit) : ("" + col.cards.length)
                                font: Kirigami.Theme.smallFont
                                color: col.overWip ? Theme.PALETTE.rose : T.QN.textDim
                                opacity: col.overWip ? wipLabel.pulse : 0.6
                                SequentialAnimation on pulse {
                                    running: col.overWip
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1; to: 0.4; duration: 700 }
                                    NumberAnimation { from: 0.4; to: 1; duration: 700 }
                                }
                            }
                            QQC2.ToolButton {
                                icon.name: "application-menu"; flat: true
                                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                                onClicked: colMenu.open()
                                QQC2.Menu {
                                    id: colMenu
                                    QQC2.Menu {
                                        title: i18n("Color")
                                        Repeater {
                                            model: Theme.ORDER
                                            QQC2.MenuItem {
                                                required property var modelData
                                                text: Theme.label(modelData)
                                                onTriggered: kroot.controller.setColor("columns", col.colId, modelData)
                                            }
                                        }
                                    }
                                    QQC2.MenuItem { text: i18n("Set WIP limit…"); onTriggered: wipDialog.open() }
                                    QQC2.MenuItem { text: i18n("Clear WIP limit"); onTriggered: kroot.controller.updateItem("columns", col.colId, { wipLimit: null }) }
                                    QQC2.MenuSeparator {}
                                    QQC2.MenuItem {
                                        text: i18n("Move left")
                                        enabled: col.colIndex > 0
                                        onTriggered: kroot.controller.updateItem("columns", col.colId, { order: (kroot.columns[col.colIndex - 1].order || 0) - 0.5 })
                                    }
                                    QQC2.MenuItem {
                                        text: i18n("Move right")
                                        enabled: col.colIndex >= 0 && col.colIndex < kroot.columns.length - 1
                                        onTriggered: kroot.controller.updateItem("columns", col.colId, { order: (kroot.columns[col.colIndex + 1].order || 0) + 0.5 })
                                    }
                                    QQC2.MenuSeparator {}
                                    QQC2.MenuItem { text: i18n("Delete column"); icon.name: "edit-delete"; onTriggered: kroot.controller.deleteItem("columns", col.colId) }
                                }
                                QQC2.Dialog {
                                    id: wipDialog
                                    title: i18n("WIP limit")
                                    standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
                                    QQC2.SpinBox { id: wipSpin; from: 1; to: 99; value: col.modelData.wipLimit || 5 }
                                    onAccepted: kroot.controller.updateItem("columns", col.colId, { wipLimit: wipSpin.value })
                                }
                            }
                        }

                        // cards
                        ListView {
                            id: cardList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: Kirigami.Units.smallSpacing * 0.6
                            model: col.cards
                            QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: cardBar }

                            // map a y in column coords to an insertion index
                            function insertIndexAt(colY) {
                                var y = colY - cardList.mapToItem(col, 0, 0).y + cardList.contentY;
                                for (var i = 0; i < count; i++) {
                                    var it = itemAtIndex(i);
                                    if (it && y < it.y + it.height / 2) return i;
                                }
                                return count;
                            }

                            delegate: KanbanCard {
                                required property var modelData
                                width: cardList.width - (cardBar.visible ? Kirigami.Units.gridUnit : 0)
                                controller: kroot.controller
                                cardData: modelData
                                columns: kroot.columns
                                tagsMap: kroot.doc ? kroot.doc.tags : ({})
                                nowMs: kroot.nowMs
                                use24h: kroot.use24h
                                accentFallback: kroot.accent
                                dragLayer: cardDragLayer
                                onEditRequested: (id) => kroot.editRequested(id)
                            }
                        }

                        // per-column quick add
                        QQC2.TextField {
                            Layout.fillWidth: true
                            placeholderText: i18n("+ card")
                            font: Kirigami.Theme.smallFont
                            color: T.QN.text
                            onAccepted: { if (text.trim() !== "") { kroot.controller.addCard(col.colId, { title: text.trim() }); text = ""; } }
                        }
                    }

                    // insertion indicator — a sibling of the ListView so its y is in
                    // column coordinates and it is not clipped by the list's content item
                    Rectangle {
                        id: dropLine
                        visible: drop.containsDrag && dropIdx.idx >= 0
                        z: 10
                        height: 2
                        radius: 1
                        color: col.colAccent
                        x: cardList.mapToItem(col, 0, 0).x
                        width: cardList.width
                        y: {
                            var base = cardList.mapToItem(col, 0, 0).y;
                            if (dropIdx.idx <= 0) return base;
                            var it = cardList.itemAtIndex(Math.min(dropIdx.idx, cardList.count) - 1);
                            return it ? base + it.y + it.height + cardList.spacing / 2 - cardList.contentY : base;
                        }
                    }
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

    // shared drag layer so a dragged card floats above all columns
    Item { id: cardDragLayer; anchors.fill: parent; z: 999 }
}
