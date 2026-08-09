import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// A transient status pill anchored at the bottom of the popup. Call show(text).
Rectangle {
    id: toast

    property string message: ""

    function show(text) {
        if (!text) return;
        toast.message = text;
        toast.opacity = 1;
        hideTimer.restart();
    }

    radius: height / 2
    color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g,
                   Kirigami.Theme.highlightColor.b, 0.92)
    implicitWidth: row.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: row.implicitHeight + Kirigami.Units.smallSpacing * 1.5
    opacity: 0
    visible: opacity > 0.01

    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            source: "dialog-information"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            color: Kirigami.Theme.highlightedTextColor
        }
        PlasmaComponents.Label {
            text: toast.message
            color: Kirigami.Theme.highlightedTextColor
            font.bold: true
        }
    }

    Timer { id: hideTimer; interval: 2600; onTriggered: toast.opacity = 0 }

    MouseArea { anchors.fill: parent; onClicked: toast.opacity = 0 }
}
