import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "theme" as T

// Top navigation strip. Replaces the old left NavRail: same neon active
// treatment (accent pill + glow ring + accent stripe) and the same badge
// shape, laid out horizontally so the content below gets the full popup
// width. Emits modeSelected(mode).
Item {
    id: tabs

    property string currentMode: "dashboard"
    property int overdue: 0
    property int openTodos: 0
    property bool enableKanban: true
    property bool enableBoard: false
    property color accent: Kirigami.Theme.highlightColor

    signal modeSelected(string mode)

    readonly property var modes: {
        var m = [
            { id: "dashboard", label: i18n("Dashboard"), icon: "view-list-icons" },
            { id: "notes",     label: i18n("Notes"),     icon: "view-pim-notes" },
            { id: "todo",      label: i18n("To-Do"),     icon: "view-pim-tasks" }
        ];
        if (enableKanban) m.push({ id: "kanban", label: i18n("Kanban"), icon: "view-calendar-tasks" });
        m.push({ id: "reminders", label: i18n("Reminders"), icon: "appointment-reminder" });
        if (enableBoard) m.push({ id: "board", label: i18n("Board"), icon: "view-presentation" });
        m.push({ id: "search", label: i18n("Search"), icon: "search" });
        m.push({ id: "tags",   label: i18n("Tags"),   icon: "tag" });
        return m;
    }
    readonly property int count: modes.length

    // Position-based access, used by FullView's Ctrl+1…7 shortcuts: the
    // numbering must follow what is actually on screen, so it is derived from
    // this model (which already drops the disabled modes), never a fixed list.
    function modeAt(i) { return (i >= 0 && i < tabs.modes.length) ? tabs.modes[i].id : ""; }
    function indexOfMode(m) {
        for (var i = 0; i < tabs.modes.length; i++) if (tabs.modes[i].id === m) return i;
        return -1;
    }
    function selectIndex(i) {
        var m = tabs.modeAt(i);
        if (m !== "") tabs.modeSelected(m);
    }
    function step(delta) {
        var i = tabs.indexOfMode(tabs.currentMode);
        if (i < 0) i = 0;
        tabs.selectIndex(Math.max(0, Math.min(tabs.modes.length - 1, i + delta)));
    }

    // ---- metrics -----------------------------------------------------------
    // Expanded-active-tab presentation: every tab is an icon, and only the
    // active one also renders its label. That fits at any popup width, so
    // there is no width measurement and no icons-only breakpoint to compute —
    // the label font and padding are the rail's normal ones again.
    readonly property real hPad: Kirigami.Units.smallSpacing * 1.5
    readonly property real gap: Kirigami.Units.smallSpacing
    readonly property real iconSize: Kirigami.Units.iconSizes.smallMedium
    readonly property real itemHeight: Kirigami.Units.gridUnit * 2.1

    implicitHeight: itemHeight + Kirigami.Units.smallSpacing
    implicitWidth: tabRow.width + Kirigami.Units.smallSpacing

    activeFocusOnTab: true
    Keys.onLeftPressed: tabs.step(-1)
    Keys.onRightPressed: tabs.step(1)

    onCurrentModeChanged: Qt.callLater(tabs.ensureVisible)
    onWidthChanged: Qt.callLater(tabs.ensureVisible)
    function ensureVisible() {
        var i = tabs.indexOfMode(tabs.currentMode);
        if (i < 0) return;
        var it = strip.itemAt(i);
        if (!it) return;
        if (it.x < flick.contentX)
            flick.contentX = it.x;
        else if (it.x + it.width > flick.contentX + flick.width)
            flick.contentX = Math.max(0, it.x + it.width - flick.width);
    }

    Rectangle {
        anchors.fill: parent
        color: T.QN.alpha(T.QN.surface, 0.6)
        radius: Kirigami.Units.smallSpacing
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 0.5
        clip: true
        interactive: contentWidth > width
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: tabRow.width
        contentHeight: height

        // wheel over the strip scrolls it when the tabs overflow
        QQC2.ScrollBar.horizontal: QQC2.ScrollBar { policy: QQC2.ScrollBar.AsNeeded; height: 2 }

        Row {
            id: tabRow
            height: parent.height
            spacing: tabs.gap

            Repeater {
                id: strip
                model: tabs.modes

                delegate: Rectangle {
                    id: item
                    required property var modelData
                    required property int index
                    readonly property bool active: tabs.currentMode === modelData.id

                    width: tabs.hPad * 2 + tabs.iconSize
                           + (active ? tabs.gap + label.implicitWidth : 0)
                    height: tabs.itemHeight
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Kirigami.Units.smallSpacing
                    color: active ? Qt.rgba(tabs.accent.r, tabs.accent.g, tabs.accent.b, 0.18)
                                  : (hover.hovered ? Qt.rgba(tabs.accent.r, tabs.accent.g, tabs.accent.b, 0.08)
                                                   : "transparent")
                    border.width: active ? 1 : 0
                    border.color: Qt.rgba(tabs.accent.r, tabs.accent.g, tabs.accent.b, 0.5)

                    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

                    // soft glow ring for the active tab
                    Rectangle {
                        visible: item.active
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 1
                        border.color: T.QN.alpha(tabs.accent, 0.25)
                        scale: 1.06
                        opacity: 0.6
                    }

                    // keyboard focus ring (the strip itself takes tab focus)
                    Rectangle {
                        visible: item.active && tabs.activeFocus
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 1
                        border.color: Kirigami.Theme.highlightColor
                    }

                    // active accent stripe — the rail's left stripe, rotated to
                    // the bottom edge now that the strip runs horizontally
                    Rectangle {
                        visible: item.active
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * 0.55
                        height: 3
                        radius: 1.5
                        color: tabs.accent
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: tabs.gap

                        Item {
                            width: tabs.iconSize
                            height: tabs.iconSize
                            anchors.verticalCenter: parent.verticalCenter

                            Kirigami.Icon {
                                anchors.fill: parent
                                source: item.modelData.icon
                                color: item.active ? tabs.accent : T.QN.textDim
                            }
                            // overdue badge on Reminders
                            Rectangle {
                                visible: item.modelData.id === "reminders" && tabs.overdue > 0
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: -3
                                width: Kirigami.Units.gridUnit * 0.8
                                height: width
                                radius: width / 2
                                color: Kirigami.Theme.negativeTextColor
                                Text {
                                    anchors.centerIn: parent
                                    text: tabs.overdue > 9 ? i18n("9+") : tabs.overdue
                                    color: "white"
                                    font.pixelSize: parent.height * 0.6
                                    font.bold: true
                                }
                            }
                            // open to-do badge on To-Do
                            Rectangle {
                                visible: item.modelData.id === "todo" && tabs.openTodos > 0
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: -3
                                width: Kirigami.Units.gridUnit * 0.8
                                height: width
                                radius: width / 2
                                color: tabs.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: tabs.openTodos > 9 ? i18n("9+") : tabs.openTodos
                                    color: "#0b0f1a"
                                    font.pixelSize: parent.height * 0.6
                                    font.bold: true
                                }
                            }
                        }
                        // Only the active tab is labelled — the accent-coloured
                        // label is one more active cue on top of the pill and
                        // the stripe, and inactive tabs stay icon-width so the
                        // strip fits at any popup width and in any language.
                        PlasmaComponents.Label {
                            id: label
                            visible: item.active
                            anchors.verticalCenter: parent.verticalCenter
                            text: item.modelData.label
                            color: tabs.accent
                        }
                    }

                    HoverHandler { id: hover }
                    TapHandler { onTapped: tabs.modeSelected(item.modelData.id) }

                    // Every tab gets a tooltip; only the first seven can carry a
                    // Ctrl-number hint, because only those have a shortcut.
                    PlasmaComponents.ToolTip {
                        text: item.index < 7
                              ? i18n("%1 (Ctrl+%2)", item.modelData.label, item.index + 1)
                              : item.modelData.label
                        visible: hover.hovered
                    }
                }
            }
        }
    }
}
