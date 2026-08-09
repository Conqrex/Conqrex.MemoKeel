import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "theme" as T
import "../code/tokens.js" as Tokens

// Always-visible add row. Parses ClickUp-style inline tokens:
//   #tag        add a tag           (repeatable)
//   !1.. !4     priority            (or !low/!med/!high/!urgent)
//   ^today ^tomorrow ^3h ^2d ^14:30 due date
// and emits addRequested({text, tagNames, priority, dueAt}).
RowLayout {
    id: bar
    property string placeholder: i18n("Quick add… (#tag !priority ^due)")
    // keyboard hint rendered dimmed inside the field, e.g. "Ctrl+N"
    property string hint: ""
    signal addRequested(var payload)

    spacing: Kirigami.Units.smallSpacing

    function focusField() { field.forceActiveFocus(); }

    // Token parsing lives in code/tokens.js so ReminderAddRow shares it verbatim.
    function submit() {
        var raw = field.text.trim();
        if (raw === "") return;
        bar.addRequested(Tokens.parse(raw));
        field.text = "";
    }

    QQC2.TextField {
        id: field
        Layout.fillWidth: true
        placeholderText: bar.placeholder
        selectByMouse: true
        hoverEnabled: true
        onAccepted: bar.submit()
        background: Rectangle {
            color: T.QN.inputBg
            radius: T.QN.radiusS
            border.width: 1
            border.color: field.activeFocus ? T.QN.alpha(Kirigami.Theme.highlightColor, 0.6)
                        : field.hovered ? T.QN.borderHi : T.QN.border
        }
        color: T.QN.text
        placeholderTextColor: T.QN.textFaint
        rightPadding: hintLabel.visible
                      ? hintLabel.implicitWidth + Kirigami.Units.smallSpacing * 3
                      : Kirigami.Units.smallSpacing * 2

        QQC2.Label {
            id: hintLabel
            visible: bar.hint !== "" && field.text === ""
            anchors.right: parent.right
            anchors.rightMargin: Kirigami.Units.smallSpacing * 1.5
            anchors.verticalCenter: parent.verticalCenter
            text: bar.hint
            color: T.QN.textFaint
            font: Kirigami.Theme.smallFont
        }
    }
    QQC2.Button {
        icon.name: "list-add"
        text: i18n("Add")
        highlighted: true
        onClicked: bar.submit()
    }
}
