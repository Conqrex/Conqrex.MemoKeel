#!/usr/bin/env bash
#
# store.sh — the SOLE filesystem writer for the MemoKeel widget.
#
# QML never touches the disk; it shells out to this broker through
# Plasma5Support.DataSource{engine:"executable"}. The whole data set lives in a
# single versioned JSON document (store.json). Saves are flock-serialized and
# atomic (write-temp + fsync + rename), with a last-good journal for crash
# recovery and pre-migration / pre-import / rolling backups.
#
# Data dir: $QN_DATA_DIR if set (QML passes the StandardPaths-resolved path or a
# user override), else ${XDG_DATA_HOME:-$HOME/.local/share}/conqrex/memokeel.
# $QN_MIGRATE_FROM may name a pre-rename data dir (the old .../conqrex/quicknotes):
# on the first load, and only when our own store.json does not exist yet, its
# contents are COPIED across and the load result carries a transport-only
# "migratedFrom" field. The legacy dir is never moved, modified or deleted.
#
# Subcommands (all print one JSON line / document on stdout; diagnostics -> stderr):
#   init                       ensure dirs + store.json; print the (migrated) doc
#   load                       print the (migrated, recovered-if-needed) doc
#   save <payload-tmp>         validate + journal + atomic-write the doc; -> {ok,rev}
#   stat                       print data dir + sizes/counts
#   attach <src>               sha256 content-address a file into attachments/; -> {ok,sha256,...}
#   gc <doc-tmp>               delete attachment blobs not referenced by the doc; -> {ok,removed}
#   backup                     write a rolling snapshot (pruned to QN_BACKUP_COUNT)
#   migrate                    load (which migrates) and persist the result
#   export <path>              write store.json + checksum/exportedAt to <path>
#   exportmd <dir>             write one .md per note + index.md into <dir>
#   import <path>              validate + snapshot current state; print the imported doc
#
set -u

SCHEMA_VERSION=1
APP_VERSION="0.1.0"

DATA_DIR="${QN_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/conqrex/memokeel}"
MIGRATE_FROM="${QN_MIGRATE_FROM:-}"
STORE="$DATA_DIR/store.json"
LOCK="$DATA_DIR/store.lock"
ATTACH_DIR="$DATA_DIR/attachments"
BACKUP_DIR="$DATA_DIR/backups"
JOURNAL_DIR="$DATA_DIR/journal"
LASTGOOD="$JOURNAL_DIR/last-good.json"

BACKUP_COUNT="${QN_BACKUP_COUNT:-10}"
MAX_BYTES="${QN_MAX_BYTES:-0}"          # 0 = unlimited (QML enforces the real cap)

iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
err()     { printf '%s\n' "$*" >&2; }
emit_err() { printf '{"ok":false,"reason":"%s"}\n' "$1"; exit "${2:-0}"; }

have() { command -v "$1" >/dev/null 2>&1; }

if ! have jq; then
    err "store.sh: 'jq' is required but not installed"
    emit_err "no_jq" 1
fi

ensure_dirs() {
    mkdir -p "$DATA_DIR" "$ATTACH_DIR" "$BACKUP_DIR" "$JOURNAL_DIR" 2>/dev/null
}

# A fresh, empty document. deviceId + item ids are minted later in QML.
default_doc() {
    jq -cn --argjson sv "$SCHEMA_VERSION" --arg av "$APP_VERSION" --arg ts "$(iso_now)" '{
        schemaVersion: $sv, appVersion: $av, rev: 0, deviceId: "",
        generatedAt: $ts, ui: {},
        notes: [], todos: [], columns: [], cards: [],
        reminders: [], tags: {}, links: [], attachments: {}, trash: [],
        meta: { nextSeq: 0 }
    }'
}

valid_json() { jq -e . "$1" >/dev/null 2>&1; }

