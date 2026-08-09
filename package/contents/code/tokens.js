.pragma library

// Inline quick-add token parsing, shared by QuickAddBar and ReminderAddRow.
// The syntax is optional everywhere — it is never required and no longer
// advertised in the reminders UI, but typing it still works:
//   #tag        add a tag           (repeatable)
//   !1.. !4     priority            (or !low/!med/!high/!urgent)
//   ^today ^tomorrow ^3h ^2d ^14:30 due date

// Build an ISO datetime from a due token, or null when the token is unknown.
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

// Priority token -> 0..4, or -1 when the token is not a priority.
function parsePriority(tok) {
    var t = tok.toLowerCase();
    if (t === "urgent" || t === "4") return 4;
    if (t === "high" || t === "3") return 3;
    if (t === "med" || t === "medium" || t === "2") return 2;
    if (t === "low" || t === "1") return 1;
    if (t === "none" || t === "0") return 0;
    return -1;
}

// Strip recognised tokens out of raw and return the leftovers plus what
// was found: { text, tagNames, priority, dueAt }.
// opts.keepPriority: when true, "!" tokens are left in the returned text
// instead of being stripped, for callers (e.g. reminders) that have no
// priority field to apply the parsed value to.
function parse(raw, opts) {
    var keepPriority = !!(opts && opts.keepPriority);
    var tagNames = [], priority = 0, dueAt = null;
    var words = ("" + (raw || "")).split(/\s+/);
    var rest = [];
    for (var i = 0; i < words.length; i++) {
        var w = words[i];
        if (w.length < 2) { if (w) rest.push(w); continue; }
        var head = w.charAt(0), body = w.substring(1);
        if (head === "#") { tagNames.push(body.toLowerCase()); }
        else if (head === "!") {
            var p = parsePriority(body);
            if (p >= 0 && !keepPriority) priority = p;
            else rest.push(w);
        }
        else if (head === "^") { var d = parseDue(body); if (d) dueAt = d; else rest.push(w); }
        else rest.push(w);
    }
    return { text: rest.join(" ").trim(), tagNames: tagNames, priority: priority, dueAt: dueAt };
}
