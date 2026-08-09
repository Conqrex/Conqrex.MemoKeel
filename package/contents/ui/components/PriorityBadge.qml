import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "../../code/theme.js" as Theme
import "../../code/format.js" as Fmt

// A compact priority indicator: a colored flag glyph and an optional label.
RowLayout {
    id: badge
    property int priority: 0
    property bool showLabel: false

    readonly property color col: Theme.priorityColor(priority, Kirigami.Theme.disabledTextColor)
    visible: priority > 0
    spacing: Kirigami.Units.smallSpacing * 0.6

    Rectangle {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 0.4
        Layout.preferredHeight: Kirigami.Units.gridUnit * 0.9
        radius: 1.5
        color: badge.col
    }
    PlasmaComponents.Label {
        visible: badge.showLabel
        text: Fmt.priorityLabel(badge.priority)
        color: badge.col
        font: Kirigami.Theme.smallFont
    }
}
