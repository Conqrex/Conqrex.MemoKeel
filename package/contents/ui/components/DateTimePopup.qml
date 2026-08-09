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

    readonly property var repeatKeys: ["none", "daily", "weekly", "monthly"]
    // The window-wide overlay: used both to centre the popup and to clamp it
    // inside the widget so it never opens at (0,0) of its declaring item.
    readonly property Item ovl: QQC2.Overlay.overlay

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
    anchors.centerIn: pop.ovl
    padding: Kirigami.Units.largeSpacing
    // Never exceed the widget: at the popup's minimum size the calendar scrolls
    // instead of overflowing past the edges.
    width: pop.ovl ? Math.min(implicitWidth, pop.ovl.width - Kirigami.Units.smallSpacing * 2) : implicitWidth
    height: pop.ovl ? Math.min(implicitHeight, pop.ovl.height - Kirigami.Units.smallSpacing * 2) : implicitHeight
    background: Rectangle { color: T.QN.surface; radius: T.QN.radiusM; border.width: 1; border.color: T.QN.borderHi }

    contentItem: Flickable {
        id: flick
        implicitWidth: col.implicitWidth
        implicitHeight: col.implicitHeight
        contentWidth: col.width
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {
            policy: flick.contentHeight > flick.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
        }
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar {
            policy: flick.contentWidth > flick.width ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
        }

        ColumnLayout {
            id: col
            width: Math.max(implicitWidth, flick.width)
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

            QQC2.DayOfWeekRow {
                Layout.fillWidth: true
                locale: grid.locale
                // Themed: the default Basic delegate uses the palette text
                // colour, which is unreadable on T.QN.surface.
                delegate: QQC2.Label {
                    required property var model
                    text: model.shortName
                    color: T.QN.textDim
                    font: Kirigami.Theme.smallFont
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            QQC2.MonthGrid {
                id: grid
                Layout.fillWidth: true
                month: pop.shown.getMonth()
                year: pop.shown.getFullYear()
                delegate: Rectangle {
                    required property var model
                    implicitWidth: Kirigami.Units.gridUnit * 1.6
                    implicitHeight: Kirigami.Units.gridUnit * 1.5
                    radius: T.QN.radiusS
                    readonly property bool isSel: model.day === pop.sel.getDate()
                                               && model.month === pop.sel.getMonth()
                                               && model.year === pop.sel.getFullYear()
                    color: isSel ? T.QN.alpha(Kirigami.Theme.highlightColor, 0.35) : "transparent"
                    opacity: model.month === grid.month ? 1 : 0.3
                    QQC2.Label { anchors.centerIn: parent; text: model.day; color: T.QN.text }
                    TapHandler {
                        onTapped: {
                            // Compose from the spinboxes so sel always matches
                            // what Set would produce.
                            pop.sel = new Date(model.year, model.month, model.day, hourBox.value, minBox.value, 0, 0);
                            // Tapping a faded adjacent-month day navigates there,
                            // so the highlight is always on a full-opacity cell.
                            if (model.month !== grid.month || model.year !== grid.year)
                                pop.shown = new Date(model.year, model.month, 1);
                        }
                    }
                }
            }

            // time
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                QQC2.SpinBox { id: hourBox; from: 0; to: 23; value: 9;  wrap: true }
                QQC2.Label { text: ":"; color: T.QN.text }
                QQC2.SpinBox { id: minBox;  from: 0; to: 59; value: 0; wrap: true; stepSize: 5 }
                Item { Layout.fillWidth: true }
            }

            // repeat — its own row so the popup stays narrow enough for the
            // widget's minimum width
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                QQC2.ComboBox {
                    id: repBox
                    Layout.fillWidth: true
                    model: [i18n("Does not repeat"), i18n("Daily"), i18n("Weekly"), i18n("Monthly")]
                    onActivated: (i) => pop.repeat = pop.repeatKeys[i]
                    // currentIndex is never bound declaratively here: activation
                    // makes the ComboBox write it itself, which would destroy a
                    // plain binding. Re-assert it from pop.repeat once settled.
                    Binding {
                        target: repBox
                        property: "currentIndex"
                        value: Math.max(0, pop.repeatKeys.indexOf(pop.repeat))
                        delayed: true
                        restoreMode: Binding.RestoreNone
                    }
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
}
