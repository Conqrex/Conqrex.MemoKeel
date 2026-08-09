import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "../code/theme.js" as Theme

// Panel/compact view: the widget icon with small badges for due reminders (red)
// and open to-dos (accent). Clicking toggles the popup.
MouseArea {
    id: ca

    property int overdue: 0
    property int openTodos: 0
    property string accentKey: "cyan"

    signal toggleRequested()

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool horizontal: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property int side: Math.min(width, height)
    readonly property color accent: Theme.accentFor(accentKey, Kirigami.Theme.highlightColor)

    hoverEnabled: true
    onClicked: ca.toggleRequested()

    Layout.minimumWidth: horizontal ? height : Kirigami.Units.iconSizes.small
    Layout.minimumHeight: vertical ? width : Kirigami.Units.iconSizes.small
    Layout.preferredWidth: horizontal ? height : Layout.minimumWidth
    Layout.preferredHeight: vertical ? width : Layout.minimumHeight

    Kirigami.Icon {
        id: icon
        anchors.centerIn: parent
        width: ca.side
        height: ca.side
        source: "com.conqrex.quicknotes"
        // fall back to a generic note icon if the package icon doesn't resolve
        fallback: "view-pim-notes"
        active: ca.containsMouse
    }

    // overdue reminders badge (top-right, red)
    Rectangle {
        visible: ca.overdue > 0 && ca.side >= 22
        anchors.right: icon.right
        anchors.top: icon.top
        width: Math.max(Kirigami.Units.gridUnit * 0.85, ca.side * 0.42)
        height: width
        radius: width / 2
        color: Kirigami.Theme.negativeTextColor
        border.width: 1
        border.color: Kirigami.Theme.backgroundColor
        Text {
            anchors.centerIn: parent
            text: ca.overdue > 9 ? "9+" : ca.overdue
            color: "white"
            font.bold: true
            font.pixelSize: parent.height * 0.62
        }
    }

    // open to-dos badge (bottom-right, accent) — only when no overdue badge fights for space
    Rectangle {
        visible: ca.openTodos > 0 && ca.overdue === 0 && ca.side >= 22
        anchors.right: icon.right
        anchors.bottom: icon.bottom
        width: Math.max(Kirigami.Units.gridUnit * 0.85, ca.side * 0.42)
        height: width
        radius: width / 2
        color: ca.accent
        border.width: 1
        border.color: Kirigami.Theme.backgroundColor
        Text {
            anchors.centerIn: parent
            text: ca.openTodos > 9 ? "9+" : ca.openTodos
            color: "#0b0f1a"
            font.bold: true
            font.pixelSize: parent.height * 0.62
        }
    }
}
