import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Always-visible add row. Parses ClickUp-style inline tokens:
//   #tag        add a tag           (repeatable)
//   !1.. !4     priority            (or !low/!med/!high/!urgent)
//   ^today ^tomorrow ^3h ^2d ^14:30 due date
// and emits addRequested({text, tagNames, priority, dueAt}).
RowLayout {
    id: bar
    property string placeholder: i18n("Quick add… (#tag !priority ^due)")
    signal addRequested(var payload)

    spacing: Kirigami.Units.smallSpacing

    function pad(n) { return n < 10 ? "0" + n : "" + n; }

    // build an ISO datetime from a due token, or null
    function parseDue(tok) {
        var now = new Date();
        tok = tok.toLowerCase();
        var m;
        if (tok === "today") { now.setHours(17, 0, 0, 0); return now.toISOString(); }
        if (tok === "tomorrow") { now.setDate(now.getDate() + 1); now.setHours(9, 0, 0, 0); return now.toISOString(); }
        if ((m = tok.match(/^(\d+)h$/))) { return new Date(Date.now() + parseInt(m[1]) * 3600000).toISOString(); }
        if ((m = tok.match(/^(\d+)d$/))) { var d = new Date(Date.now() + parseInt(m[1]) * 86400000); d.setHours(9, 0, 0, 0); return d.toISOString(); }
        if ((m = tok.match(/^(\d{1,2}):(\d{2})$/))) {
            var t = new Date();
            t.setHours(parseInt(m[1]), parseInt(m[2]), 0, 0);
            if (t.getTime() < Date.now()) t.setDate(t.getDate() + 1);
            return t.toISOString();
        }
        return null;
    }

    function parsePriority(tok) {
        var t = tok.toLowerCase();
        if (t === "urgent" || t === "4") return 4;
        if (t === "high" || t === "3") return 3;
        if (t === "med" || t === "medium" || t === "2") return 2;
        if (t === "low" || t === "1") return 1;
        if (t === "none" || t === "0") return 0;
        return -1;
    }

    function parse(raw) {
        var tagNames = [], priority = 0, dueAt = null;
        var words = raw.split(/\s+/);
        var rest = [];
        for (var i = 0; i < words.length; i++) {
            var w = words[i];
            if (w.length < 2) { if (w) rest.push(w); continue; }
            var head = w.charAt(0), body = w.substring(1);
            if (head === "#") { tagNames.push(body.toLowerCase()); }
            else if (head === "!") { var p = parsePriority(body); if (p >= 0) priority = p; else rest.push(w); }
            else if (head === "^") { var d = parseDue(body); if (d) dueAt = d; else rest.push(w); }
            else rest.push(w);
        }
        return { text: rest.join(" ").trim(), tagNames: tagNames, priority: priority, dueAt: dueAt };
    }

    function submit() {
        var raw = field.text.trim();
        if (raw === "") return;
        bar.addRequested(parse(raw));
        field.text = "";
    }

    QQC2.TextField {
        id: field
        Layout.fillWidth: true
        placeholderText: bar.placeholder
        selectByMouse: true
        onAccepted: bar.submit()
    }
    QQC2.Button {
        icon.name: "list-add"
        text: i18n("Add")
        highlighted: true
        onClicked: bar.submit()
    }
}
