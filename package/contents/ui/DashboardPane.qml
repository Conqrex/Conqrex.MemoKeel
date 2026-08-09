import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "theme" as T

// One titled section of the dashboard: a clickable title (which takes the user
// to that mode's tab), a count, an optional inline add row and a body.
//
// The body is a Component rather than a default child list because the pane
// declares its own chrome — a default property alias would swallow the header
// too. It scrolls on its own when the panes sit side by side; when they are
// stacked the pane is content-sized and the dashboard scrolls as a whole, so
// there is never a scroll area inside a scroll area.
ColumnLayout {
    id: pane

    property string title: ""
    property string iconName: ""
    property int count: 0
    property color tint: Kirigami.Theme.highlightColor
    property bool bodyScrolls: true
    property Component adder: null
    property Component bodyComponent: null

    signal titleActivated()

    spacing: Kirigami.Units.smallSpacing * 0.5

    // ---- title -----------------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: head.implicitHeight + Kirigami.Units.smallSpacing
        radius: T.QN.radiusS
        color: titleHover.hovered ? T.QN.alpha(pane.tint, 0.12) : "transparent"
        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

        HoverHandler { id: titleHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: pane.titleActivated() }
        QQC2.ToolTip.text: i18n("Open %1", pane.title)
        QQC2.ToolTip.visible: titleHover.hovered

        RowLayout {
            id: head
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing * 0.75
            anchors.rightMargin: Kirigami.Units.smallSpacing * 0.75
            spacing: Kirigami.Units.smallSpacing * 0.75

            Kirigami.Icon {
                source: pane.iconName
                color: pane.tint
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents.Label {
                text: pane.title
                font.bold: true
                color: pane.tint
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Rectangle {
                visible: pane.count > 0
                implicitWidth: Math.max(countLabel.implicitWidth + Kirigami.Units.smallSpacing,
                                        Kirigami.Units.gridUnit)
                implicitHeight: countLabel.implicitHeight + Kirigami.Units.smallSpacing * 0.3
                radius: height / 2
                color: T.QN.alpha(pane.tint, 0.18)
                PlasmaComponents.Label {
                    id: countLabel
                    anchors.centerIn: parent
                    text: pane.count
                    font: Kirigami.Theme.smallFont
                    color: pane.tint
                }
            }
            Kirigami.Icon {
                source: "go-next"
                color: pane.tint
                opacity: titleHover.hovered ? 0.9 : 0.35
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
        }
    }

    // ---- inline add ------------------------------------------------------
    Loader {
        Layout.fillWidth: true
        active: pane.adder !== null
        sourceComponent: pane.adder
    }

    // ---- body ------------------------------------------------------------
    QQC2.ScrollView {
        id: scroller
        Layout.fillWidth: true
        Layout.fillHeight: pane.bodyScrolls
        Layout.preferredHeight: pane.bodyScrolls ? -1 : body.implicitHeight
        contentWidth: availableWidth
        clip: true

        Loader {
            id: body
            width: scroller.availableWidth
            sourceComponent: pane.bodyComponent
        }
    }
}
