import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../theme" as T
import "../../code/theme.js" as Theme

// A row of neon swatches. Emits picked(key) where key is a palette key or "" for
// the default/theme color. The current selection gets a ring.
Flow {
    id: picker

    property string selected: ""
    signal picked(string key)

    spacing: Kirigami.Units.smallSpacing

    Repeater {
        model: Theme.ORDER
        delegate: Rectangle {
            required property var modelData
            readonly property bool isDefault: modelData === ""
            readonly property color swatch: isDefault
                ? Kirigami.Theme.highlightColor
                : Theme.accentFor(modelData, Kirigami.Theme.highlightColor)

            width: Kirigami.Units.gridUnit * 1.3
            height: width
            radius: width / 2
            color: isDefault ? Qt.rgba(swatch.r, swatch.g, swatch.b, 0.18) : swatch
            border.width: picker.selected === modelData ? 2 : 1
            border.color: picker.selected === modelData
                ? T.QN.text
                : Qt.rgba(swatch.r, swatch.g, swatch.b, 0.6)

            // a small glyph on the default swatch
            Text {
                anchors.centerIn: parent
                visible: parent.isDefault
                text: "—"
                color: T.QN.textDim
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: picker.picked(modelData)
            }
        }
    }
}
