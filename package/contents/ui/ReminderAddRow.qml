import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T
import "../code/tokens.js" as Tokens

// Reminder add row: text + time chips + custom picker. No token syntax needed,
// but the shared #tag/!priority/^due parser still runs so anyone who types a
// token gets what they asked for — a typed ^due beats the selected chip.
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
        var raw = field.text.trim();
        if (raw === "") return;
        var p = Tokens.parse(raw);
        if (p.text === "") return;
        // A typed ^token wins over the chip; otherwise the chip selection applies.
        var due = p.dueAt ? new Date(p.dueAt) : chipDue(row.chipIndex);
        if (isNaN(due.getTime())) { picker.openFor(new Date(Date.now() + 3600000), row.customRepeat); return; }
        var id = row.controller.addReminder({ text: p.text, dueAt: due.toISOString(),
                                              repeat: row.chipIndex === 4 ? row.customRepeat : "none" });
        if (id && p.tagNames.length) row.controller.applyTagNames("reminders", id, p.tagNames);
        field.text = "";
        row.chipIndex = 0;
        row.customWhen = new Date(NaN);
        row.customRepeat = "none";
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
