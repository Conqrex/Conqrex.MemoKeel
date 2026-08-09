import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T
import "../code/grouping.js" as Grouping

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

    readonly property var groups: Grouping.reminderBuckets(controller ? controller.doc : null,
                                                           { nowMs: nowMs, query: query, tagId: tagFilter })
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
                        delegate: ReminderRow {
                            id: rrow
                            required property var modelData
                            Layout.fillWidth: true
                            controller: view.controller
                            reminder: modelData
                            nowMs: view.nowMs
                            use24h: view.use24h
                            accentFallback: view.accent
                            onEditTimeRequested: {
                                var eff = Grouping.effectiveDue(rrow.modelData);
                                duePicker.forId = rrow.modelData.id;
                                duePicker.forDueMs = eff ? new Date(eff).getTime() : NaN;
                                duePicker.hasValue = !!eff;
                                // new Date(null) is the epoch, not an invalid date, so a
                                // cleared reminder must be handed an explicitly invalid
                                // date for openFor's "default to now + 1h" fallback.
                                duePicker.openFor(eff ? new Date(eff) : new Date(NaN), rrow.modelData.repeat || "none");
                            }
                        }
                    }
                }
            }
        }
    }
}
