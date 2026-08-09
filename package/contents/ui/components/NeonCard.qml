import QtQuick
import org.kde.kirigami as Kirigami
import "../theme" as T

// A reusable glassy card surface on the QN token palette: dark elevated
// gradient, rounded corners, accent border that brightens on hover, and a
// left accent stripe. Children are placed directly inside; inset past stripe.
Rectangle {
    id: card

    property color accent: Kirigami.Theme.highlightColor
    property bool hovered: false
    property bool showStripe: true
    property real cardRadius: T.QN.radiusM

    radius: cardRadius
    antialiasing: true

    gradient: Gradient {
        GradientStop { position: 0.0; color: card.hovered ? T.QN.surfaceHi : T.QN.surface }
        GradientStop { position: 1.0; color: Qt.darker(T.QN.surface, card.hovered ? 1.02 : 1.12) }
    }

    border.width: 1
    border.color: T.QN.alpha(card.accent, card.hovered ? 0.65 : 0.25)
    Behavior on border.color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

    // left accent stripe
    Rectangle {
        visible: card.showStripe
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 1.5
        width: 3
        radius: width / 2
        color: card.accent
        opacity: card.hovered ? 0.95 : 0.7
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
    }
}
