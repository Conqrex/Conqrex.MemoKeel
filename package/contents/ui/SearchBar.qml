import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "theme" as T

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
        hoverEnabled: true
        Keys.onEscapePressed: field.text = ""
        background: Rectangle {
            color: T.QN.inputBg
            radius: T.QN.radiusS
            border.width: 1
            border.color: field.activeFocus ? T.QN.alpha(Kirigami.Theme.highlightColor, 0.6)
                        : field.hovered ? T.QN.borderHi : T.QN.border
        }
        color: T.QN.text
        placeholderTextColor: T.QN.textFaint
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
