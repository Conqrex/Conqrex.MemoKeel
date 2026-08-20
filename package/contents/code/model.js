.pragma library
.import "schema.js" as Schema

// Pure document operations. Every mutator returns a NEW document (deep clone +
// edit) so reassigning root.doc in main.qml fires QML bindings. No I/O lives
// here — persistence is store.sh's job. Edits are user-paced (clicks / debounced
// commits), so a per-intent JSON clone of a kilobyte document is cheap.

function clone(doc) { return JSON.parse(JSON.stringify(doc)); }
function nowIso() { return new Date().toISOString(); }
function bump(d) { d.rev = (d.rev || 0) + 1; return d; }
function touch(item) { item.updatedAt = nowIso(); item.rev = (item.rev || 0) + 1; return item; }

function indexOf(arr, id) {
    for (var i = 0; i < arr.length; i++) if (arr[i].id === id) return i;
    return -1;
}
function byId(arr, id) { var i = indexOf(arr, id); return i >= 0 ? arr[i] : null; }
function maxOrder(arr) {
    var m = 0;
    for (var i = 0; i < arr.length; i++) if ((arr[i].order || 0) > m) m = arr[i].order;
    return m;
}

// collection name for a trashed item's type
function collectionFor(type) {
    return { note: "notes", todo: "todos", board: "boards", column: "columns",
             card: "cards", reminder: "reminders" }[type] || (type + "s");
}

// ---------------------------------------------------------------- notes ------
function addNote(doc, fields) {
    var d = clone(doc);
    var n = Schema.makeNote(fields || {});
    d.notes.unshift(n);
    return { doc: bump(d), id: n.id };
}
function togglePin(doc, id) {
    var d = clone(doc), n = byId(d.notes, id);
    if (n) { n.pinned = !n.pinned; touch(n); }
    return bump(d);
}

// ------------------------------------------------------- generic per-item ----
function updateItem(doc, collection, id, patch) {
    var d = clone(doc), it = byId(d[collection], id);
    if (!it) return d;
    for (var k in patch) it[k] = patch[k];
    touch(it);
    return bump(d);
}
function setColor(doc, collection, id, color) {
    return updateItem(doc, collection, id, { color: color });
}
function setArchived(doc, collection, id, val) {
    return updateItem(doc, collection, id, { archived: !!val });
}
function setPriority(doc, collection, id, p) {
    return updateItem(doc, collection, id, { priority: Number(p) || 0 });
}
function setDue(doc, collection, id, iso) {
    return updateItem(doc, collection, id, { dueAt: iso || null });
}

// ------------------------------------------------------------- trash ---------
function softDelete(doc, collection, id, retentionDays) {
    var d = clone(doc), i = indexOf(d[collection], id);
    if (i < 0) return d;
    var purge = new Date(Date.now() + (retentionDays || 14) * 86400000).toISOString();
    var item = d[collection].splice(i, 1)[0];
    d.trash.unshift({ collection: collection, item: item, deletedAt: nowIso(), purgeAfter: purge });
    // deleting a board trashes its columns and cards too
    if (collection === "boards") {
        var boardColumnIds = {};
        for (var bc = d.columns.length - 1; bc >= 0; bc--) {
            if (d.columns[bc].boardId === id) {
                var boardCol = d.columns.splice(bc, 1)[0];
                boardColumnIds[boardCol.id] = true;
                d.trash.unshift({ collection: "columns", item: boardCol, deletedAt: nowIso(), purgeAfter: purge });
            }
        }
        for (var bk = d.cards.length - 1; bk >= 0; bk--) {
            if (boardColumnIds[d.cards[bk].columnId]) {
                var boardCard = d.cards.splice(bk, 1)[0];
                d.trash.unshift({ collection: "cards", item: boardCard, deletedAt: nowIso(), purgeAfter: purge });
            }
        }
    }
    // deleting a column trashes its cards too
    if (collection === "columns") {
        for (var j = d.cards.length - 1; j >= 0; j--) {
            if (d.cards[j].columnId === id) {
                var c = d.cards.splice(j, 1)[0];
                d.trash.unshift({ collection: "cards", item: c, deletedAt: nowIso(), purgeAfter: purge });
            }
        }
    }
    recomputeAttachmentRefCounts(d);
    return bump(d);
}
function restoreTrash(doc, itemId) {
    var d = clone(doc);
    for (var i = 0; i < d.trash.length; i++) {
        var t = d.trash[i];
        if (t.item && t.item.id === itemId) {
            d.trash.splice(i, 1);
            var coll = t.collection || collectionFor(t.item.type);
            if (!d[coll]) d[coll] = [];
            d[coll].unshift(t.item);
            break;
        }
    }
    recomputeAttachmentRefCounts(d);
    return bump(d);
}
function purgeExpiredTrash(doc, nowMs) {
    var d = clone(doc), changed = false;
    for (var i = d.trash.length - 1; i >= 0; i--) {
        var p = d.trash[i].purgeAfter;
        if (p && new Date(p).getTime() <= nowMs) { d.trash.splice(i, 1); changed = true; }
    }
    if (changed) { recomputeAttachmentRefCounts(d); bump(d); }
    return d;
}
function emptyTrash(doc) {
    var d = clone(doc);
    d.trash = [];
    recomputeAttachmentRefCounts(d);
    return bump(d);
}

