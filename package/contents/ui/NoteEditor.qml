import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
import "../code/markdown.js" as Md
import "../code/search.js" as Search
import "../code/format.js" as Fmt
import "../code/theme.js" as Theme

// Expanded note editor: title + markdown body with Edit/Preview, inline checklist
// helper, tag editor, attachments and a backlinks panel. Edits are debounced to
// the controller and flushed on close; the text fields are populated once per
// note so commits never disturb the cursor.
QN.NeonCard {
    id: editor

    property var controller
    property string noteId: ""
    property double nowMs: 0
    property bool use24h: true

    signal closed()
    signal tagActivated(string tagId)
    signal openNote(string id)

    // reactive lookup (tags/attachments/meta) — text fields are NOT bound to it
    readonly property var note: lookup(controller ? controller.doc : null, noteId)
    accent: note ? Theme.accentFor(note.color, Kirigami.Theme.highlightColor) : Kirigami.Theme.highlightColor

    function lookup(doc, id) {
        if (!doc) return null;
        for (var i = 0; i < doc.notes.length; i++) if (doc.notes[i].id === id) return doc.notes[i];
        return null;
    }

    property bool _loading: false
    function load() {
        _loading = true;
        var n = lookup(controller ? controller.doc : null, noteId);
        titleField.text = n ? n.title : "";
        bodyArea.text = n ? n.body : "";
        _loading = false;
    }
    function markDirty() { if (!_loading) commitTimer.restart(); }
    function commit() {
        if (!controller || noteId === "") return;
        controller.updateNote(noteId, { title: titleField.text, body: bodyArea.text });
    }
    function flush() { if (commitTimer.running) { commitTimer.stop(); commit(); } }

    Component.onCompleted: load()
    onNoteIdChanged: load()
    Component.onDestruction: flush()
    Timer { id: commitTimer; interval: 700; onTriggered: editor.commit() }

    // backlinks (notes referencing this one) when wiki-links are enabled
    readonly property var backlinkIds: {
        if (!Plasmoid.configuration.enableWikiLinks || !controller || !controller.doc || !note) return [];
        var idx = Search.buildLinkIndex(controller.doc.notes);
        return idx.backlinks[noteId] || [];
    }

    MouseArea { anchors.fill: parent } // swallow clicks so the backdrop doesn't close

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.bottomMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // header: title + actions
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            QQC2.TextField {
                id: titleField
                Layout.fillWidth: true
                placeholderText: i18n("Title")
                font.bold: true
                onTextChanged: editor.markDirty()
            }
            QQC2.ToolButton {
                icon.name: editor.note && editor.note.pinned ? "bookmark-remove" : "bookmarks"
                flat: true
                onClicked: editor.controller.togglePin(editor.noteId)
                QQC2.ToolTip.text: i18n("Pin"); QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
                icon.name: "color-management"
                flat: true
                onClicked: colorPop.open()
                QQC2.Popup {
                    id: colorPop
                    y: parent.height
                    QN.ColorPicker {
                        selected: editor.note ? editor.note.color : ""
                        onPicked: (k) => { editor.controller.setColor("notes", editor.noteId, k); colorPop.close(); }
                    }
                }
            }
            QQC2.ToolButton {
                icon.name: "window-close"
                flat: true
                onClicked: { editor.flush(); editor.closed(); }
            }
        }

        // edit / preview tabs
        QQC2.TabBar {
            id: tabs
            Layout.fillWidth: true
            QQC2.TabButton { text: i18n("Edit") }
            QQC2.TabButton { text: i18n("Preview") }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabs.currentIndex

            // --- edit ---
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing * 0.5
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    QQC2.ToolButton {
                        icon.name: "checkbox"; flat: true
                        onClicked: { bodyArea.insert(bodyArea.cursorPosition, (bodyArea.length > 0 ? "\n" : "") + "- [ ] "); bodyArea.forceActiveFocus(); }
                        QQC2.ToolTip.text: i18n("Insert checklist item"); QQC2.ToolTip.visible: hovered
                    }
                    QQC2.ToolButton {
                        text: "B"; font.bold: true; flat: true
                        onClicked: editor.wrapSelection("**")
                        QQC2.ToolTip.text: i18n("Bold"); QQC2.ToolTip.visible: hovered
                    }
                    QQC2.ToolButton {
                        text: "I"; font.italic: true; flat: true
                        onClicked: editor.wrapSelection("*")
                        QQC2.ToolTip.text: i18n("Italic"); QQC2.ToolTip.visible: hovered
                    }
                    QQC2.ToolButton {
                        text: "[[ ]]"; flat: true; font: Kirigami.Theme.smallFont
                        onClicked: { bodyArea.insert(bodyArea.cursorPosition, "[[]]"); bodyArea.cursorPosition -= 2; bodyArea.forceActiveFocus(); }
                        QQC2.ToolTip.text: i18n("Link to a note"); QQC2.ToolTip.visible: hovered
                    }
                    Item { Layout.fillWidth: true }
                }
                QQC2.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    QQC2.TextArea {
                        id: bodyArea
                        placeholderText: i18n("Write in Markdown… use - [ ] for checklists and [[Title]] to link notes.")
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        onTextChanged: editor.markDirty()
                    }
                }
            }

            // --- preview ---
            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                TextEdit {
                    readOnly: true
                    textFormat: TextEdit.RichText
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    color: Kirigami.Theme.textColor
                    text: Md.toRichText(bodyArea.text)
                    onLinkActivated: (link) => {
                        if (link.indexOf("qn-wiki:") === 0) {
                            var title = link.substring(8);
                            var idx = Search.buildLinkIndex(editor.controller.doc.notes);
                            var id = idx.byTitle[title.toLowerCase()];
                            if (id) { editor.flush(); editor.openNote(id); }
                        } else {
                            Qt.openUrlExternally(link);
                        }
                    }
                }
            }
        }

        // tags
        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 0.6
            Repeater {
                model: editor.note ? editor.note.tagIds : []
                delegate: QN.TagChip {
                    required property var modelData
                    readonly property var tag: editor.controller.doc.tags[modelData]
                    visible: !!tag
                    tagName: tag ? tag.name : ""
                    tagColor: tag ? Theme.accentFor(tag.color, editor.accent) : editor.accent
                    removable: true
                    onRemoveClicked: editor.controller.removeTagFromItem("notes", editor.noteId, modelData)
                    onClicked: editor.tagActivated(modelData)
                }
            }
            QQC2.TextField {
                id: tagField
                placeholderText: i18n("+ tag")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                onAccepted: {
                    var name = text.trim().replace(/^#/, "");
                    if (name !== "") {
                        var id = editor.controller.ensureTag(name);
                        if (id) editor.controller.addTagToItem("notes", editor.noteId, id);
                    }
                    text = "";
                }
            }
        }

        // attachments
        QN.AttachmentStrip {
            Layout.fillWidth: true
            visible: Plasmoid.configuration.attachmentsEnabled
            controller: editor.controller
            coll: "notes"
            itemId: editor.noteId
            attachmentIds: editor.note ? editor.note.attachmentIds : []
            accent: editor.accent
            addEnabled: Plasmoid.configuration.attachmentsEnabled
        }

        // backlinks
        ColumnLayout {
            Layout.fillWidth: true
            visible: editor.backlinkIds.length > 0
            spacing: 2
            PlasmaComponents.Label { text: i18n("Linked from"); font: Kirigami.Theme.smallFont; opacity: 0.6 }
            Flow {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing * 0.6
                Repeater {
                    model: editor.backlinkIds
                    delegate: QN.NeonCard {
                        required property var modelData
                        readonly property var bn: editor.lookup(editor.controller.doc, modelData)
                        width: lbl.implicitWidth + Kirigami.Units.smallSpacing * 2.5
                        height: lbl.implicitHeight + Kirigami.Units.smallSpacing
                        showStripe: false
                        accent: editor.accent
                        PlasmaComponents.Label {
                            id: lbl
                            anchors.centerIn: parent
                            text: bn ? (bn.title || i18n("Untitled")) : ""
                            font: Kirigami.Theme.smallFont
                        }
                        TapHandler { onTapped: { editor.flush(); editor.openNote(modelData); } }
                    }
                }
            }
        }

        // footer
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                Layout.fillWidth: true
                opacity: 0.5; font: Kirigami.Theme.smallFont
                text: editor.note ? i18n("Updated %1", Fmt.dateTimeShort(editor.note.updatedAt, editor.use24h)) : ""
            }
            QQC2.ToolButton {
                icon.name: editor.note && editor.note.archived ? "archive-remove" : "archive-insert"
                flat: true
                onClicked: editor.controller.setArchived("notes", editor.noteId, !(editor.note && editor.note.archived))
                QQC2.ToolTip.text: i18n("Archive"); QQC2.ToolTip.visible: hovered
            }
            QQC2.ToolButton {
                icon.name: "edit-delete"
                flat: true
                onClicked: { var id = editor.noteId; editor.flush(); editor.closed(); editor.controller.deleteItem("notes", id); }
                QQC2.ToolTip.text: i18n("Delete"); QQC2.ToolTip.visible: hovered
            }
        }
    }

    function wrapSelection(token) {
        var s = bodyArea.selectionStart, e = bodyArea.selectionEnd;
        if (s === e) { bodyArea.insert(bodyArea.cursorPosition, token + token); bodyArea.cursorPosition -= token.length; }
        else {
            var sel = bodyArea.selectedText;
            bodyArea.remove(s, e);
            bodyArea.insert(s, token + sel + token);
        }
        bodyArea.forceActiveFocus();
    }
}
