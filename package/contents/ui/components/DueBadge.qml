import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "../../code/format.js" as Fmt

// Due/overdue badge with a humane countdown, colored by how close it is.
Rectangle {
    id: due
    property string iso: ""
    property double nowMs: 0
    property bool use24h: true

    readonly property string state: Fmt.dueState(iso, nowMs)
    visible: iso !== "" && state !== "none"

    readonly property color col: {
        switch (state) {
        case "overdue": return Kirigami.Theme.negativeTextColor;
        case "today":   return Kirigami.Theme.neutralTextColor;
        case "soon":    return Kirigami.Theme.neutralTextColor;
        default:        return Kirigami.Theme.positiveTextColor;
        }
    }

    implicitHeight: lbl.implicitHeight + Kirigami.Units.smallSpacing * 0.6
    implicitWidth: lbl.implicitWidth + Kirigami.Units.smallSpacing * 1.4
    radius: height / 2
    color: Qt.rgba(col.r, col.g, col.b, 0.16)
    border.width: 1
    border.color: Qt.rgba(col.r, col.g, col.b, 0.45)

    RowLayout {
        id: lbl
        anchors.centerIn: parent
        spacing: 3
        Kirigami.Icon {
            source: due.state === "overdue" ? "appointment-reminder" : "appointment-new"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small * 0.8
            Layout.preferredHeight: Kirigami.Units.iconSizes.small * 0.8
            color: due.col
        }
        PlasmaComponents.Label {
            text: Fmt.dueText(due.iso, due.nowMs, due.use24h)
            color: due.col
            font: Kirigami.Theme.smallFont
        }
    }
}
