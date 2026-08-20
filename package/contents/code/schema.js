.pragma library

// Single source of truth for the document shape. Item factories stamp ids,
// timestamps and an initial rev; defaultDoc() mirrors store.sh's default_doc().

var CURRENT_SCHEMA_VERSION = 2;
var APP_VERSION = "0.2.1";

// Collision-safe id: "<type>-<base36 time>-<base36 random>" (never an array index).
function uid(type) {
    var ts = Date.now().toString(36);
    var rand = Math.floor(Math.random() * 1e9).toString(36);
    return (type || "id") + "-" + ts + "-" + rand;
}

function nowIso() { return new Date().toISOString(); }

function defaultDoc() {
    return {
        schemaVersion: CURRENT_SCHEMA_VERSION,
        appVersion: APP_VERSION,
        rev: 0,
        deviceId: "",
        generatedAt: nowIso(),
        ui: {},
        notes: [], todos: [], boards: [], columns: [], cards: [],
        reminders: [], tags: {}, links: [], attachments: {}, trash: [],
        meta: { nextSeq: 0 }
    };
}

function _num(v, dflt) { return (v === null || v === undefined) ? dflt : v; }

function makeNote(o) {
    o = o || {};
    var t = nowIso();
    return {
        id: o.id || uid("note"), type: "note",
        title: o.title || "", body: o.body || "",
        color: o.color || "", pinned: !!o.pinned, archived: !!o.archived,
        tagIds: o.tagIds || [], attachmentIds: o.attachmentIds || [],
        createdAt: o.createdAt || t, updatedAt: o.updatedAt || t, rev: o.rev || 1
    };
}

function makeTodo(o) {
    o = o || {};
    var t = nowIso();
    return {
        id: o.id || uid("todo"), type: "todo",
        text: o.text || "", status: o.status || "todo",
        priority: _num(o.priority, 0), dueAt: o.dueAt || null,
        repeat: o.repeat || "none", order: _num(o.order, 0),
        color: o.color || "", tagIds: o.tagIds || [], archived: !!o.archived,
        attachmentIds: o.attachmentIds || [],
        createdAt: o.createdAt || t, updatedAt: o.updatedAt || t, rev: o.rev || 1
    };
}

function makeBoard(o) {
    o = o || {};
    var t = nowIso();
    return {
        id: o.id || uid("board"), type: "board",
        title: o.title || "My Board", color: o.color || "",
        order: _num(o.order, 0),
        createdAt: o.createdAt || t, updatedAt: o.updatedAt || t, rev: o.rev || 1
    };
}

function makeColumn(o) {
    o = o || {};
    var t = nowIso();
    return {
        id: o.id || uid("col"), type: "column", boardId: o.boardId || "",
        title: o.title || "New column", color: o.color || "",
        order: _num(o.order, 0), wipLimit: _num(o.wipLimit, null),
        createdAt: o.createdAt || t, updatedAt: o.updatedAt || t, rev: o.rev || 1
    };
}

function makeCard(o) {
    o = o || {};
    var t = nowIso();
    return {
        id: o.id || uid("card"), type: "card",
        columnId: o.columnId || "", order: _num(o.order, 0),
        title: o.title || "", body: o.body || "",
        priority: _num(o.priority, 0), status: o.status || "",
        dueAt: o.dueAt || null, color: o.color || "", archived: !!o.archived,
        tagIds: o.tagIds || [], attachmentIds: o.attachmentIds || [],
        boardPos: o.boardPos || null,
        createdAt: o.createdAt || t, updatedAt: o.updatedAt || t, rev: o.rev || 1
    };
}

function makeReminder(o) {
    o = o || {};
    var t = nowIso();
    return {
        id: o.id || uid("rem"), type: "reminder",
        text: o.text || "", dueAt: o.dueAt || nowIso(),
        repeat: o.repeat || "none", notified: !!o.notified,
        ackedAt: o.ackedAt || null, snoozeUntil: o.snoozeUntil || null,
        refId: o.refId || null, color: o.color || "", tagIds: o.tagIds || [],
        createdAt: o.createdAt || t, updatedAt: o.updatedAt || t, rev: o.rev || 1
    };
}

function makeTag(o) {
    o = o || {};
    return {
        id: o.id || uid("tag"),
        name: (o.name || "").toLowerCase(),
        color: o.color || "",
        createdAt: o.createdAt || nowIso()
    };
}
