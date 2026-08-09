import QtQuick
import QtCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import "../code/schema.js" as Schema
import "../code/model.js" as Model

// Quick Notes — a unified notes / to-do / kanban / reminders hub. main.qml owns
// the single in-memory document (root.doc) and all persistence: views are dumb
// renderers that call the intent functions here, which apply a pure op from
// model.js, reassign root.doc (firing bindings) and schedule a debounced save
// through the store.sh broker. The broker is the only thing that touches disk.
PlasmoidItem {
    id: root

    // the whole data set; null until the first load completes
    property var doc: null
    property bool loaded: false
    property double nowMs: Date.now()
    property string lastSaved: ""
    property string statusMessage: ""

    // ----- config mirrors -------------------------------------------------
    readonly property string accentKey: Plasmoid.configuration.accent
    readonly property bool use24h: Plasmoid.configuration.timeFormat24h

    // ----- data dir + broker command building -----------------------------
    readonly property string scriptPath:
        Qt.resolvedUrl("../code/store.sh").toString().replace(/^file:\/\//, "")

    function resolveDataDir() {
        var override = ("" + (Plasmoid.configuration.dataDirOverride || "")).trim();
        if (override !== "") return override.replace(/^file:\/\//, "");
        var base = "" + StandardPaths.writableLocation(StandardPaths.GenericDataLocation);
        base = base.replace(/^file:\/\//, "");
        if (base.charAt(base.length - 1) === "/") base = base.substring(0, base.length - 1);
        return base + "/conqrex/quicknotes";
    }
    readonly property string dataDir: resolveDataDir()

    // POSIX single-quote escaping so any path/payload survives the shell
    function shq(s) { return "'" + ("" + s).replace(/'/g, "'\\''") + "'"; }
    function envPrefix() {
        return "QN_DATA_DIR=" + shq(dataDir)
             + " QN_BACKUP_COUNT=" + Plasmoid.configuration.backupCount
             + " QN_MAX_BYTES=" + (Plasmoid.configuration.maxAttachmentMB * 1048576) + " ";
    }
    function storeCmd(args) { return envPrefix() + "bash " + shq(scriptPath) + " " + args; }

    // ----- derived badge counts -------------------------------------------
    function countOpenTodos(d) {
        if (!d) return 0;
        var n = 0;
        for (var i = 0; i < d.todos.length; i++)
            if (!d.todos[i].archived && d.todos[i].status !== "done") n++;
        return n;
    }
    readonly property int overdueCount: (loaded && doc) ? Model.overdueReminderCount(doc, nowMs) : 0
    readonly property int openTodoCount: countOpenTodos(doc)

    // ======================================================================
    //  Persistence plumbing
    // ======================================================================
    property var pendingCtx: ({})
    property int _nonce: 0

    Plasma5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            var ctx = root.pendingCtx[source] || { kind: "unknown" };
            delete root.pendingCtx[source];
            disconnectSource(source);
            var out = ("" + data["stdout"]).trim();
            var code = data["exit code"];
            root.handleResult(ctx, out, code);
        }
        function exec(cmd, ctx) {
            var keyed = "QN_N=" + (root._nonce++) + " " + cmd;
            root.pendingCtx[keyed] = ctx || { kind: "unknown" };
            connectSource(keyed);
        }
    }

    function handleResult(ctx, out, code) {
        switch (ctx.kind) {
        case "load":
            applyLoaded(out, code);
            break;
        case "chunk":
            writeNextChunk();
            break;
        case "save":
            _saving = false;
            if (code === 0) {
                root.lastSaved = Qt.formatDateTime(new Date(), use24h ? "HH:mm" : "h:mm AP");
                try { Plasmoid.configuration.lastKnownRev = JSON.parse(out).rev || 0; } catch (e) {}
            } else {
                root.statusMessage = i18n("Save failed — your last edit may not be on disk");
            }
            if (_saveQueued) { _saveQueued = false; saveDoc(); }
            break;
        case "attach":
            finishAttach(ctx, out, code);
            break;
        case "import":
            finishImport(ctx, out, code);
            break;
        case "stat":
            try { root.statInfo = JSON.parse(out); } catch (e) {}
            break;
        case "toast":
            if (code === 0) root.statusMessage = ctx.message || i18n("Done");
            else root.statusMessage = ctx.errorMessage || i18n("Operation failed");
            break;
        }
    }

    // ----- load -----------------------------------------------------------
    function load() { exec.exec(storeCmd("init"), { kind: "load" }); }

    function applyLoaded(out, code) {
        var d;
        try { d = JSON.parse(out); } catch (e) { d = null; }
        if (!d || code !== 0) { d = Schema.defaultDoc(); }

        // first-run device id, persisted to both the doc and config
        if (!d.deviceId) {
            var did = Plasmoid.configuration.deviceId
                    || ("dev-" + Date.now().toString(36) + "-" + Math.floor(Math.random() * 1e9).toString(36));
            d.deviceId = did;
            Plasmoid.configuration.deviceId = did;
        }
        // recover attachment ref-counts + purge expired trash on every boot
        Model.recomputeAttachmentRefCounts(d);
        var before = d.trash.length;
        d = Model.purgeExpiredTrash(d, Date.now());
        root.doc = d;
        root.loaded = true;
        if (d.trash.length !== before) saveDoc();   // persist the purge
        root.tick();                                  // immediate catch-up on overdue reminders
    }

    // ----- chunked atomic save -------------------------------------------
    // The doc is serialized and written to a temp file by appending <=20k-char
    // chunks (one shell command each, sequentially) so no single command exceeds
    // the kernel's per-arg limit. store.sh then validates + atomically replaces
    // store.json. Saves are debounced and coalesced.
    property bool _saving: false
    property bool _saveQueued: false
    property var _saveChunks: []
    property int _saveIndex: 0
    property string _saveTmp: ""

    function saveDoc() {
        if (!loaded || !doc) return;
        if (_saving) { _saveQueued = true; return; }
        _saving = true;
        var json = JSON.stringify(doc);
        _saveTmp = dataDir + "/.save-tmp.json";
        _saveChunks = [];
        for (var i = 0; i < json.length; i += 20000) _saveChunks.push(json.substring(i, i + 20000));
        if (_saveChunks.length === 0) _saveChunks.push("");
        _saveIndex = 0;
        writeNextChunk();
    }
    function writeNextChunk() {
        if (_saveIndex >= _saveChunks.length) {
            exec.exec(storeCmd("save " + shq(_saveTmp)), { kind: "save" });
            return;
        }
        var redir = (_saveIndex === 0) ? " > " : " >> ";
        var cmd = "printf '%s' " + shq(_saveChunks[_saveIndex]) + redir + shq(_saveTmp);
        _saveIndex++;
        exec.exec(cmd, { kind: "chunk" });
    }

    Timer {
        id: saveDebounce
        interval: Math.max(200, Plasmoid.configuration.autosaveDebounceMs)
        repeat: false
        onTriggered: root.saveDoc()
    }
    function scheduleSave() { saveDebounce.restart(); }

    // commit the current doc and reschedule (used by every intent)
    function commit(newDoc) { root.doc = newDoc; scheduleSave(); }

    // ======================================================================
    //  Intent API — views call these; each applies a pure model op + saves
    // ======================================================================
    // notes
    function addNote(fields) { var r = Model.addNote(doc, fields || {}); commit(r.doc); return r.id; }
    function updateNote(id, patch) { commit(Model.updateItem(doc, "notes", id, patch)); }
    function togglePin(id) { commit(Model.togglePin(doc, id)); }
    // generic
    function setColor(coll, id, c) { commit(Model.setColor(doc, coll, id, c)); }
    function setArchived(coll, id, v) { commit(Model.setArchived(doc, coll, id, v)); }
    function setPriority(coll, id, p) { commit(Model.setPriority(doc, coll, id, p)); }
    function setDue(coll, id, iso) { commit(Model.setDue(doc, coll, id, iso)); }
    function updateItem(coll, id, patch) { commit(Model.updateItem(doc, coll, id, patch)); }
    function deleteItem(coll, id) { commit(Model.softDelete(doc, coll, id, Plasmoid.configuration.trashRetentionDays)); }
    function restoreItem(id) { commit(Model.restoreTrash(doc, id)); }
    function emptyTrash() { commit(Model.emptyTrash(doc)); }
    // todos
    function addTodo(fields) { var r = Model.addTodo(doc, fields || {}); commit(r.doc); return r.id; }
    function cycleTodo(id) { commit(Model.cycleTodoStatus(doc, id)); }
    function toggleTodoDone(id) { commit(Model.toggleTodoDone(doc, id)); }
    function setTodoStatus(id, s) { commit(Model.setTodoStatus(doc, id, s)); }
    function reorder(coll, ids) { commit(Model.reorderList(doc, coll, ids)); }
    // reminders
    function addReminder(fields) { var r = Model.addReminder(doc, fields || {}); commit(r.doc); return r.id; }
    function ackReminder(id) { commit(Model.ackReminder(doc, id)); }
    function snoozeReminder(id, min) { commit(Model.snoozeReminder(doc, id, min)); }
    // tags
    function ensureTag(name, color) { var r = Model.ensureTag(doc, name, color); root.doc = r.doc; scheduleSave(); return r.id; }
    function addTagToItem(coll, id, tagId) { commit(Model.addTagToItem(doc, coll, id, tagId)); }
    function removeTagFromItem(coll, id, tagId) { commit(Model.removeTagFromItem(doc, coll, id, tagId)); }
    function renameTag(tagId, name) { commit(Model.renameTag(doc, tagId, name)); }
    function setTagColor(tagId, c) { commit(Model.setTagColor(doc, tagId, c)); }
    function deleteTag(tagId) { commit(Model.deleteTag(doc, tagId)); }
    // kanban
    function addColumn(fields) { var r = Model.addColumn(doc, fields || {}); commit(r.doc); return r.id; }
    function addCard(colId, fields) { var r = Model.addCard(doc, colId, fields || {}); commit(r.doc); return r.id; }
    function moveCard(cardId, toCol, beforeId) { commit(Model.moveCardBefore(doc, cardId, toCol, beforeId)); }

    // tag a freshly-created item from a list of tag names (quick-add helper)
    function applyTagNames(coll, itemId, names) {
        if (!names || names.length === 0) return;
        var d = doc;
        for (var i = 0; i < names.length; i++) {
            var r = Model.ensureTag(d, names[i]);
            d = r.doc;
            if (r.id) d = Model.addTagToItem(d, coll, itemId, r.id);
        }
        commit(d);
    }

    // ----- attachments (async: attach blob, then reference it) ------------
    function attachFile(coll, itemId, srcPath) {
        if (!Plasmoid.configuration.attachmentsEnabled) return;
        exec.exec(storeCmd("attach " + shq(srcPath)), { kind: "attach", coll: coll, itemId: itemId });
    }
    function finishAttach(ctx, out, code) {
        var meta;
        try { meta = JSON.parse(out); } catch (e) { meta = null; }
        if (!meta || !meta.ok) { root.statusMessage = i18n("Could not attach file"); return; }
        var d = Model.addAttachmentMeta(doc, meta);
        d = Model.attachToItem(d, ctx.coll, ctx.itemId, meta.sha256);
        commit(d);
    }
    function detach(coll, itemId, sha) { commit(Model.detachFromItem(doc, coll, itemId, sha)); }
    function attachmentPath(sha) { return Model.attachmentPath(doc, dataDir, sha); }
    function runGc() {
        // write current doc to a temp, then gc against it
        var json = JSON.stringify(doc);
        var tmp = dataDir + "/.gc-tmp.json";
        exec.exec("printf '%s' " + shq(json) + " > " + shq(tmp) + " && " + storeCmd("gc " + shq(tmp)),
                  { kind: "toast", message: i18n("Cleaned up unused attachments") });
    }

    // ----- backup / export / import ---------------------------------------
    function backupNow() { exec.exec(storeCmd("backup"), { kind: "toast", message: i18n("Backup written") }); }
    function exportJson(path) { exec.exec(storeCmd("export " + shq(path)), { kind: "toast", message: i18n("Exported to JSON") }); }
    function exportMarkdown(dir) { exec.exec(storeCmd("exportmd " + shq(dir)), { kind: "toast", message: i18n("Exported notes to Markdown") }); }
    function importFile(path, mode) {
        exec.exec(storeCmd("import " + shq(path)), { kind: "import", mode: mode || "merge" });
    }
    function finishImport(ctx, out, code) {
        var incoming;
        try { incoming = JSON.parse(out); } catch (e) { incoming = null; }
        if (!incoming || code !== 0 || !incoming.schemaVersion) {
            root.statusMessage = i18n("Import failed — not a valid backup");
            return;
        }
        var merged = (ctx.mode === "replace") ? incoming : Model.mergeDocs(doc, incoming);
        if (!merged.deviceId) merged.deviceId = doc.deviceId;
        Model.recomputeAttachmentRefCounts(merged);
        commit(merged);
        root.statusMessage = (ctx.mode === "replace")
            ? i18n("Replaced with imported data")
            : i18n("Merged imported data");
    }

    property var statInfo: ({})
    function refreshStat() { exec.exec(storeCmd("stat"), { kind: "stat" }); }

    // ======================================================================
    //  Reminders: poll for due ones, fire notifications, re-arm/roll forward
    // ======================================================================
    Notifier { id: notifier; runCommand: function (cmd) { exec.exec(cmd, { kind: "ignore" }); } }

    Timer {
        interval: Math.max(15, Plasmoid.configuration.reminderPollSeconds) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }
    function tick() {
        root.nowMs = Date.now();
        if (!loaded || !doc) return;
        if (Plasmoid.configuration.remindersEnabled) {
            var due = Model.pendingReminders(doc, nowMs);
            if (due.length > 0) {
                var d = doc;
                for (var i = 0; i < due.length; i++) {
                    notifier.fire(i18n("Reminder"), due[i].text || i18n("(no text)"),
                                  Plasmoid.configuration.notifyUrgency);
                    d = Model.markReminderFired(d, due[i].id, nowMs);
                }
                commit(d);
            }
        }
        // occasional trash purge while running
        if (doc.trash.length > 0) {
            var b = doc.trash.length;
            var pd = Model.purgeExpiredTrash(doc, nowMs);
            if (pd.trash.length !== b) commit(pd);
        }
    }

    // daily auto-backup (best-effort, based on a stored date stamp)
    property string _lastBackupDay: ""
    function maybeDailyBackup() {
        if (!Plasmoid.configuration.autoBackupDaily) return;
        var today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        if (root._lastBackupDay !== today) { root._lastBackupDay = today; backupNow(); }
    }

    Component.onCompleted: { load(); }

    // ======================================================================
    //  Representations
    // ======================================================================
    toolTipMainText: i18n("Quick Notes")
    toolTipSubText: {
        if (!loaded) return i18n("Loading…");
        var parts = [];
        if (doc && doc.reminders.length) {
            var next = null;
            for (var i = 0; i < doc.reminders.length; i++) {
                var r = doc.reminders[i];
                if (r.ackedAt && (!r.repeat || r.repeat === "none")) continue;
                var due = new Date(r.snoozeUntil || r.dueAt).getTime();
                if (due > nowMs && (!next || due < next.due)) next = { due: due, text: r.text };
            }
            if (next) {
                // A reminder body can be arbitrarily long; the panel tooltip is not
                // the place to render all of it, so cap the substituted value.
                var label = ("" + next.text);
                if (label.length > 40) label = label.substring(0, 39).trimEnd() + "…";
                parts.push(i18n("Next: %1 (%2)", label,
                    Qt.formatDateTime(new Date(next.due), use24h ? "ddd hh:mm" : "ddd h:mm AP")));
            }
        }
        if (openTodoCount > 0) parts.push(i18np("%1 open to-do", "%1 open to-dos", openTodoCount));
        if (overdueCount > 0) parts.push(i18np("%1 reminder due", "%1 reminders due", overdueCount));
        if (doc && doc.notes.length > 0) parts.push(i18np("%1 note", "%1 notes", doc.notes.length));
        return parts.length ? parts.join("  ·  ") : i18n("No notes yet — click to add one");
    }

    compactRepresentation: CompactView {
        overdue: root.overdueCount
        openTodos: root.openTodoCount
        accentKey: root.accentKey
        onToggleRequested: root.expanded = !root.expanded
    }

    fullRepresentation: FullView { controller: root }
}
