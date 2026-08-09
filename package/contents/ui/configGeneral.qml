import QtQuick
import QtCore
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    // alias-backed entries (auto-synced to config)
    property alias cfg_timeFormat24h: time24Box.checked
    property alias cfg_followSystemTheme: followSystemThemeBox.checked
    property alias cfg_sortDescending: sortDescBox.checked
    property alias cfg_popupWidthUnits: widthSpin.value
    property alias cfg_popupHeightUnits: heightSpin.value
    property alias cfg_remindersEnabled: remindersBox.checked
    property alias cfg_reminderPollSeconds: pollSpin.value
    property alias cfg_enableKanban: kanbanBox.checked
    property alias cfg_enableBoard: boardBox.checked
    property alias cfg_enableWikiLinks: wikiBox.checked
    property alias cfg_attachmentsEnabled: attachBox.checked
    property alias cfg_maxAttachmentMB: maxAttachSpin.value
    property alias cfg_trashRetentionDays: trashSpin.value
    property alias cfg_backupCount: backupSpin.value
    property alias cfg_autoBackupDaily: autoBackupBox.checked
    property alias cfg_autosaveDebounceMs: debounceSpin.value
    property alias cfg_dataDirOverride: dataDirField.text

    // combo-backed string entries
    property string cfg_accent: "cyan"
    property string cfg_defaultMode: "dashboard"
    property string cfg_sortBy: "updated"
    property string cfg_notifyUrgency: "normal"
    property string cfg_defaultNoteColor: ""

    function resolveDataDir() {
        var override = ("" + (page.cfg_dataDirOverride || "")).trim();
        if (override !== "") return override.replace(/^file:\/\//, "");
        var base = ("" + StandardPaths.writableLocation(StandardPaths.GenericDataLocation)).replace(/^file:\/\//, "");
        if (base.charAt(base.length - 1) === "/") base = base.substring(0, base.length - 1);
        return base + "/conqrex/memokeel";
    }

    Kirigami.FormLayout {

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Appearance") }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Accent:")
            textRole: "label"; valueRole: "key"
            model: [
                { key: "cyan", label: i18n("Cyan") },
                { key: "sky", label: i18n("Sky") },
                { key: "violet", label: i18n("Violet") },
                { key: "lime", label: i18n("Lime") },
                { key: "amber", label: i18n("Amber") },
                { key: "rose", label: i18n("Rose") },
                { key: "slate", label: i18n("Slate") }
            ]
            currentIndex: Math.max(0, indexOfValue(page.cfg_accent))
            onActivated: page.cfg_accent = currentValue
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("New notes color:")
            textRole: "label"; valueRole: "key"
            model: [
                { key: "", label: i18n("Default") },
                { key: "cyan", label: i18n("Cyan") },
                { key: "sky", label: i18n("Sky") },
                { key: "violet", label: i18n("Violet") },
                { key: "lime", label: i18n("Lime") },
                { key: "amber", label: i18n("Amber") },
                { key: "rose", label: i18n("Rose") },
                { key: "slate", label: i18n("Slate") }
            ]
            currentIndex: Math.max(0, indexOfValue(page.cfg_defaultNoteColor))
            onActivated: page.cfg_defaultNoteColor = currentValue
        }
        QQC2.CheckBox { id: time24Box; text: i18n("Use 24-hour time") }
        QQC2.CheckBox { id: followSystemThemeBox; text: i18n("Follow system theme instead of the dark Conqrex look") }
        QQC2.SpinBox { id: widthSpin; from: 16; to: 60; Kirigami.FormData.label: i18n("Popup width (units):") }
        QQC2.SpinBox { id: heightSpin; from: 14; to: 60; Kirigami.FormData.label: i18n("Popup height (units):") }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Behavior") }

        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Start on:")
            textRole: "label"; valueRole: "key"
            model: [
                { key: "dashboard", label: i18n("Dashboard") },
                { key: "notes", label: i18n("Notes") },
                { key: "todo", label: i18n("To-Do") },
                { key: "kanban", label: i18n("Kanban") },
                { key: "reminders", label: i18n("Reminders") },
                { key: "board", label: i18n("Board") },
                { key: "search", label: i18n("Search") },
                { key: "tags", label: i18n("Tags") }
            ]
            currentIndex: Math.max(0, indexOfValue(page.cfg_defaultMode))
            onActivated: page.cfg_defaultMode = currentValue
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Default sort:")
            QQC2.ComboBox {
                textRole: "label"; valueRole: "key"
                model: [
                    { key: "updated", label: i18n("Recently updated") },
                    { key: "created", label: i18n("Date created") },
                    { key: "title", label: i18n("Title") },
                    { key: "priority", label: i18n("Priority") },
                    { key: "due", label: i18n("Due date") }
                ]
                currentIndex: Math.max(0, indexOfValue(page.cfg_sortBy))
                onActivated: page.cfg_sortBy = currentValue
            }
            QQC2.CheckBox { id: sortDescBox; text: i18n("Descending") }
        }
        QQC2.SpinBox { id: debounceSpin; from: 200; to: 5000; stepSize: 100; Kirigami.FormData.label: i18n("Autosave delay (ms):") }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Reminders") }

        QQC2.CheckBox { id: remindersBox; text: i18n("Fire desktop notifications") }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("Urgency:")
            enabled: remindersBox.checked
            textRole: "label"; valueRole: "key"
            model: [
                { key: "low", label: i18n("Low") },
                { key: "normal", label: i18n("Normal") },
                { key: "critical", label: i18n("Critical") }
            ]
            currentIndex: Math.max(0, indexOfValue(page.cfg_notifyUrgency))
            onActivated: page.cfg_notifyUrgency = currentValue
        }
        QQC2.SpinBox { id: pollSpin; from: 15; to: 600; stepSize: 5; Kirigami.FormData.label: i18n("Check every (s):") }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.WordWrap; opacity: 0.7; font: Kirigami.Theme.smallFont
            text: i18n("Reminders fire only while the panel is running (they catch up when you next open it).")
        }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Modes & features") }

        QQC2.CheckBox { id: kanbanBox; text: i18n("Show the Kanban board") }
        QQC2.CheckBox { id: boardBox; text: i18n("Show the freeform Board (preview)") }
        QQC2.CheckBox { id: wikiBox; text: i18n("Parse [[wiki-links]] and backlinks") }
        QQC2.CheckBox { id: attachBox; text: i18n("Allow image / file attachments") }
        QQC2.SpinBox { id: maxAttachSpin; from: 1; to: 500; enabled: attachBox.checked; Kirigami.FormData.label: i18n("Max attachment (MB):") }

        Item { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Data & backups") }

        QQC2.SpinBox { id: trashSpin; from: 1; to: 365; Kirigami.FormData.label: i18n("Keep trash for (days):") }
        QQC2.SpinBox { id: backupSpin; from: 0; to: 100; Kirigami.FormData.label: i18n("Rolling backups:") }
        QQC2.CheckBox { id: autoBackupBox; text: i18n("Write a daily snapshot") }
        QQC2.TextField {
            id: dataDirField
            Kirigami.FormData.label: i18n("Data directory:")
            placeholderText: i18n("default")
            Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        }
        RowLayout {
            QQC2.Label {
                Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                text: page.resolveDataDir()
                elide: Text.ElideMiddle; opacity: 0.7; font: Kirigami.Theme.smallFont
            }
            QQC2.Button {
                icon.name: "folder-open"; text: i18n("Open")
                onClicked: Qt.openUrlExternally("file://" + page.resolveDataDir())
            }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 20
            wrapMode: Text.WordWrap; opacity: 0.7; font: Kirigami.Theme.smallFont
            text: i18n("Export, import and backup are in the widget itself (the ⋮ menu), where they work on your live data. Your notes survive widget upgrades because they live here, not in the package.")
        }
    }
}
