import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
import "../code/model.js" as Model
import "../code/search.js" as Search
import "../code/theme.js" as Theme

// Kanban mode: horizontally scrolling columns of draggable cards. Drop a card on
// a column to move it there; per-column quick-add; WIP limits.
Item {
    id: kroot

    property var controller
    property double nowMs: 0
    property bool use24h: true
    property color accent: Kirigami.Theme.highlightColor
    property string query: ""
    property string tagFilter: ""

    signal openRequested(string id)   // wired by FullView; unused for cards

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

    QQC2.ScrollView {
        anchors.fill: parent
        visible: kroot.columns.length > 0
        contentHeight: availableHeight
        clip: true
        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AsNeeded

        RowLayout {
            height: kroot.height
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: kroot.columns
                delegate: Rectangle {
                    id: col
                    required property var modelData
                    readonly property string colId: modelData.id
                    readonly property var cards: kroot.colCards(colId)
                    readonly property bool overWip: modelData.wipLimit && cards.length > modelData.wipLimit
                    readonly property color colAccent: Theme.accentFor(modelData.color, kroot.accent)

                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    Layout.fillHeight: true
                    radius: Kirigami.Units.smallSpacing
                    color: Qt.rgba(col.colAccent.r, col.colAccent.g, col.colAccent.b, drop.containsDrag ? 0.18 : 0.06)
                    border.width: 1
                    border.color: Qt.rgba(col.colAccent.r, col.colAccent.g, col.colAccent.b, drop.containsDrag ? 0.7 : 0.2)

                    DropArea {
                        id: drop
                        anchors.fill: parent
                        onDropped: (d) => {
                            var s = d.source;
                            if (s && s.cardId) { kroot.controller.moveCard(s.cardId, col.colId, null); d.accept(); }
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
                                onEditingFinished: if (text !== col.modelData.title) kroot.controller.updateItem("columns", col.colId, { title: text })
                            }
                            PlasmaComponents.Label {
                                text: col.modelData.wipLimit ? (col.cards.length + "/" + col.modelData.wipLimit) : ("" + col.cards.length)
                                font: Kirigami.Theme.smallFont
                                color: col.overWip ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                                opacity: col.overWip ? 1 : 0.6
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
                                dragLayer: dragLayer
                            }
                        }

                        // per-column quick add
                        QQC2.TextField {
                            Layout.fillWidth: true
                            placeholderText: i18n("+ card")
                            font: Kirigami.Theme.smallFont
                            onAccepted: { if (text.trim() !== "") { kroot.controller.addCard(col.colId, { title: text.trim() }); text = ""; } }
                        }
                    }
                }
            }

            // add column
            QQC2.Button {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: Kirigami.Units.smallSpacing
                icon.name: "list-add"
                text: i18n("Column")
                flat: true
                onClicked: kroot.controller.addColumn({ title: i18n("New column") })
            }
        }
    }

    // shared drag layer so a dragged card floats above all columns
    Item { id: dragLayer; anchors.fill: parent; z: 999 }
}
