import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T
import "../code/search.js" as Search
import "../code/theme.js" as Theme
import "../code/format.js" as Fmt

// Reminders mode: active reminders grouped into Overdue / Today / Upcoming, plus
// a collapsed Done section. Each row supports snooze, acknowledge, repeat and due.
ColumnLayout {
    id: view

    property var controller
    property double nowMs: 0
    property bool use24h: true
    property color accent: Kirigami.Theme.highlightColor
    property string query: ""
    property string tagFilter: ""

    spacing: Kirigami.Units.smallSpacing

    function effDue(r) { return r.snoozeUntil || r.dueAt; }
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
    function isActive(r) { return (r.repeat && r.repeat !== "none") || !r.ackedAt; }

    function buckets(doc, q, tag) {
        var res = { overdue: [], today: [], upcoming: [], done: [] };
        if (!doc) return res;
        var list = doc.reminders.slice();
        if (tag) list = list.filter(function (r) { return (r.tagIds || []).indexOf(tag) >= 0; });
        if (q && q.trim() !== "") list = Search.rank(q, list, doc.tags);
        list.sort(function (a, b) { return new Date(view.effDue(a)) - new Date(view.effDue(b)); });
        for (var i = 0; i < list.length; i++) {
            var r = list[i];
            if (!view.isActive(r)) { res.done.push(r); continue; }
            var st = Fmt.dueState(view.effDue(r), view.nowMs);
            if (st === "overdue") res.overdue.push(r);
            else if (st === "today") res.today.push(r);
            else res.upcoming.push(r);
        }
        return res;
    }
    readonly property var groups: buckets(controller ? controller.doc : null, query, tagFilter)
    readonly property bool empty: groups.overdue.length + groups.today.length
                                + groups.upcoming.length + groups.done.length === 0

    QN.EmptyState {
        Layout.fillWidth: true; Layout.fillHeight: true
        visible: view.empty
        icon: "appointment-reminder"
        title: i18n("No reminders")
        hint: i18n("Pick a time chip and add your first reminder.")
    }

    QN.DateTimePopup {
        id: duePicker
        property string forId: ""
        // Effective due (snoozeUntil, else dueAt) of the reminder being edited, in
        // ms; NaN when unknown. This MUST be the same value openFor() is seeded
        // with, or a repeat-only edit would always look like a time change.
        property double forDueMs: NaN
        onPicked: (when, repeat) => {
            // Only a real time change resets the delivery state. Using the
            // picker purely to set a repeat must not un-ack the reminder or
            // drag it back into an active bucket. Compare at minute
            // granularity: the picker always zeroes seconds/ms, but the
            // stored due (e.g. from the default "In 1h" chip or a ^Nh
            // token) usually does not, so a full-precision compare would
            // spuriously report a change on a repeat-only edit. The baseline
            // is the *effective* due (snoozeUntil, else dueAt) because that is
            // exactly what the picker was prefilled with — comparing against
            // dueAt alone made every snoozed reminder look changed.
            var patch = { repeat: repeat, snoozeUntil: null };   // the user explicitly chose a time here, so any stale snooze never survives
            var whenMin = Math.floor(when.getTime() / 60000);
            var forDueMin = isNaN(duePicker.forDueMs) ? NaN : Math.floor(duePicker.forDueMs / 60000);
            if (isNaN(forDueMin) || whenMin !== forDueMin) {
                patch.dueAt = when.toISOString();
                patch.notified = false;
                patch.ackedAt = null;
            }
            view.controller.updateItem("reminders", duePicker.forId, patch);
        }
        onCleared: view.controller.updateItem("reminders", duePicker.forId,
                                              { dueAt: null, snoozeUntil: null, notified: false, ackedAt: null })
    }

    QQC2.ScrollView {
        visible: !view.empty
        Layout.fillWidth: true; Layout.fillHeight: true
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: view.width
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: [
                    { key: "overdue", label: i18n("Overdue"), color: Kirigami.Theme.negativeTextColor },
                    { key: "today", label: i18n("Today"), color: Kirigami.Theme.neutralTextColor },
                    { key: "upcoming", label: i18n("Upcoming"), color: view.accent },
                    { key: "done", label: i18n("Done"), color: T.QN.textFaint }
                ]
                delegate: ColumnLayout {
                    required property var modelData
                    readonly property var rows: view.groups[modelData.key]
                    Layout.fillWidth: true
                    visible: rows.length > 0
                    spacing: Kirigami.Units.smallSpacing * 0.5

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing * 0.5
                        Rectangle { width: Kirigami.Units.gridUnit * 0.4; height: width; radius: width / 2; color: modelData.color }
                        PlasmaComponents.Label { text: modelData.label + "  (" + rows.length + ")"; font.bold: true; color: T.QN.text }
                        Item { Layout.fillWidth: true }
                    }

                    Repeater {
                        model: parent.rows
                        delegate: QN.NeonCard {
                            id: rrow
                            required property var modelData
                            readonly property bool over: Fmt.dueState(view.effDue(modelData), view.nowMs) === "overdue" && view.isActive(modelData)
                            Layout.fillWidth: true
                            implicitHeight: rl.implicitHeight + Kirigami.Units.smallSpacing * 1.5
                            accent: rrow.over ? Kirigami.Theme.negativeTextColor : Theme.accentFor(modelData.color, view.accent)
                            hovered: rh.hovered
                            opacity: view.isActive(modelData) ? 1 : 0.55
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
                                        text: rrow.modelData.text
                                        background: null
                                        color: T.QN.text
                                        placeholderTextColor: T.QN.textFaint
                                        onEditingFinished: if (text !== rrow.modelData.text) view.controller.updateItem("reminders", rrow.modelData.id, { text: text })
                                    }
                                    RowLayout {
                                        spacing: Kirigami.Units.smallSpacing * 0.6
                                        QN.DueBadge { iso: view.effDue(rrow.modelData) || ""; nowMs: view.nowMs; use24h: view.use24h }
                                        RowLayout {
                                            visible: rrow.modelData.repeat && rrow.modelData.repeat !== "none"
                                            spacing: 2
                                            Kirigami.Icon { source: "view-refresh"; Layout.preferredWidth: Kirigami.Units.iconSizes.small * 0.8; Layout.preferredHeight: Kirigami.Units.iconSizes.small * 0.8; opacity: 0.6 }
                                            PlasmaComponents.Label { text: view.repeatLabel(rrow.modelData.repeat); font: Kirigami.Theme.smallFont; color: T.QN.textDim }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                }

                                Row {
                                    spacing: 0
                                    QQC2.ToolButton {
                                        icon.name: "appointment-new"; flat: true
                                        icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                                        onClicked: { var eff = view.effDue(rrow.modelData);
                                                     duePicker.forId = rrow.modelData.id;
                                                     duePicker.forDueMs = eff ? new Date(eff).getTime() : NaN;
                                                     duePicker.hasValue = !!eff;
                                                     // new Date(null) is the epoch, not an invalid date, so a
                                                     // cleared reminder must be handed an explicitly invalid
                                                     // date for openFor's "default to now + 1h" fallback.
                                                     duePicker.openFor(eff ? new Date(eff) : new Date(NaN), rrow.modelData.repeat || "none"); }
                                        QQC2.ToolTip.text: i18n("Change time"); QQC2.ToolTip.visible: hovered
                                    }
                                    QQC2.ToolButton {
                                        icon.name: "media-playback-pause"; flat: true
                                        icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                                        visible: view.isActive(rrow.modelData)
                                        onClicked: snM.open()
                                        QQC2.Menu {
                                            id: snM
                                            QQC2.MenuItem { text: i18n("Snooze 10 min"); onTriggered: view.controller.snoozeReminder(rrow.modelData.id, 10) }
                                            QQC2.MenuItem { text: i18n("Snooze 1 hour"); onTriggered: view.controller.snoozeReminder(rrow.modelData.id, 60) }
                                            QQC2.MenuItem { text: i18n("Snooze until tomorrow"); onTriggered: view.controller.snoozeReminder(rrow.modelData.id, 60 * 18) }
                                        }
                                        QQC2.ToolTip.text: i18n("Snooze"); QQC2.ToolTip.visible: hovered
                                    }
                                    QQC2.ToolButton {
                                        icon.name: "checkmark"; flat: true
                                        icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                                        visible: view.isActive(rrow.modelData)
                                        onClicked: view.controller.ackReminder(rrow.modelData.id)
                                        QQC2.ToolTip.text: i18n("Done"); QQC2.ToolTip.visible: hovered
                                    }
                                    QQC2.ToolButton {
                                        icon.name: "edit-delete"; flat: true
                                        icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                                        opacity: rh.hovered ? 1 : 0
                                        onClicked: view.controller.deleteItem("reminders", rrow.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
