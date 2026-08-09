import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T

// Modal card editor sheet: title, body, column, priority, due, color.
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

    color: T.QN.surface
    radius: T.QN.radiusL
    border.width: 1
    border.color: T.QN.borderHi
    visible: cardData !== null

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
            QQC2.ToolButton { icon.name: "window-close"; flat: true; onClicked: ed.closed() }
        }

        QQC2.TextField {
            Layout.fillWidth: true
            text: ed.cardData ? ed.cardData.title : ""
            placeholderText: i18n("Title")
            color: T.QN.text
            onEditingFinished: if (ed.cardData && text !== ed.cardData.title) ed.controller.updateItem("cards", ed.cardId, { title: text })
        }

        QQC2.TextArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: (ed.cardData && ed.cardData.body) ? ed.cardData.body : ""
            placeholderText: i18n("Description")
            wrapMode: TextEdit.Wrap
            color: T.QN.text
            onEditingFinished: if (ed.cardData && text !== (ed.cardData.body || "")) ed.controller.updateItem("cards", ed.cardId, { body: text })
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            QQC2.ComboBox {
                Layout.fillWidth: true
                model: ed.columns.map(function (c) { return c.title; })
                currentIndex: {
                    for (var i = 0; i < ed.columns.length; i++)
                        if (ed.cardData && ed.columns[i].id === ed.cardData.columnId) return i;
                    return 0;
                }
                onActivated: (i) => ed.controller.moveCard(ed.cardId, ed.columns[i].id, null)
            }
            QQC2.ComboBox {
                model: [i18n("No priority"), i18n("Low"), i18n("Medium"), i18n("High"), i18n("Urgent")]
                currentIndex: ed.cardData ? (ed.cardData.priority || 0) : 0
                onActivated: (i) => ed.controller.setPriority("cards", ed.cardId, i)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            QN.DueBadge { iso: (ed.cardData && ed.cardData.dueAt) ? ed.cardData.dueAt : ""; nowMs: ed.nowMs; use24h: ed.use24h }
            Item { Layout.fillWidth: true }
            QN.ColorPicker {
                selected: ed.cardData ? (ed.cardData.color || "") : ""
                onPicked: (key) => ed.controller.setColor("cards", ed.cardId, key)
            }
            QQC2.Button {
                icon.name: "edit-delete"
                text: i18n("Delete")
                onClicked: { ed.controller.deleteItem("cards", ed.cardId); ed.closed(); }
            }
        }
    }
}
