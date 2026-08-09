import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Qt.labs.platform as Platform
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// A thumbnail row for an item's attachments, with add-via-picker and drag-drop.
// Image blobs render as thumbnails; everything else shows a file glyph + ext.
ColumnLayout {
    id: strip

    property var controller
    property string coll: "notes"
    property string itemId: ""
    property var attachmentIds: []
    property color accent: Kirigami.Theme.highlightColor
    property bool addEnabled: true

    spacing: Kirigami.Units.smallSpacing

    function metaOf(sha) {
        return (controller && controller.doc && controller.doc.attachments[sha])
             ? controller.doc.attachments[sha] : null;
    }
    function isImage(sha) {
        var m = metaOf(sha);
        return m && ("" + (m.mime || "")).indexOf("image/") === 0;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon { source: "mail-attachment"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small; opacity: 0.7 }
        PlasmaComponents.Label { text: i18n("Attachments"); font: Kirigami.Theme.smallFont; opacity: 0.7 }
        Item { Layout.fillWidth: true }
        QQC2.ToolButton {
            icon.name: "list-add"
            flat: true
            enabled: strip.addEnabled
            onClicked: fileDialog.open()
            QQC2.ToolTip.text: i18n("Add files"); QQC2.ToolTip.visible: hovered
        }
    }

    Flow {
        id: flow
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: strip.attachmentIds || []
            delegate: Rectangle {
                id: thumb
                required property var modelData
                readonly property string path: strip.controller ? strip.controller.attachmentPath(modelData) : ""
                readonly property var meta: strip.metaOf(modelData)
                width: Kirigami.Units.gridUnit * 3.6
                height: Kirigami.Units.gridUnit * 3.6
                radius: Kirigami.Units.smallSpacing
                color: Qt.rgba(strip.accent.r, strip.accent.g, strip.accent.b, 0.1)
                border.width: 1
                border.color: Qt.rgba(strip.accent.r, strip.accent.g, strip.accent.b, 0.3)
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    visible: strip.isImage(thumb.modelData) && status === Image.Ready
                    source: thumb.path !== "" ? "file://" + thumb.path : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: width * 2
                    sourceSize.height: height * 2
                }
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: !strip.isImage(thumb.modelData)
                    spacing: 2
                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        source: "application-octet-stream"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: thumb.meta ? ("." + (thumb.meta.ext || "?")) : ""
                        font: Kirigami.Theme.smallFont
                    }
                }

                HoverHandler { id: th }
                TapHandler { onTapped: if (thumb.path !== "") Qt.openUrlExternally("file://" + thumb.path) }

                QQC2.ToolButton {
                    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: -2
                    icon.name: "edit-delete"
                    icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                    opacity: th.hovered ? 1 : 0
                    visible: opacity > 0.01
                    onClicked: strip.controller.detach(strip.coll, strip.itemId, thumb.modelData)
                }
            }
        }
    }

    Platform.FileDialog {
        id: fileDialog
        fileMode: Platform.FileDialog.OpenFiles
        nameFilters: [i18n("Images (*.png *.jpg *.jpeg *.gif *.webp *.bmp *.svg)"), i18n("All files (*)")]
        onAccepted: {
            for (var i = 0; i < files.length; i++)
                strip.controller.attachFile(strip.coll, strip.itemId, ("" + files[i]).replace(/^file:\/\//, ""));
        }
    }

    // drop files anywhere on the strip
    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            if (drop.hasUrls) {
                for (var i = 0; i < drop.urls.length; i++)
                    strip.controller.attachFile(strip.coll, strip.itemId, ("" + drop.urls[i]).replace(/^file:\/\//, ""));
                drop.accept();
            }
        }
    }
}
