import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// A centered placeholder for an empty mode.
ColumnLayout {
    id: empty
    property string icon: "edit-none"
    property string title: ""
    property string hint: ""

    spacing: Kirigami.Units.smallSpacing

    Kirigami.Icon {
        Layout.alignment: Qt.AlignHCenter
        source: empty.icon
        Layout.preferredWidth: Kirigami.Units.iconSizes.huge
        Layout.preferredHeight: Kirigami.Units.iconSizes.huge
        opacity: 0.4
    }
    PlasmaComponents.Label {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: empty.title
        font.bold: true
        opacity: 0.8
        wrapMode: Text.WordWrap
    }
    PlasmaComponents.Label {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 18
        visible: empty.hint !== ""
        horizontalAlignment: Text.AlignHCenter
        text: empty.hint
        opacity: 0.55
        font: Kirigami.Theme.smallFont
        wrapMode: Text.WordWrap
    }
}
