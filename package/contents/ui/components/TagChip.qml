import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "../theme" as T

// A small tag pill: colored dot + #name, optionally removable, clickable to filter.
Rectangle {
    id: chip

    property string tagName: ""
    property color tagColor: Kirigami.Theme.highlightColor
    property bool removable: false
    property bool active: false
    property int count: -1

    signal clicked()
    signal removeClicked()

    implicitHeight: Kirigami.Units.gridUnit * 1.15
    implicitWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
    radius: height / 2
    color: active ? Qt.rgba(tagColor.r, tagColor.g, tagColor.b, 0.28)
                  : Qt.rgba(tagColor.r, tagColor.g, tagColor.b, 0.12)
    border.width: 1
    border.color: Qt.rgba(tagColor.r, tagColor.g, tagColor.b, active ? 0.8 : 0.35)

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing * 0.7

        Rectangle {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 0.42
            Layout.preferredHeight: Kirigami.Units.gridUnit * 0.42
            radius: width / 2
            color: chip.tagColor
        }
        PlasmaComponents.Label {
            text: "#" + chip.tagName + (chip.count >= 0 ? "  " + chip.count : "")
            font: Kirigami.Theme.smallFont
            color: T.QN.text
        }
        PlasmaComponents.Label {
            visible: chip.removable
            text: "✕"
            color: T.QN.textDim
            font: Kirigami.Theme.smallFont
            MouseArea {
                anchors.fill: parent
                anchors.margins: -3
                cursorShape: Qt.PointingHandCursor
                onClicked: chip.removeClicked()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: chip.clicked()
        z: -1
    }
}
