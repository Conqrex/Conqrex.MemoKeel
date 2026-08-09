import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "components" as QN

// Freeform Milanote-style board — planned for a future release. The data model
// already carries each card's boardPos, so this slots in without data changes.
Item {
    id: board
    property var controller
    property color accent: Kirigami.Theme.highlightColor

    // faint neon grid backdrop, hinting at what's coming
    Canvas {
        anchors.fill: parent
        opacity: 0.12
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = board.accent;
            ctx.lineWidth = 1;
            var step = Kirigami.Units.gridUnit * 2;
            for (var x = 0; x < width; x += step) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke(); }
            for (var y = 0; y < height; y += step) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke(); }
        }
    }

    QN.EmptyState {
        anchors.centerIn: parent
        width: parent.width
        icon: "view-presentation"
        title: i18n("Freeform board — coming soon")
        hint: i18n("A pannable canvas for arranging note and image cards visually. Your other data is unaffected.")
    }
}
