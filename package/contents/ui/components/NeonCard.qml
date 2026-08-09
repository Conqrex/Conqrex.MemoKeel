import QtQuick
import org.kde.kirigami as Kirigami

// A reusable glassy card surface: translucent elevated background, rounded
// corners, a thin accent border that brightens on hover, and a left accent
// stripe. Children are placed directly inside; inset them past the stripe.
Rectangle {
    id: card

    property color accent: Kirigami.Theme.highlightColor
    property bool hovered: false
    property bool showStripe: true
    property real cardRadius: Kirigami.Units.smallSpacing * 1.6

    radius: cardRadius
    antialiasing: true

    readonly property color _bg: Kirigami.Theme.backgroundColor
    gradient: Gradient {
        GradientStop {
            position: 0.0
            color: Qt.rgba(card._bg.r + (1 - card._bg.r) * 0.06,
                           card._bg.g + (1 - card._bg.g) * 0.06,
                           card._bg.b + (1 - card._bg.b) * 0.06,
                           card.hovered ? 0.92 : 0.78)
        }
        GradientStop {
            position: 1.0
            color: Qt.rgba(card._bg.r, card._bg.g, card._bg.b, card.hovered ? 0.86 : 0.7)
        }
    }

    border.width: 1
    border.color: Qt.rgba(accent.r, accent.g, accent.b, hovered ? 0.65 : 0.28)

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
