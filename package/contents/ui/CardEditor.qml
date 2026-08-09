import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T

// Modal card editor sheet: title, body, column, priority, due, color.
// Text edits are debounced to the controller and flushed on destruction (same
// pattern as NoteEditor.qml), so dismissing the sheet never loses typing.
Rectangle {
    id: ed

    property var controller
    property string cardId: ""
    property double nowMs: 0
    property bool use24h: true
    signal closed()

    readonly property var doc: controller ? controller.doc : null
    readonly property var cardData: {
        if (!doc) return null;
        for (var i = 0; i < doc.cards.length; i++) if (doc.cards[i].id === cardId) return doc.cards[i];
        return null;
    }
    readonly property var columns: doc ? doc.columns.slice().sort(function (a, b) { return (a.order || 0) - (b.order || 0); }) : []
    readonly property int columnIndex: {
        if (!cardData) return -1;
        for (var i = 0; i < columns.length; i++) if (columns[i].id === cardData.columnId) return i;
        return -1;
    }
    readonly property int priorityIndex: cardData ? (cardData.priority || 0) : 0

    color: T.QN.surface
    radius: T.QN.radiusL
    border.width: 1
    border.color: T.QN.borderHi
    visible: cardData !== null

    // ---- debounced text commit (mirrors NoteEditor) --------------------------
    property bool _loading: false
    function load() {
        _loading = true;
        var c = ed.cardData;
        titleField.text = c ? (c.title || "") : "";
        bodyArea.text = c ? (c.body || "") : "";
        _loading = false;
    }
    function markDirty() { if (!ed._loading) commitTimer.restart(); }
    function commit() {
        if (!ed.controller || ed.cardId === "" || !ed.cardData) return;
        ed.controller.updateItem("cards", ed.cardId, { title: titleField.text, body: bodyArea.text });
    }
    function flush() { if (commitTimer.running) { commitTimer.stop(); ed.commit(); } }

    Component.onCompleted: load()
    onCardIdChanged: load()
    Component.onDestruction: flush()
    Timer { id: commitTimer; interval: 700; onTriggered: ed.commit() }

    QN.DateTimePopup {
        id: cardDue
        // Cards have no repeat field in the schema, so the repeat control is
        // hidden rather than shown and silently ignored.
        showRepeat: false
        hasValue: !!(ed.cardData && ed.cardData.dueAt)
        onPicked: (when, repeat) => ed.controller.setDue("cards", ed.cardId, when.toISOString())
        onCleared: ed.controller.setDue("cards", ed.cardId, null)
    }

    // swallow clicks so they don't reach the dimmer behind the sheet
    MouseArea { anchors.fill: parent; onClicked: (m) => m.accepted = true }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Heading { level: 4; text: i18n("Edit card"); color: T.QN.text }
            Item { Layout.fillWidth: true }
            QQC2.ToolButton { icon.name: "window-close"; flat: true; onClicked: { ed.flush(); ed.closed(); } }
        }

        QQC2.TextField {
            id: titleField
            Layout.fillWidth: true
            placeholderText: i18n("Title")
            selectByMouse: true
            hoverEnabled: true
            background: Rectangle {
                color: T.QN.inputBg
                radius: T.QN.radiusS
                border.width: 1
                border.color: titleField.activeFocus ? T.QN.alpha(Kirigami.Theme.highlightColor, 0.6)
                            : titleField.hovered ? T.QN.borderHi : T.QN.border
            }
            color: T.QN.text
            placeholderTextColor: T.QN.textFaint
            onTextChanged: ed.markDirty()
        }

        QQC2.TextArea {
            id: bodyArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            placeholderText: i18n("Description")
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            hoverEnabled: true
            background: Rectangle {
                color: T.QN.inputBg
                radius: T.QN.radiusS
                border.width: 1
                border.color: bodyArea.activeFocus ? T.QN.alpha(Kirigami.Theme.highlightColor, 0.6)
                            : bodyArea.hovered ? T.QN.borderHi : T.QN.border
            }
            color: T.QN.text
            placeholderTextColor: T.QN.textFaint
            onTextChanged: ed.markDirty()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.ComboBox {
                id: columnCombo
                Layout.fillWidth: true
                model: ed.columns.map(function (c) { return c.title; })
                onActivated: (i) => {
                    if (ed.cardData && ed.columns[i] && ed.columns[i].id !== ed.cardData.columnId)
                        ed.controller.moveCard(ed.cardId, ed.columns[i].id, null);
                }
                // currentIndex is never assigned imperatively here: activation makes the
                // ComboBox write it itself and the model rebuild resets it to 0, so the
                // index is (re)asserted from the card's real state after the dust settles.
                Binding {
                    target: columnCombo
                    property: "currentIndex"
                    value: ed.columnIndex
                    delayed: true
                    restoreMode: Binding.RestoreNone
                }
            }

            QQC2.ComboBox {
                id: priorityCombo
                model: [i18n("No priority"), i18n("Low"), i18n("Medium"), i18n("High"), i18n("Urgent")]
                onActivated: (i) => ed.controller.setPriority("cards", ed.cardId, i)
                Binding {
                    target: priorityCombo
                    property: "currentIndex"
                    value: ed.priorityIndex
                    delayed: true
                    restoreMode: Binding.RestoreNone
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            QN.DueBadge { iso: (ed.cardData && ed.cardData.dueAt) ? ed.cardData.dueAt : ""; nowMs: ed.nowMs; use24h: ed.use24h }
            QQC2.Button {
                icon.name: "appointment-new"; text: i18n("Due…")
                onClicked: cardDue.openFor(ed.cardData && ed.cardData.dueAt ? new Date(ed.cardData.dueAt) : new Date(Date.now() + 86400000), "none")
            }
            Item { Layout.fillWidth: true }
            QN.ColorPicker {
                selected: ed.cardData ? (ed.cardData.color || "") : ""
                onPicked: (key) => ed.controller.setColor("cards", ed.cardId, key)
            }
            QQC2.Button {
                icon.name: "edit-delete"
                text: i18n("Delete")
                onClicked: {
                    commitTimer.stop();
                    ed.controller.deleteItem("cards", ed.cardId);
                    ed.closed();
                }
            }
        }
    }
}
