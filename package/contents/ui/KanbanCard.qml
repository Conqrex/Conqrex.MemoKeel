import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T
import "../code/theme.js" as Theme

// A draggable kanban card. Dragging reparents it to the shared drag layer so it
// floats above the columns; a column's DropArea reads cardId on drop. A "move to"
// menu is the reliable fallback. Clicking the card asks for the editor.
QN.NeonCard {
    id: card

    signal editRequested(string id)

    property var controller
    property var cardData
    property var columns: []
    property var tagsMap: ({})
    property double nowMs: 0
    property bool use24h: true
    property color accentFallback: Kirigami.Theme.highlightColor
    property Item dragLayer: null

    readonly property string cardId: cardData.id
    accent: cardData.priority > 0 ? Theme.priorityColor(cardData.priority, accentFallback)
                                  : Theme.accentFor(cardData.color, accentFallback)
    hovered: ch.hovered || drag.active
    implicitHeight: cl.implicitHeight + Kirigami.Units.smallSpacing * 1.4
    z: drag.active ? 1000 : 0
    opacity: drag.active ? 0.85 : 1

    Drag.active: drag.active
    Drag.source: card
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: Kirigami.Units.gridUnit

    HoverHandler { id: ch }
    TapHandler {
        id: cardTap
        acceptedButtons: Qt.LeftButton
        // Same threshold as the DragHandler: a gesture is either a drag or a tap,
        // never both. (The default is the system startDragDistance, which is larger
        // than the drag threshold below, so a short drag used to do both.)
        dragThreshold: drag.dragThreshold
        onTapped: (ep) => {
            // the ⋮ button is a child of the card; a tap that lands inside its bounds
            // must not also open the editor. Gate purely on tap position — not on the
            // button's enabled state, which stays true regardless of hover/visibility
            // so touch and keyboard focus traversal can always reach it.
            if (menuBtn.contains(menuBtn.mapFromItem(card, ep.position)))
                return;
            card.editRequested(card.cardId);
        }
    }
    DragHandler {
        id: drag
        // small threshold so taps/edits aren't treated as drags
        dragThreshold: Kirigami.Units.gridUnit / 2
    }

    states: State {
        when: drag.active
        ParentChange { target: card; parent: card.dragLayer }
    }

    ColumnLayout {
        id: cl
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing * 1.6
        anchors.rightMargin: Kirigami.Units.smallSpacing
        anchors.topMargin: Kirigami.Units.smallSpacing * 0.7
        anchors.bottomMargin: Kirigami.Units.smallSpacing * 0.7
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 0.5
            QN.PriorityBadge { priority: card.cardData.priority }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: card.cardData.title || i18n("(untitled)")
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                color: T.QN.text
            }
            QQC2.ToolButton {
                id: menuBtn
                icon.name: "application-menu"; flat: true
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                opacity: ch.hovered || cardMenu.visible ? 1 : 0
                // kept enabled (not just opacity-hidden) so touch and keyboard focus
                // traversal can still reach it — this is the documented fallback for
                // moving cards, so it must stay genuinely reachable, not just visible
                onClicked: cardMenu.open()
                QQC2.Menu {
                    id: cardMenu
                    QQC2.Menu {
                        title: i18n("Move to")
                        Repeater {
                            model: card.columns
                            QQC2.MenuItem {
                                required property var modelData
                                text: modelData.title
                                enabled: modelData.id !== card.cardData.columnId
                                onTriggered: card.controller.moveCard(card.cardId, modelData.id, null)
                            }
                        }
                    }
                    QQC2.Menu {
                        title: i18n("Priority")
                        QQC2.MenuItem { text: i18n("Urgent"); onTriggered: card.controller.setPriority("cards", card.cardId, 4) }
                        QQC2.MenuItem { text: i18n("High"); onTriggered: card.controller.setPriority("cards", card.cardId, 3) }
                        QQC2.MenuItem { text: i18n("Medium"); onTriggered: card.controller.setPriority("cards", card.cardId, 2) }
                        QQC2.MenuItem { text: i18n("Low"); onTriggered: card.controller.setPriority("cards", card.cardId, 1) }
                        QQC2.MenuItem { text: i18n("None"); onTriggered: card.controller.setPriority("cards", card.cardId, 0) }
                    }
                    QQC2.MenuItem { text: i18n("Delete"); icon.name: "edit-delete"; onTriggered: card.controller.deleteItem("cards", card.cardId) }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: card.cardData.dueAt || (card.cardData.tagIds && card.cardData.tagIds.length > 0)
            spacing: Kirigami.Units.smallSpacing * 0.5
            QN.DueBadge { iso: card.cardData.dueAt || ""; nowMs: card.nowMs; use24h: card.use24h }
            Flow {
                Layout.fillWidth: true
                spacing: 3
                Repeater {
                    model: card.cardData.tagIds || []
                    delegate: QN.TagChip {
                        required property var modelData
                        readonly property var tag: card.tagsMap[modelData]
                        visible: !!tag
                        tagName: tag ? tag.name : ""
                        tagColor: tag ? Theme.accentFor(tag.color, card.accentFallback) : card.accentFallback
                    }
                }
            }
        }
    }
}
