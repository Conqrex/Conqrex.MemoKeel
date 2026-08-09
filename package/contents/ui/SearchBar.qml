import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Global search/filter field. Exposes `text`; the FullView feeds it into the
// in-memory fuzzy index that narrows every mode.
RowLayout {
    id: bar
    property alias text: field.text
    spacing: Kirigami.Units.smallSpacing

    function clear() { field.text = ""; }
    function focusField() { field.forceActiveFocus(); }

    Kirigami.Icon {
        source: "search"
        Layout.preferredWidth: Kirigami.Units.iconSizes.small
        Layout.preferredHeight: Kirigami.Units.iconSizes.small
        opacity: 0.6
    }
    QQC2.TextField {
        id: field
        Layout.fillWidth: true
        placeholderText: i18n("Search notes, to-dos, tags…")
        selectByMouse: true
        Keys.onEscapePressed: field.text = ""
    }
    QQC2.ToolButton {
        visible: field.text !== ""
        icon.name: "edit-clear"
        flat: true
        onClicked: field.text = ""
        QQC2.ToolTip.text: i18n("Clear")
        QQC2.ToolTip.visible: hovered
    }
}