// ------------------------------------------------------------- todos ---------
function addTodo(doc, fields) {
    var d = clone(doc);
    fields = fields || {};
    if (fields.order == null) fields.order = maxOrder(d.todos) + 1;
    var t = Schema.makeTodo(fields);
    d.todos.unshift(t);
    return { doc: bump(d), id: t.id };
}
var _TODO_CYCLE = { todo: "doing", doing: "done", done: "todo" };
function cycleTodoStatus(doc, id) {
    var d = clone(doc), t = byId(d.todos, id);
    if (t) { t.status = _TODO_CYCLE[t.status] || "todo"; touch(t); }
    return bump(d);
}
function setTodoStatus(doc, id, status) {
    return updateItem(doc, "todos", id, { status: status });
}
function toggleTodoDone(doc, id) {
    var d = clone(doc), t = byId(d.todos, id);
    if (t) { t.status = (t.status === "done") ? "todo" : "done"; touch(t); }
    return bump(d);
}

// reassign sequential orders from a drag-produced id list
function reorderList(doc, collection, orderedIds) {
    var d = clone(doc), map = {};
    for (var i = 0; i < orderedIds.length; i++) map[orderedIds[i]] = i;
    for (var j = 0; j < d[collection].length; j++) {
        var it = d[collection][j];
        if (map[it.id] != null) it.order = map[it.id];
    }
    return bump(d);
}

// ---------------------------------------------------------- reminders --------
function addReminder(doc, fields) {
    var d = clone(doc);
    var r = Schema.makeReminder(fields || {});
    d.reminders.unshift(r);
    return { doc: bump(d), id: r.id };
}
function _nextOccurrence(iso, repeat, nowMs) {
    var d = new Date(iso);
    if (isNaN(d.getTime()) || !repeat || repeat === "none") return null;
    var guard = 0;
    do {
        if (repeat === "daily") d.setDate(d.getDate() + 1);
        else if (repeat === "weekly") d.setDate(d.getDate() + 7);
        else if (repeat === "monthly") d.setMonth(d.getMonth() + 1);
        else return null;
        guard++;
    } while (nowMs != null && d.getTime() <= nowMs && guard < 10000);
    return d.toISOString();
}
function effectiveDue(r) { return r.snoozeUntil || r.dueAt; }
// mark a reminder fired; repeating ones roll forward and re-arm
function markReminderFired(doc, id, nowMs) {
    var d = clone(doc), r = byId(d.reminders, id);
    if (!r) return d;
    if (r.repeat && r.repeat !== "none") {
        r.dueAt = _nextOccurrence(r.dueAt, r.repeat, nowMs);
        r.notified = false; r.snoozeUntil = null;
    } else {
        r.notified = true;
    }
    touch(r);
    return bump(d);
}
function ackReminder(doc, id) {
    var d = clone(doc), r = byId(d.reminders, id);
    if (r) { r.ackedAt = nowIso(); r.notified = true; r.snoozeUntil = null; touch(r); }
    return bump(d);
}
function snoozeReminder(doc, id, minutes) {
    var d = clone(doc), r = byId(d.reminders, id);
    if (r) {
        r.snoozeUntil = new Date(Date.now() + minutes * 60000).toISOString();
        r.notified = false; r.ackedAt = null; touch(r);
    }
    return bump(d);
}
function isReminderActive(r) {
    if (r.repeat && r.repeat !== "none") return true;
    return !r.ackedAt;
}
// reminders that are due now and not yet notified (ready to fire a notification)
function pendingReminders(doc, nowMs) {
    var out = [];
    for (var i = 0; i < doc.reminders.length; i++) {
        var r = doc.reminders[i];
        if (!isReminderActive(r) || r.notified) continue;
        var due = effectiveDue(r);
        if (due && new Date(due).getTime() <= nowMs) out.push(r);
    }
    return out;
}
function overdueReminderCount(doc, nowMs) {
    var n = 0;
    for (var i = 0; i < doc.reminders.length; i++) {
        var r = doc.reminders[i];
        if (!isReminderActive(r) || r.ackedAt) continue;
        var due = effectiveDue(r);
        if (due && new Date(due).getTime() <= nowMs) n++;
    }
    return n;
}

