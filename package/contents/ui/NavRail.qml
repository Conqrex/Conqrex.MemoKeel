import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "../code/theme.js" as Theme

// Left neon icon rail. Emits modeSelected(mode). Highlights the active mode with
// an accent glow and shows a badge of overdue reminders on the Reminders entry.
Rectangle {
    id: rail

    property string currentMode: "notes"
    property int overdue: 0
    property bool collapsed: false
    property bool enableKanban: true
    property bool enableBoard: false
    property color accent: Kirigami.Theme.highlightColor

    signal modeSelected(string mode)

    readonly property var modes: {
        var m = [
            { id: "notes",     label: i18n("Notes"),     icon: "view-pim-notes" },
            { id: "todo",      label: i18n("To-Do"),     icon: "view-pim-tasks" }
        ];
        if (enableKanban) m.push({ id: "kanban", label: i18n("Kanban"), icon: "view-calendar-tasks" });
        m.push({ id: "reminders", label: i18n("Reminders"), icon: "appointment-reminder" });
        if (enableBoard) m.push({ id: "board", label: i18n("Board"), icon: "view-presentation" });
        m.push({ id: "search", label: i18n("Search"), icon: "search" });
        return m;
    }

    implicitWidth: collapsed ? Kirigami.Units.gridUnit * 2.6 : Kirigami.Units.gridUnit * 7
    color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g,
                   Kirigami.Theme.backgroundColor.b, 0.4)
    radius: Kirigami.Units.smallSpacing

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing * 0.6

        Repeater {
            model: rail.modes
            delegate: Rectangle {
                id: item
                required property var modelData
                readonly property bool active: rail.currentMode === modelData.id

                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.1
                radius: Kirigami.Units.smallSpacing
                color: active ? Qt.rgba(rail.accent.r, rail.accent.g, rail.accent.b, 0.18)
                              : (hover.hovered ? Qt.rgba(rail.accent.r, rail.accent.g, rail.accent.b, 0.08)
                                               : "transparent")
                border.width: active ? 1 : 0
                border.color: Qt.rgba(rail.accent.r, rail.accent.g, rail.accent.b, 0.5)

                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

                // active accent stripe
                Rectangle {
                    visible: item.active
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3; height: parent.height * 0.55
                    radius: 1.5
                    color: rail.accent
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Kirigami.Units.smallSpacing * 1.5
                    anchors.rightMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Item {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        Kirigami.Icon {
                            anchors.fill: parent
                            source: item.modelData.icon
                            color: item.active ? rail.accent : Kirigami.Theme.textColor
                            opacity: item.active ? 1 : 0.8
                        }
                        // overdue badge on the reminders entry
                        Rectangle {
                            visible: item.modelData.id === "reminders" && rail.overdue > 0
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: -3
                            width: Kirigami.Units.gridUnit * 0.8
                            height: width
                            radius: width / 2
                            color: Kirigami.Theme.negativeTextColor
                            Text {
                                anchors.centerIn: parent
                                text: rail.overdue > 9 ? "9+" : rail.overdue
                                color: "white"
                                font.pixelSize: parent.height * 0.6
                                font.bold: true
                            }
                        }
                    }
                    PlasmaComponents.Label {
                        visible: !rail.collapsed
                        Layout.fillWidth: true
                        text: item.modelData.label
                        elide: Text.ElideRight
                        color: item.active ? rail.accent : Kirigami.Theme.textColor
                        font.bold: item.active
                    }
                }

                HoverHandler { id: hover }
                TapHandler { onTapped: rail.modeSelected(item.modelData.id) }

                PlasmaComponents.ToolTip {
                    text: item.modelData.label
                    visible: rail.collapsed && hover.hovered
                }
            }
        }

        Item { Layout.fillHeight: true }

        // collapse toggle
        QQC2.ToolButton {
            Layout.alignment: Qt.AlignHCenter
            icon.name: rail.collapsed ? "arrow-right" : "arrow-left"
            flat: true
            onClicked: rail.collapsed = !rail.collapsed
        }
    }
}
