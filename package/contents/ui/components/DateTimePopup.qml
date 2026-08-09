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