// ------------------------------------------------------------- tags ----------
function findTagByName(doc, name) {
    name = (name || "").toLowerCase().replace(/^#/, "").trim();
    for (var id in doc.tags) if (doc.tags[id].name === name) return id;
    return null;
}
// idempotent: returns the existing tag id or creates a new one
function ensureTag(doc, name, color) {
    var d = clone(doc);
    name = (name || "").toLowerCase().replace(/^#/, "").trim();
    if (!name) return { doc: d, id: null };
    var existing = findTagByName(d, name);
    if (existing) return { doc: d, id: existing };
    var t = Schema.makeTag({ name: name, color: color || "" });
    d.tags[t.id] = t;
    return { doc: bump(d), id: t.id };
}
function addTagToItem(doc, collection, itemId, tagId) {
    var d = clone(doc), it = byId(d[collection], itemId);
    if (it && tagId) {
        it.tagIds = it.tagIds || [];
        if (it.tagIds.indexOf(tagId) < 0) { it.tagIds.push(tagId); touch(it); }
    }
    return bump(d);
}
function removeTagFromItem(doc, collection, itemId, tagId) {
    var d = clone(doc), it = byId(d[collection], itemId);
    if (it && it.tagIds) {
        var i = it.tagIds.indexOf(tagId);
        if (i >= 0) { it.tagIds.splice(i, 1); touch(it); }
    }
    return bump(d);
}
function renameTag(doc, tagId, name) {
    var d = clone(doc);
    if (d.tags[tagId]) d.tags[tagId].name = (name || "").toLowerCase().replace(/^#/, "").trim();
    return bump(d);
}
function setTagColor(doc, tagId, color) {
    var d = clone(doc);
    if (d.tags[tagId]) d.tags[tagId].color = color;
    return bump(d);
}
function deleteTag(doc, tagId) {
    var d = clone(doc);
    delete d.tags[tagId];
    ["notes", "todos", "cards", "reminders"].forEach(function (coll) {
        d[coll].forEach(function (it) {
            if (it.tagIds) {
                var i = it.tagIds.indexOf(tagId);
                if (i >= 0) it.tagIds.splice(i, 1);
            }
        });
    });
    return bump(d);
}
// derived, never persisted: how many items reference each tag
function tagCounts(doc) {
    var counts = {};
    ["notes", "todos", "cards", "reminders"].forEach(function (coll) {
        doc[coll].forEach(function (it) {
            (it.tagIds || []).forEach(function (tid) { counts[tid] = (counts[tid] || 0) + 1; });
        });
    });
    return counts;
}

// ------------------------------------------------------------ kanban ---------
function addBoard(doc, fields) {
    var d = clone(doc);
    fields = fields || {};
    if (fields.order == null) fields.order = maxOrder(d.boards) + 1;
    var board = Schema.makeBoard(fields);
    d.boards.push(board);
    if (!d.ui) d.ui = {};
    d.ui.activeKanbanBoardId = board.id;
    return { doc: bump(d), id: board.id };
}
function boardsSorted(doc) {
    return (doc.boards || []).slice().sort(function (a, b) { return (a.order || 0) - (b.order || 0); });
}
function columnsOf(doc, boardId) {
    return doc.columns
        .filter(function (c) { return c.boardId === boardId; })
        .sort(function (a, b) { return (a.order || 0) - (b.order || 0); });
}
function setActiveKanbanBoard(doc, boardId) {
    var d = clone(doc);
    if (!byId(d.boards || [], boardId)) return d;
    if (!d.ui) d.ui = {};
    if (d.ui.activeKanbanBoardId === boardId) return d;
    d.ui.activeKanbanBoardId = boardId;
    return bump(d);
}
function addColumn(doc, boardId, fields) {
    var d = clone(doc);
    fields = fields || {};
    fields.boardId = boardId;
    if (fields.order == null) fields.order = maxOrder(columnsOf(d, boardId)) + 1;
    var c = Schema.makeColumn(fields);
    d.columns.push(c);
    return { doc: bump(d), id: c.id };
}
function addCard(doc, columnId, fields) {
    var d = clone(doc);
    fields = fields || {};
    fields.columnId = columnId;
    var siblings = d.cards.filter(function (c) { return c.columnId === columnId; });
    if (fields.order == null) fields.order = maxOrder(siblings) + 1;
    var card = Schema.makeCard(fields);
    d.cards.push(card);
    return { doc: bump(d), id: card.id };
}
function cardsOf(doc, columnId) {
    return doc.cards
        .filter(function (c) { return c.columnId === columnId && !c.archived; })
        .sort(function (a, b) { return (a.order || 0) - (b.order || 0); });
}
// move a card before another (or to a column's end), rewriting only columnId+order
function moveCardBefore(doc, cardId, toColumnId, beforeCardId) {
    var d = clone(doc), card = byId(d.cards, cardId);
    if (!card) return d;
    card.columnId = toColumnId;
    var siblings = d.cards
        .filter(function (c) { return c.columnId === toColumnId && c.id !== cardId; })
        .sort(function (a, b) { return (a.order || 0) - (b.order || 0); });
    var prev = null, next = null;
    if (!beforeCardId) {
        prev = siblings.length ? siblings[siblings.length - 1].order : 0;
    } else {
        var bi = -1;
        for (var i = 0; i < siblings.length; i++) if (siblings[i].id === beforeCardId) { bi = i; break; }
        if (bi < 0) { prev = siblings.length ? siblings[siblings.length - 1].order : 0; }
        else { next = siblings[bi].order; prev = bi > 0 ? siblings[bi - 1].order : null; }
    }
    var order;
    if (prev == null && next == null) order = 1;
    else if (prev == null) order = next - 1;
    else if (next == null) order = prev + 1;
    else order = (prev + next) / 2;
    card.order = order;
    touch(card);
    return bump(d);
}

// Move across project boards. A new/empty board gets one usable landing
// column so the card can never become orphaned or invisible.
function moveCardToBoard(doc, cardId, boardId, defaultColumnTitle) {
    var d = clone(doc), card = byId(d.cards, cardId);
    if (!card || !byId(d.boards || [], boardId)) return d;
    var columns = columnsOf(d, boardId);
    var targetColumnId = "";
    if (columns.length > 0) {
        targetColumnId = columns[0].id;
    } else {
        var column = Schema.makeColumn({
            boardId: boardId,
            title: defaultColumnTitle || "To Do",
            order: 1
        });
        d.columns.push(column);
        targetColumnId = column.id;
    }
    return moveCardBefore(d, cardId, targetColumnId, null);
}

// ---------------------------------------------------------- attachments ------
function recomputeAttachmentRefCounts(doc) {
    var refs = {};
    function tally(it) { (it.attachmentIds || []).forEach(function (s) { refs[s] = (refs[s] || 0) + 1; }); }
    doc.notes.forEach(tally);
    doc.todos.forEach(tally);
    doc.cards.forEach(tally);
    doc.trash.forEach(function (t) { if (t.item) tally(t.item); });
    for (var sha in doc.attachments) doc.attachments[sha].refCount = refs[sha] || 0;
    for (var s in refs) if (!doc.attachments[s]) doc.attachments[s] = { sha256: s, refCount: refs[s] };
    return doc;
}
function addAttachmentMeta(doc, meta) {
    var d = clone(doc), sha = meta.sha256;
    d.attachments[sha] = {
        sha256: sha, ext: meta.ext || "", mime: meta.mime || "",
        bytes: meta.bytes || 0, width: meta.width || null, height: meta.height || null,
        refCount: (d.attachments[sha] ? d.attachments[sha].refCount : 0) || 0,
        importedAt: meta.importedAt || nowIso()
    };
    return d; // not bumped: the attach-to-item call that follows bumps
}
function attachToItem(doc, collection, itemId, sha) {
    var d = clone(doc), it = byId(d[collection], itemId);
    if (it) {
        it.attachmentIds = it.attachmentIds || [];
        if (it.attachmentIds.indexOf(sha) < 0) { it.attachmentIds.push(sha); touch(it); }
    }
    recomputeAttachmentRefCounts(d);
    return bump(d);
}
function detachFromItem(doc, collection, itemId, sha) {
    var d = clone(doc), it = byId(d[collection], itemId);
    if (it && it.attachmentIds) {
        var i = it.attachmentIds.indexOf(sha);
        if (i >= 0) { it.attachmentIds.splice(i, 1); touch(it); }
    }
    recomputeAttachmentRefCounts(d);
    return bump(d);
}
function attachmentPath(doc, dataDir, sha) {
    var a = doc.attachments[sha];
    if (!a) return "";
    return dataDir + "/attachments/" + sha + (a.ext ? "." + a.ext : "");
}

// --------------------------------------------------- import / merge ----------
// newer-rev-wins union by id across collections; tags/attachments maps unioned.
function mergeDocs(current, incoming) {
    var d = clone(current);
    ["notes", "todos", "boards", "columns", "cards", "reminders"].forEach(function (coll) {
        var seen = {};
        d[coll].forEach(function (it) { seen[it.id] = true; });
        (incoming[coll] || []).forEach(function (it) {
            var i = indexOf(d[coll], it.id);
            if (i < 0) d[coll].push(it);
            else if ((it.rev || 0) > (d[coll][i].rev || 0)) d[coll][i] = it;
        });
    });
    for (var tid in (incoming.tags || {})) if (!d.tags[tid]) d.tags[tid] = incoming.tags[tid];
    for (var sha in (incoming.attachments || {})) if (!d.attachments[sha]) d.attachments[sha] = incoming.attachments[sha];
    recomputeAttachmentRefCounts(d);
    return bump(d);
}

// ------------------------------------------------------ sort / filter --------
function compare(a, b, by) {
    switch (by) {
    case "title":    return ("" + (a.title || a.text || "")).toLowerCase()
                            .localeCompare(("" + (b.title || b.text || "")).toLowerCase());
    case "created":  return new Date(a.createdAt) - new Date(b.createdAt);
    case "priority": return (a.priority || 0) - (b.priority || 0);
    case "due":      return new Date(a.dueAt || 8640000000000000) - new Date(b.dueAt || 8640000000000000);
    default:         return new Date(a.updatedAt) - new Date(b.updatedAt); // "updated"
    }
}
function sortItems(items, by, desc) {
    var arr = items.slice();
    arr.sort(function (a, b) { var r = compare(a, b, by); return desc ? -r : r; });
    return arr;
}
// notes are always pinned-first, then sorted within each group
function sortNotes(notes, by, desc) {
    var pinned = notes.filter(function (n) { return n.pinned; });
    var rest = notes.filter(function (n) { return !n.pinned; });
    return sortItems(pinned, by, desc).concat(sortItems(rest, by, desc));
}
function visibleItems(items, opts) {
    opts = opts || {};
    return items.filter(function (it) {
        if (!opts.showArchived && it.archived) return false;
        if (opts.tagId && (it.tagIds || []).indexOf(opts.tagId) < 0) return false;
        return true;
    });
}
