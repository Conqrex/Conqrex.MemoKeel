.pragma library
.import "format.js" as Fmt
.import "model.js" as Model
.import "search.js" as Search

// Ordering and bucketing shared by the mode views and the dashboard panes.
// Whoever renders a list of to-dos or reminders must get the *same* order and
// the *same* due buckets, so the rules live here once instead of in each view.

// ------------------------------------------------------------- to-dos --------
// In-progress first, then open, then done; within a status the most urgent
// (priority, then soonest due, then most recently touched) comes first.
function statusRank(s) { return s === "done" ? 2 : (s === "doing" ? 0 : 1); }

function sortTodos(list) {
    return list.slice().sort(function (a, b) {
        var sr = statusRank(a.status) - statusRank(b.status);
        if (sr !== 0) return sr;
        if ((b.priority || 0) !== (a.priority || 0)) return (b.priority || 0) - (a.priority || 0);
        var ad = a.dueAt ? new Date(a.dueAt).getTime() : 8640000000000000;
        var bd = b.dueAt ? new Date(b.dueAt).getTime() : 8640000000000000;
        if (ad !== bd) return ad - bd;
        return new Date(b.updatedAt) - new Date(a.updatedAt);
    });
}

function openTodos(list) {
    return list.filter(function (t) { return t.status !== "done"; });
}

// ---------------------------------------------------------- reminders --------
// Effective due and "still live" are Model's definitions; re-exported here so a
// view never has to decide for itself what a snoozed or acked reminder means.
function effectiveDue(r) { return Model.effectiveDue(r); }
function isActive(r) { return Model.isReminderActive(r); }

// { overdue, today, upcoming, done }, each sorted by effective due date.
// opts: { nowMs, query, tagId }
function reminderBuckets(doc, opts) {
    opts = opts || {};
    var res = { overdue: [], today: [], upcoming: [], done: [] };
    if (!doc) return res;
    var list = doc.reminders.slice();
    if (opts.tagId)
        list = list.filter(function (r) { return (r.tagIds || []).indexOf(opts.tagId) >= 0; });
    if (opts.query && opts.query.trim() !== "")
        list = Search.rank(opts.query, list, doc.tags);
    list.sort(function (a, b) { return new Date(effectiveDue(a)) - new Date(effectiveDue(b)); });
    for (var i = 0; i < list.length; i++) {
        var r = list[i];
        if (!isActive(r)) { res.done.push(r); continue; }
        var st = Fmt.dueState(effectiveDue(r), opts.nowMs);
        if (st === "overdue") res.overdue.push(r);
        else if (st === "today") res.today.push(r);
        else res.upcoming.push(r);
    }
    return res;
}