# Defensive: guarantee every expected top-level key exists with the right type,
# so views never crash on a hand-edited or partial document.
normalize() {
    jq -c '
        . as $d
        | {
            schemaVersion: ($d.schemaVersion // 1),
            appVersion:    ($d.appVersion // "0.0.0"),
            rev:           ($d.rev // 0),
            deviceId:      ($d.deviceId // ""),
            generatedAt:   ($d.generatedAt // ""),
            ui:            ($d.ui // {}),
            notes:         ($d.notes // []),
            todos:         ($d.todos // []),
            columns:       ($d.columns // []),
            cards:         ($d.cards // []),
            reminders:     ($d.reminders // []),
            tags:          ($d.tags // {}),
            links:         ($d.links // []),
            attachments:   ($d.attachments // {}),
            trash:         ($d.trash // []),
            meta:          ($d.meta // { nextSeq: 0 })
        }'
}

# Ordered, durable migration. Returns the migrated doc on stdout; if a forward
# migration was applied it also snapshots the pre-migration state and rewrites
# store.json so the bump is persistent. A future-versioned store is refused.
migrate_store() {
    local disk_v
    disk_v="$(jq -r '.schemaVersion // 0' "$STORE" 2>/dev/null)"
    [ -n "$disk_v" ] || disk_v=0

    if [ "$disk_v" -gt "$SCHEMA_VERSION" ] 2>/dev/null; then
        err "store.sh: store schemaVersion $disk_v is newer than app $SCHEMA_VERSION — refusing to downgrade"
        return 1
    fi

    if [ "$disk_v" -lt "$SCHEMA_VERSION" ] 2>/dev/null; then
        cp -f "$STORE" "$BACKUP_DIR/premigrate-v${disk_v}-$(date -u +%Y%m%d-%H%M%S).json" 2>/dev/null
        # apply ordered steps here as the schema evolves; v0->v1 only needs the
        # defensive normalize + version bump.
        normalize < "$STORE" | jq -c --argjson sv "$SCHEMA_VERSION" '.schemaVersion = $sv' > "$STORE.mig.$$" \
            && mv -f "$STORE.mig.$$" "$STORE"
    fi
    normalize < "$STORE"
}

# One-shot import of a pre-rename data directory. Copies, never moves: the
# legacy directory is left untouched as the user's fallback. No-op unless the
# caller names a legacy dir that has a store.json and our own store.json is
# absent, so it cannot fire twice and cannot overwrite live data. The copy runs
# under the same flock the writers use, and store.json is renamed into place
# last, so an interrupted or concurrent run cannot leave a half-written store.
MIGRATED_FROM=""
maybe_migrate_legacy() {
    [ -n "$MIGRATE_FROM" ]             || return 0
    [ "$MIGRATE_FROM" != "$DATA_DIR" ] || return 0
    [ -f "$MIGRATE_FROM/store.json" ]  || return 0
    [ ! -f "$STORE" ]                  || return 0

    mkdir -p "$DATA_DIR" || return 0
    (
        flock -w 10 9 || { err "store.sh: could not acquire lock for migration"; exit 1; }
        # re-check under the lock: another instance may have won the race
        [ ! -f "$STORE" ] || exit 1
        cp -a "$MIGRATE_FROM/store.json" "$STORE.migrating" 2>/dev/null || exit 1
        # best-effort side data; a failure here must not lose the document
        for d in attachments backups journal; do
            if [ -d "$MIGRATE_FROM/$d" ]; then
                mkdir -p "$DATA_DIR/$d" 2>/dev/null \
                    && cp -a "$MIGRATE_FROM/$d/." "$DATA_DIR/$d/" 2>/dev/null
            fi
        done
        mv -f "$STORE.migrating" "$STORE" || exit 1
        exit 10
    ) 9>"$LOCK"
    # 10 == the subshell actually completed a migration
    [ "$?" -eq 10 ] || return 0
    MIGRATED_FROM="$MIGRATE_FROM"
    err "store.sh: migrated data from $MIGRATE_FROM"
}

cmd_load() {
    ensure_dirs
    maybe_migrate_legacy
    if [ ! -f "$STORE" ]; then
        if [ -f "$LASTGOOD" ] && valid_json "$LASTGOOD"; then
            err "store.sh: store.json missing — restoring last-good journal"
            cp -f "$LASTGOOD" "$STORE"
        else
            default_doc > "$STORE"
        fi
    fi
    if ! valid_json "$STORE"; then
        if [ -f "$LASTGOOD" ] && valid_json "$LASTGOOD"; then
            err "store.sh: store.json corrupt — restoring last-good journal"
            cp -f "$STORE" "$BACKUP_DIR/corrupt-$(date -u +%Y%m%d-%H%M%S).json" 2>/dev/null
            cp -f "$LASTGOOD" "$STORE"
        else
            err "store.sh: store.json corrupt and no journal — starting fresh"
            cp -f "$STORE" "$BACKUP_DIR/corrupt-$(date -u +%Y%m%d-%H%M%S).json" 2>/dev/null
            default_doc > "$STORE"
        fi
    fi
    # migratedFrom is transport-only — injected into the printed document so the
    # UI can toast once, never written into store.json (see the `migrate` case).
    if [ -n "$MIGRATED_FROM" ]; then
        migrate_store | jq -c --arg mf "$MIGRATED_FROM" '. + {migratedFrom: $mf}'
    else
        migrate_store
    fi
}

cmd_save() {
    local tmp="$1"
    [ -n "$tmp" ] && [ -f "$tmp" ] || emit_err "no_payload"
    valid_json "$tmp" || emit_err "invalid_json"
    ensure_dirs

    (
        flock -w 10 9 || { err "store.sh: could not acquire lock"; exit 75; }

        local out="$STORE.$$.tmp"
        normalize < "$tmp" | jq -c --arg ts "$(iso_now)" --arg av "$APP_VERSION" \
            '.generatedAt = $ts | .appVersion = $av' > "$out" || { err "store.sh: write failed"; exit 1; }
        # ensure bytes hit disk before the rename (atomic same-fs replace)
        sync "$out" 2>/dev/null || sync
        mv -f "$out" "$STORE" || { err "store.sh: rename failed"; exit 1; }
        # mirror the latest good save into the journal for corruption recovery
        cp -f "$STORE" "$LASTGOOD" 2>/dev/null
    ) 9>"$LOCK"
    local rc=$?
    [ "$rc" -eq 0 ] || emit_err "save_failed" 0

    local rev
    rev="$(jq -r '.rev // 0' "$STORE" 2>/dev/null)"
    printf '{"ok":true,"rev":%s}\n' "${rev:-0}"
}

cmd_stat() {
    ensure_dirs
    local store_bytes att_count att_bytes bk_count
    store_bytes=$( [ -f "$STORE" ] && stat -c %s "$STORE" 2>/dev/null || echo 0 )
    att_count=$( find "$ATTACH_DIR" -type f 2>/dev/null | wc -l | tr -d ' ' )
    att_bytes=$( find "$ATTACH_DIR" -type f -printf '%s\n' 2>/dev/null | awk '{s+=$1} END{print s+0}' )
    bk_count=$( find "$BACKUP_DIR" -type f 2>/dev/null | wc -l | tr -d ' ' )
    jq -cn --arg dir "$DATA_DIR" --argjson sb "${store_bytes:-0}" \
        --argjson ac "${att_count:-0}" --argjson ab "${att_bytes:-0}" --argjson bc "${bk_count:-0}" \
        '{ok:true, dataDir:$dir, storeBytes:$sb, attachmentsCount:$ac, attachmentsBytes:$ab, backupsCount:$bc}'
}

cmd_attach() {
    local src="$1"
    [ -n "$src" ] || emit_err "no_source"
    # accept file:// urls too
    src="${src#file://}"
    [ -f "$src" ] || emit_err "not_a_file"
    ensure_dirs

    local bytes
    bytes=$(stat -c %s "$src" 2>/dev/null || echo 0)
    if [ "$MAX_BYTES" -gt 0 ] 2>/dev/null && [ "$bytes" -gt "$MAX_BYTES" ] 2>/dev/null; then
        emit_err "too_large"
    fi

    local sha ext mime base
    sha=$(sha256sum "$src" 2>/dev/null | cut -d' ' -f1)
    [ -n "$sha" ] || emit_err "hash_failed"
    base="$(basename -- "$src")"
    ext="${base##*.}"
    [ "$ext" = "$base" ] && ext=""            # no extension
    ext="$(printf '%s' "$ext" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9')"
    if have file; then
        mime="$(file --mime-type -b -- "$src" 2>/dev/null)"
    else
        mime="application/octet-stream"
    fi

    local dest
    if [ -n "$ext" ]; then dest="$ATTACH_DIR/$sha.$ext"; else dest="$ATTACH_DIR/$sha"; fi
    if [ ! -f "$dest" ]; then
        cp -f -- "$src" "$dest.$$.tmp" 2>/dev/null && mv -f "$dest.$$.tmp" "$dest" 2>/dev/null \
            || emit_err "copy_failed"
    fi
    jq -cn --arg sha "$sha" --arg ext "$ext" --arg mime "$mime" --argjson bytes "${bytes:-0}" --arg ts "$(iso_now)" \
        '{ok:true, sha256:$sha, ext:$ext, mime:$mime, bytes:$bytes, importedAt:$ts}'
}

# Delete attachment blobs not referenced by any item or trash entry in the given
# document. Authoritative cleanup — the doc is the source of truth.
cmd_gc() {
    local tmp="$1"
    [ -n "$tmp" ] && [ -f "$tmp" ] || emit_err "no_payload"
    valid_json "$tmp" || emit_err "invalid_json"
    ensure_dirs

    local referenced removed=0
    referenced="$(jq -r '
        [ (.notes[]?, .todos[]?, .cards[]?, (.trash[]?.item)) | .attachmentIds[]? ] | unique | .[]
    ' "$tmp" 2>/dev/null)"

    local f base sha
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        base="$(basename -- "$f")"
        sha="${base%%.*}"
        if ! printf '%s\n' "$referenced" | grep -qxF "$sha"; then
            rm -f -- "$f" && removed=$((removed + 1))
        fi
    done < <(find "$ATTACH_DIR" -type f 2>/dev/null)

    printf '{"ok":true,"removed":%d}\n' "$removed"
}

cmd_backup() {
    ensure_dirs
    [ -f "$STORE" ] || emit_err "no_store"
    local dest="$BACKUP_DIR/snap-$(date -u +%Y%m%d-%H%M%S).json"
    cp -f "$STORE" "$dest" 2>/dev/null || emit_err "backup_failed"
    # prune to the newest BACKUP_COUNT snapshots
    if [ "$BACKUP_COUNT" -gt 0 ] 2>/dev/null; then
        ls -1t "$BACKUP_DIR"/snap-*.json 2>/dev/null | tail -n +$((BACKUP_COUNT + 1)) | while IFS= read -r old; do
            rm -f -- "$old"
        done
    fi
    printf '{"ok":true,"path":"%s"}\n' "$dest"
}

cmd_export() {
    local path="$1"
    [ -n "$path" ] || emit_err "no_path"
    path="${path#file://}"
    ensure_dirs
    [ -f "$STORE" ] || emit_err "no_store"
    valid_json "$STORE" || emit_err "invalid_store"
    local sum
    sum="$(sha256sum "$STORE" 2>/dev/null | cut -d' ' -f1)"
    jq -c --arg sum "$sum" --arg ts "$(iso_now)" '. + {checksum:$sum, exportedAt:$ts}' "$STORE" > "$path.$$.tmp" \
        && mv -f "$path.$$.tmp" "$path" || emit_err "export_failed"
    printf '{"ok":true,"path":"%s"}\n' "$path"
}

cmd_exportmd() {
    local dir="$1"
    [ -n "$dir" ] || emit_err "no_dir"
    dir="${dir#file://}"
    mkdir -p "$dir" 2>/dev/null || emit_err "mkdir_failed"
    [ -f "$STORE" ] || emit_err "no_store"
    valid_json "$STORE" || emit_err "invalid_store"

    local count=0 idx="$dir/index.md"
    : > "$idx"
    printf '# MemoKeel export\n\n_Exported %s_\n\n' "$(iso_now)" >> "$idx"

    local n total
    total="$(jq -r '.notes | length' "$STORE")"
    local i=0
    while [ "$i" -lt "$total" ]; do
        # resolve this note's tag names + a safe slug, then dump body
        local title slug fname
        title="$(jq -r --argjson i "$i" '.notes[$i].title // "Untitled"' "$STORE")"
        slug="$(printf '%s' "$title" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')"
        [ -n "$slug" ] || slug="note"
        local id
        id="$(jq -r --argjson i "$i" '.notes[$i].id // ""' "$STORE")"
        fname="$dir/${slug}-${id##*-}.md"

        jq -r --argjson i "$i" '
            .tags as $t
            | .notes[$i] as $n
            | "---",
              "title: " + ($n.title // ""),
              "tags: [" + ([ $n.tagIds[]? | ($t[.].name // .) ] | join(", ")) + "]",
              "color: " + ($n.color // ""),
              "pinned: " + (($n.pinned // false) | tostring),
              "created: " + ($n.createdAt // ""),
              "updated: " + ($n.updatedAt // ""),
              "---", "",
              "# " + ($n.title // "Untitled"), "",
              ($n.body // "")
        ' "$STORE" > "$fname"

        printf -- '- [%s](%s)\n' "$title" "$(basename "$fname")" >> "$idx"
        count=$((count + 1))
        i=$((i + 1))
    done
    printf '{"ok":true,"dir":"%s","notes":%d}\n' "$dir" "$count"
}

# Validate an external backup, snapshot the current state, and print the imported
# doc. QML decides merge-vs-replace (model.js) and then issues a normal save.
cmd_import() {
    local path="$1"
    [ -n "$path" ] || emit_err "no_path"
    path="${path#file://}"
    [ -f "$path" ] || emit_err "not_a_file"
    valid_json "$path" || emit_err "invalid_json"
    ensure_dirs

    local sv
    sv="$(jq -r '.schemaVersion // empty' "$path")"
    [ -n "$sv" ] || emit_err "not_a_backup"
    if [ "$sv" -gt "$SCHEMA_VERSION" ] 2>/dev/null; then
        emit_err "newer_schema"
    fi

    if [ -f "$STORE" ] && valid_json "$STORE"; then
        cp -f "$STORE" "$BACKUP_DIR/preimport-$(date -u +%Y%m%d-%H%M%S).json" 2>/dev/null
    fi
    # strip export-only annotations, normalize, and hand the clean doc to QML
    jq -c 'del(.checksum, .exportedAt)' "$path" | normalize
}

cmd="${1:-load}"
case "$cmd" in
    init)     cmd_load ;;
    load)     cmd_load ;;
    save)     cmd_save "${2:-}" ;;
    stat)     cmd_stat ;;
    attach)   cmd_attach "${2:-}" ;;
    gc)       cmd_gc "${2:-}" ;;
    backup)   cmd_backup ;;
    migrate)  out="$(cmd_load)"
              # strip the transport-only marker before persisting; a jq failure
              # (empty/invalid load) must leave store.json alone
              if printf '%s' "$out" | jq -ce 'del(.migratedFrom)' > "$STORE.$$.tmp" 2>/dev/null; then
                  mv -f "$STORE.$$.tmp" "$STORE"
              else
                  rm -f "$STORE.$$.tmp"
              fi
              printf '%s\n' "$out" ;;
    export)   cmd_export "${2:-}" ;;
    exportmd) cmd_exportmd "${2:-}" ;;
    import)   cmd_import "${2:-}" ;;
    *)        err "store.sh: unknown command '$cmd'"; emit_err "unknown_command" 1 ;;
esac
