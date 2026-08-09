import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T
import "../code/theme.js" as Theme
import "../code/format.js" as Fmt
import "../code/grouping.js" as Grouping

// One reminder: inline-editable text, its effective due badge, the repeat hint
// and the snooze / done / delete actions. Shared by the Reminders mode and the
// dashboard's due pane. Changing the time needs a date picker, which the owner
// hosts (the Reminders mode has one) — hence `editTimeRequested` instead of a
// second copy of the picker's rules.
QN.NeonCard {
    id: row

    property var controller
    property var reminder
    property double nowMs: 0
    property bool use24h: true
    property color accentFallback: Kirigami.Theme.highlightColor
    // Off where no date picker is available to open.
    property bool canEditTime: true

    signal editTimeRequested()

    readonly property bool active: Grouping.isActive(reminder)
    readonly property bool over: Fmt.dueState(Grouping.effectiveDue(reminder), row.nowMs) === "overdue" && row.active

    // Human label for a stored repeat key. Wording matches DateTimePopup's combo
    // so the row and the picker never disagree.
    function repeatLabel(key) {
        switch (key) {
        case "daily":   return i18n("Daily");
        case "weekly":  return i18n("Weekly");
        case "monthly": return i18n("Monthly");
        default:        return i18n("Does not repeat");
        }
    }

    implicitHeight: rl.implicitHeight + Kirigami.Units.smallSpacing * 1.5
    accent: row.over ? Kirigami.Theme.negativeTextColor : Theme.accentFor(reminder.color, row.accentFallback)
    hovered: rh.hovered
    opacity: row.active ? 1 : 0.55
    HoverHandler { id: rh }

    RowLayout {
        id: rl
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing * 1.6
        anchors.rightMargin: Kirigami.Units.smallSpacing
        anchors.topMargin: Kirigami.Units.smallSpacing * 0.75
        anchors.bottomMargin: Kirigami.Units.smallSpacing * 0.75
        spacing: Kirigami.Units.smallSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            QQC2.TextField {
                Layout.fillWidth: true
                text: row.reminder.text
                background: null
                color: T.QN.text
                placeholderTextColor: T.QN.textFaint
                onEditingFinished: if (text !== row.reminder.text) row.controller.updateItem("reminders", row.reminder.id, { text: text })
            }
            RowLayout {
                spacing: Kirigami.Units.smallSpacing * 0.6
                QN.DueBadge { iso: Grouping.effectiveDue(row.reminder) || ""; nowMs: row.nowMs; use24h: row.use24h }
                RowLayout {
                    visible: row.reminder.repeat && row.reminder.repeat !== "none"
                    spacing: 2
                    Kirigami.Icon { source: "view-refresh"; Layout.preferredWidth: Kirigami.Units.iconSizes.small * 0.8; Layout.preferredHeight: Kirigami.Units.iconSizes.small * 0.8; opacity: 0.6 }
                    PlasmaComponents.Label { text: row.repeatLabel(row.reminder.repeat); font: Kirigami.Theme.smallFont; color: T.QN.textDim }
                }
                Item { Layout.fillWidth: true }
            }
        }

        Row {
            spacing: 0
            QQC2.ToolButton {
                icon.name: "appointment-new"; flat: true
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                visible: row.canEditTime
                onClicked: row.editTimeRequested()
                QQC2.ToolTip.text: i18n("Change time"); QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
                icon.name: "media-playback-pause"; flat: true
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                visible: row.active
                onClicked: snM.open()
                QQC2.Menu {
                    id: snM
                    QQC2.MenuItem { text: i18n("Snooze 10 min"); onTriggered: row.controller.snoozeReminder(row.reminder.id, 10) }
                    QQC2.MenuItem { text: i18n("Snooze 1 hour"); onTriggered: row.controller.snoozeReminder(row.reminder.id, 60) }
                    QQC2.MenuItem { text: i18n("Snooze until tomorrow"); onTriggered: row.controller.snoozeReminder(row.reminder.id, 60 * 18) }
                }
                QQC2.ToolTip.text: i18n("Snooze"); QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
                icon.name: "checkmark"; flat: true
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                visible: row.active
                onClicked: row.controller.ackReminder(row.reminder.id)
                QQC2.ToolTip.text: i18n("Done"); QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
                icon.name: "edit-delete"; flat: true
                icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                opacity: rh.hovered ? 1 : 0
                onClicked: row.controller.deleteItem("reminders", row.reminder.id)
            }
        }
    }
}
