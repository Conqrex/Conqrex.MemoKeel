.pragma library

// Date/time, countdown and human-label helpers. Plain strings only (no i18n in a
// .pragma library — QML views wrap user-facing text); timestamps are ISO-8601.

function pad(n) { return n < 10 ? "0" + n : "" + n; }

function clampPct(x) {
    var v = Math.round(Number(x));
    if (isNaN(v)) v = 0;
    return Math.max(0, Math.min(100, v));
}

function parseDate(iso) {
    if (!iso) return null;
    var d = (iso instanceof Date) ? iso : new Date(iso);
    return isNaN(d.getTime()) ? null : d;
}

var DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// Milliseconds -> "3d 4h" / "2h 13m" / "5m" / "<1m" / "now".
function formatCountdown(ms) {
    if (ms === null || ms === undefined || isNaN(ms)) return "";
    var s = Math.floor(ms / 1000);
    if (s <= 0) return "now";
    var d = Math.floor(s / 86400); s -= d * 86400;
    var h = Math.floor(s / 3600);  s -= h * 3600;
    var m = Math.floor(s / 60);
    if (d > 0) return d + "d " + h + "h";
    if (h > 0) return h + "h " + m + "m";
    if (m > 0) return m + "m";
    return "<1m";
}

function timeOfDay(d, use24h) {
    var hh = d.getHours(), mm = d.getMinutes();
    if (use24h) return pad(hh) + ":" + pad(mm);
    var ap = hh >= 12 ? "PM" : "AM";
    var h12 = hh % 12; if (h12 === 0) h12 = 12;
    return h12 + ":" + pad(mm) + " " + ap;
}

// "Wed 24 Jun · 14:00"
function dateTimeShort(iso, use24h) {
    var d = parseDate(iso);
    if (!d) return "";
    return DAYS[d.getDay()] + " " + d.getDate() + " " + MONTHS[d.getMonth()]
         + " · " + timeOfDay(d, use24h);
}

function isSameDay(a, b) {
    return a.getFullYear() === b.getFullYear()
        && a.getMonth() === b.getMonth()
        && a.getDate() === b.getDate();
}

// "overdue" | "today" | "soon" (<24h) | "upcoming" | "none"
function dueState(iso, nowMs) {
    var d = parseDate(iso);
    if (!d) return "none";
    var now = new Date(nowMs);
    if (d.getTime() < nowMs) return "overdue";
    if (isSameDay(d, now)) return "today";
    if (d.getTime() - nowMs < 86400000) return "soon";
    return "upcoming";
}

// humane due text: "Overdue 2h", "in 35m", "in 3h", "Tomorrow 14:00", "Wed 24 Jun · 14:00"
function dueText(iso, nowMs, use24h) {
    var d = parseDate(iso);
    if (!d) return "";
    var diff = d.getTime() - nowMs;
    if (diff <= 0) return "Overdue " + formatCountdown(-diff);
    if (diff < 3600000) return "in " + Math.max(1, Math.round(diff / 60000)) + "m";
    if (diff < 86400000 && isSameDay(d, new Date(nowMs))) return "Today " + timeOfDay(d, use24h);
    var tomorrow = new Date(nowMs + 86400000);
    if (isSameDay(d, tomorrow)) return "Tomorrow " + timeOfDay(d, use24h);
    return dateTimeShort(iso, use24h);
}

// next occurrence of a repeating date strictly after nowMs (or after the date
// itself when nowMs is null). Returns ISO or null for non-repeating.
function nextOccurrence(iso, repeat, nowMs) {
    var d = parseDate(iso);
    if (!d || !repeat || repeat === "none") return null;
    var next = new Date(d.getTime());
    var guard = 0;
    do {
        if (repeat === "daily") next.setDate(next.getDate() + 1);
        else if (repeat === "weekly") next.setDate(next.getDate() + 7);
        else if (repeat === "monthly") next.setMonth(next.getMonth() + 1);
        else return null;
        guard++;
    } while (nowMs != null && next.getTime() <= nowMs && guard < 10000);
    return next.toISOString();
}

function formatBytes(n) {
    n = Number(n) || 0;
    if (n < 1024) return n + " B";
    if (n < 1048576) return (n / 1024).toFixed(1) + " KB";
    if (n < 1073741824) return (n / 1048576).toFixed(1) + " MB";
    return (n / 1073741824).toFixed(1) + " GB";
}

var PRIORITY_LABELS = ["None", "Low", "Medium", "High", "Urgent"];
function priorityLabel(p) {
    p = Number(p) || 0;
    return PRIORITY_LABELS[p] || "None";
}

var STATUS_LABELS = { todo: "To Do", doing: "In Progress", done: "Done" };
function statusLabel(s) { return STATUS_LABELS[s] || s; }

// a value for QML's <input type=datetime-local> style local string, if needed
function toLocalParts(iso) {
    var d = parseDate(iso) || new Date();
    return {
        year: d.getFullYear(), month: d.getMonth(), day: d.getDate(),
        hour: d.getHours(), minute: d.getMinutes()
    };
}
