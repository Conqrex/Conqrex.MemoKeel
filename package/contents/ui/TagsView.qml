import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "components" as QN
import "theme" as T
import "../code/model.js" as Model
import "../code/theme.js" as Theme

// Tags mode: every tag in the document as one cloud, each chip sized by how
// many items carry it, plus the per-tag housekeeping that has never had a home
// — rename, recolour and delete. Clicking a chip hands the tag up as the global
// filter; the tab bar's Search tab is where the filtered items are listed.
ColumnLayout {
    id: view

    property var controller
    property color accent: Kirigami.Theme.highlightColor

    signal tagActivated(string tagId)

    spacing: Kirigami.Units.smallSpacing

    // The controller has no document while it is still loading, or when a
    // legacy import is blocked, so every derived value tolerates a null doc.
    readonly property var doc: controller ? controller.doc : null

    // ---- data ---------------------------------------------------------------
    // Model.tagCounts is the document's own tally and already walks exactly the
    // four collections that carry tag ids (notes, todos, cards, reminders), so
    // this view counts through it rather than growing a second, driftable copy.
    // It counts archived items too, and that is the behaviour we want here:
    // Model.deleteTag strips the tag from archived items as well, so the number
    // in the delete confirmation has to be the number that will actually be
    // touched. Trashed items are not counted — they are out of the four live
    // collections, and deleting a tag leaves the copy inside doc.trash alone.
    readonly property var counts: view.doc ? Model.tagCounts(view.doc) : ({})

    function buildTags(d, c) {
        if (!d) return [];
        var out = [];
        for (var id in d.tags) {
            var t = d.tags[id];
            out.push({ id: id, name: t.name || "", color: t.color || "", count: c[id] || 0 });
        }
        // Most-used first, alphabetical inside a tie: the cloud then reads
        // biggest-to-smallest instead of in arbitrary object-key order.
        out.sort(function (a, b) {
            if (b.count !== a.count) return b.count - a.count;
            return a.name.localeCompare(b.name);
        });
        return out;
    }
    readonly property var tagItems: view.buildTags(view.doc, view.counts)
    readonly property int maxCount: {
        var m = 0;
        for (var i = 0; i < view.tagItems.length; i++) if (view.tagItems[i].count > m) m = view.tagItems[i].count;
        return m;
    }

    // ---- size scaling -------------------------------------------------------
    // A chip is never smaller than minScale nor bigger than maxScale, so one
    // tag used fifty times cannot blow the Flow out while a tag used once stays
    // readable. The curve is logarithmic rather than linear because usage is
    // long-tailed: linear scaling would flatten every rare tag onto the floor
    // as soon as a single popular tag existed. 1 usage lands on the floor, the
    // busiest tag lands on the ceiling, and everything in between spreads out.
    readonly property real minScale: 1.0
    readonly property real maxScale: 2.0
    function chipScale(count) {
        if (view.maxCount <= 1) return view.minScale;
        var lo = Math.log(2);
        var span = Math.log(1 + view.maxCount) - lo;
        var t = (Math.log(1 + Math.max(count, 1)) - lo) / span;
        t = Math.max(0, Math.min(1, t));
        return view.minScale + t * (view.maxScale - view.minScale);
    }

    // ---- rename collisions --------------------------------------------------
    // Model.renameTag writes the new name in unconditionally: it does NOT merge
    // into an identically-named tag, it just leaves two distinct tag ids sharing
    // one name. Every item keeps whichever id it had, so the cloud would show
    // two chips reading "#work" with split counts, and Model.findTagByName (the
    // one used when "#work" is typed into a quick-add bar) would then resolve to
    // whichever of them the document happens to list first. That is exactly the
    // silent surprise this UI must not produce, so a colliding name is refused
    // in the dialog before the intent is ever fired.
    function normalizeName(name) {
        return ("" + (name || "")).toLowerCase().replace(/^#/, "").trim();
    }
    function collidingTagId(tagId, name) {
        var norm = view.normalizeName(name);
        if (norm === "" || !view.doc) return "";
        for (var id in view.doc.tags) {
            if (id !== tagId && view.doc.tags[id].name === norm) return id;
        }
        return "";
    }

    function tagById(id) { return (view.doc && view.doc.tags[id]) ? view.doc.tags[id] : null; }
    function tagNameOf(id) { var t = view.tagById(id); return t ? t.name : ""; }
    function tagColorOf(id) { var t = view.tagById(id); return t ? Theme.accentFor(t.color, view.accent) : view.accent; }
    function usageOf(id) { return view.counts[id] || 0; }

    // ---- action entry points ------------------------------------------------
    // Each opens the one shared dialog for that action; the delegates only ever
    // pass an id, so the dialogs stay outside the Flow and are not rebuilt as
    // the cloud re-renders after every edit.
    function openRename(id) {
        renameDialog.tagId = id;
        renameField.text = view.tagNameOf(id);
        renameDialog.open();
    }
    function openColor(id) {
        colorDialog.tagId = id;
        colorDialog.open();
    }
    function openDelete(id) {
        deleteDialog.tagId = id;
        deleteDialog.open();
    }

    function commitRename() {
        if (!renameDialog.canApply) return;
        view.controller.renameTag(renameDialog.tagId, view.normalizeName(renameField.text));
        renameDialog.close();
    }

    // ---- header -------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            text: i18n("Tags")
            font.bold: true
            color: T.QN.text
        }
        PlasmaComponents.Label {
            visible: view.tagItems.length > 0
            text: i18np("%1 tag", "%1 tags", view.tagItems.length)
            color: T.QN.textFaint
            font: Kirigami.Theme.smallFont
        }
        Item { Layout.fillWidth: true }
        PlasmaComponents.Label {
            visible: view.tagItems.length > 0
            text: i18n("Click a tag to filter · right-click for actions")
            color: T.QN.textFaint
            font: Kirigami.Theme.smallFont
            elide: Text.ElideRight
            Layout.maximumWidth: Kirigami.Units.gridUnit * 18
        }
    }

    QN.EmptyState {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: view.tagItems.length === 0
        icon: "tag"
        title: i18n("No tags yet")
        hint: i18n("Type #tag while adding a note, to-do, card or reminder and it shows up here.")
    }

    // ---- the cloud ----------------------------------------------------------
    QQC2.ScrollView {
        id: cloudScroll
        visible: view.tagItems.length > 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        clip: true

        Flow {
            id: cloud
            width: cloudScroll.availableWidth
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: view.tagItems

                // One cell = the chip plus its own overflow button. The button
                // keeps its width whether or not it is lit, so hovering a chip
                // never nudges the whole cloud sideways.
                delegate: Item {
                    id: cell
                    required property var modelData
                    readonly property string tagId: cell.modelData.id
                    readonly property real buttonWidth: Kirigami.Units.iconSizes.small
                                                        + Kirigami.Units.smallSpacing

                    width: chip.implicitWidth + cell.buttonWidth
                    height: Math.max(chip.implicitHeight, menuButton.implicitHeight)

                    HoverHandler { id: cellHover }

                    // Right-clicks are not accepted by TagChip's own MouseArea
                    // (left button only) nor by the ToolButton, so they fall
                    // through to this one, which sits below both.
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onClicked: cellMenu.popup()
                    }

                    QN.TagChip {
                        id: chip
                        objectName: "tagChip_" + cell.modelData.name
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: implicitWidth
                        height: implicitHeight
                        tagName: cell.modelData.name
                        tagColor: Theme.accentFor(cell.modelData.color, view.accent)
                        count: cell.modelData.count
                        sizeScale: view.chipScale(cell.modelData.count)
                        onClicked: view.tagActivated(cell.tagId)
                    }

                    QQC2.ToolButton {
                        id: menuButton
                        objectName: "tagMenu_" + cell.modelData.name
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: cell.buttonWidth
                        flat: true
                        icon.name: "overflow-menu"
                        icon.width: Kirigami.Units.iconSizes.small
                        icon.height: Kirigami.Units.iconSizes.small
                        opacity: (cellHover.hovered || cellMenu.visible) ? 1 : 0.3
                        onClicked: cellMenu.popup()
                        QQC2.ToolTip.text: i18n("Actions for #%1", cell.modelData.name)
                        QQC2.ToolTip.visible: hovered
                    }

                    QQC2.Menu {
                        id: cellMenu
                        QQC2.MenuItem {
                            text: i18n("Rename…")
                            icon.name: "edit-rename"
                            onTriggered: view.openRename(cell.tagId)
                        }
                        QQC2.MenuItem {
                            text: i18n("Colour…")
                            icon.name: "color-picker"
                            onTriggered: view.openColor(cell.tagId)
                        }
                        QQC2.MenuSeparator {}
                        QQC2.MenuItem {
                            text: i18n("Delete…")
                            icon.name: "edit-delete"
                            onTriggered: view.openDelete(cell.tagId)
                        }
                    }
                }
            }
        }
    }

    // ---- dialogs ------------------------------------------------------------
    // A shared shell so the three dialogs cannot drift apart visually: themed
    // surface, centred over the view, modal, closed by clicking away or Escape.
    component TagDialog: QQC2.Popup {
        id: dlg
        property string tagId: ""

        // Popup understands anchors.centerIn (and only that one) — using it
        // instead of x/y also keeps it off the enclosing layout's books.
        anchors.centerIn: QQC2.Overlay.overlay
        modal: true
        focus: true
        padding: Kirigami.Units.largeSpacing
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
        background: Rectangle {
            color: T.QN.surface
            radius: T.QN.radiusM
            border.width: 1
            border.color: T.QN.borderHi
        }
    }

    TagDialog {
        id: renameDialog
        readonly property string typed: view.normalizeName(renameField.text)
        readonly property string clash: view.collidingTagId(renameDialog.tagId, renameField.text)
        readonly property bool canApply: renameDialog.typed !== "" && renameDialog.clash === ""

        // Focus once the popup is actually shown; forcing it before the enter
        // transition has run leaves the caret nowhere.
        onOpened: { renameField.forceActiveFocus(); renameField.selectAll(); }

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: i18n("Rename #%1", view.tagNameOf(renameDialog.tagId))
                font.bold: true
                color: T.QN.text
            }
            QQC2.TextField {
                id: renameField
                objectName: "renameField"
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                selectByMouse: true
                hoverEnabled: true
                color: T.QN.text
                placeholderText: i18n("Tag name")
                background: Rectangle {
                    color: T.QN.inputBg
                    radius: T.QN.radiusS
                    border.width: 1
                    border.color: renameField.activeFocus ? T.QN.alpha(Kirigami.Theme.highlightColor, 0.6)
                                : renameField.hovered ? T.QN.borderHi : T.QN.border
                }
                onAccepted: view.commitRename()
            }
            // Model.renameTag would happily create a second tag with this name
            // rather than merge, so the rename is refused here instead.
            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                visible: renameDialog.clash !== ""
                text: i18n("#%1 already exists. Renaming would leave two separate tags with the same name, so pick another.",
                           view.tagNameOf(renameDialog.clash))
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.negativeTextColor
                font: Kirigami.Theme.smallFont
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Item { Layout.fillWidth: true }
                QQC2.Button {
                    objectName: "renameCancel"
                    text: i18n("Cancel")
                    flat: true
                    onClicked: renameDialog.close()
                }
                QQC2.Button {
                    objectName: "renameApply"
                    text: i18n("Rename")
                    enabled: renameDialog.canApply
                    onClicked: view.commitRename()
                }
            }
        }
    }

    TagDialog {
        id: colorDialog

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: i18n("Colour of #%1", view.tagNameOf(colorDialog.tagId))
                font.bold: true
                color: T.QN.text
            }
            // ColorPicker's API is `selected` (the current palette key) and
            // `picked(key)`; "" is the default/theme-highlight swatch.
            QN.ColorPicker {
                objectName: "tagColorPicker"
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 13
                selected: {
                    var t = view.tagById(colorDialog.tagId);
                    return t ? (t.color || "") : "";
                }
                onPicked: (key) => {
                    view.controller.setTagColor(colorDialog.tagId, key);
                    colorDialog.close();
                }
            }
        }
    }

    TagDialog {
        id: deleteDialog
        readonly property int usage: view.usageOf(deleteDialog.tagId)

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: i18n("Delete #%1?", view.tagNameOf(deleteDialog.tagId))
                font.bold: true
                color: T.QN.text
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                wrapMode: Text.WordWrap
                color: T.QN.textDim
                font: Kirigami.Theme.smallFont
                // Deleting a tag is not just dropping a label from a list: it
                // strips the tag off every live item that carries it, archived
                // ones included, so the confirmation says how many that is.
                //
                // KNOWN GAP: Model.deleteTag (code/model.js) walks notes,
                // todos, cards and reminders only — it does not touch the
                // copies parked in doc.trash, and Model.tagCounts (the source
                // of `usage`) does not count them either. So a trashed item
                // keeps the deleted tag id, and restoring it later resurfaces a
                // reference to a tag that no longer exists. The wording below
                // is therefore deliberately scoped to live items and never
                // claims the tag is gone everywhere. Fixing it properly means
                // changing model.js, which is frozen.
                text: deleteDialog.usage === 0
                      ? i18n("Nothing in your live notes, to-dos, cards or reminders is tagged with it, so only the tag itself goes.")
                      : i18np("It will be removed from %1 live item — notes, to-dos, cards and reminders. Items already in the trash keep it.",
                              "It will be removed from %1 live items — notes, to-dos, cards and reminders. Items already in the trash keep it.",
                              deleteDialog.usage)
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Item { Layout.fillWidth: true }
                QQC2.Button {
                    objectName: "deleteCancel"
                    text: i18n("Cancel")
                    flat: true
                    onClicked: deleteDialog.close()
                }
                QQC2.Button {
                    objectName: "deleteConfirm"
                    text: i18n("Delete")
                    icon.name: "edit-delete"
                    onClicked: {
                        view.controller.deleteTag(deleteDialog.tagId);
                        deleteDialog.close();
                    }
                }
            }
        }
    }
}
