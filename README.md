# Conqrex Quick Notes

A professional, all-in-one quick-noting widget for **KDE Plasma 6**, in the same
neon-glass style as the Conqrex gauge widget. One widget, several modes:

- **📝 Notes** — Markdown bodies (bold/italic/code/lists/links), inline checklists
  (`- [ ]`), per-note neon colors, pin to top, archive, and a recoverable trash.
  Obsidian-style `[[wiki-links]]` with a backlinks panel.
- **✅ To-Do** — status cycling (To Do → In Progress → Done), priorities, due dates,
  tags and quick-add.
- **📋 Kanban** — columns with WIP limits, drag a card between columns (or use its
  menu), priorities, due dates, tags and per-column quick-add.
- **⏰ Reminders** — due date + repeat (daily/weekly/monthly), **native desktop
  notifications** while the panel runs, snooze/acknowledge, and overdue badges.
- **🔎 Search** — global fuzzy search across notes, to-dos, cards and reminders,
  plus a tag cloud. **Tags** are rename-safe and filter every mode at once.
- **🖼 Attachments** — drag-drop or pick image/files; stored content-addressed
  (deduplicated, reference-counted) under your data dir.

The panel icon shows live badges for **overdue reminders** and **open to-dos**.

## Quick-add tokens

Type in the always-visible add bar:

```
buy milk #home !2 ^tomorrow
```

- `#tag` — add a tag (repeatable)
- `!1`–`!4` or `!low` `!med` `!high` `!urgent` — priority
- `^today` `^tomorrow` `^3h` `^2d` `^14:30` — due date

## Install

```sh
./install.sh            # installs or upgrades, per-user (no sudo)
```

Then right-click your desktop or panel → **Add Widgets** → search **Conqrex Quick Notes**.

After changing the code, reload the shell to pick it up:

```sh
kquitapp6 plasmashell && kstart plasmashell
```

## Where your data lives

Everything is one JSON document (plus an `attachments/` blob store) under:

```
~/.local/share/conqrex/quicknotes/
├── store.json        # the single source of truth
├── attachments/      # content-addressed image/file blobs
├── backups/          # rolling + pre-migration + pre-import snapshots
└── journal/          # last-good copy for crash recovery
```

This is **outside the widget package**, so `kpackagetool6 -u` / reinstalls never
touch your notes. Saves are flock-serialized and atomic (write-temp + fsync +
rename) with a last-good journal, so an interrupted write can't corrupt your data.

Use the widget's **⋮ (Data)** menu to **Export to JSON**, **Export notes to
Markdown**, **Import** (merge or replace), **Back up now**, **Clean up unused
attachments**, or **Open the data folder**. You can point the widget at a
different folder in **Settings → Data directory**.

> **Reminders** fire only while plasmashell is running; when you open the widget
> it catches up on anything that came due while it was closed.

## Develop / preview

The data layer is a plain shell broker you can drive directly:

```sh
S=package/contents/code/store.sh
QN_DATA_DIR=/tmp/qn bash "$S" init   | jq .
QN_DATA_DIR=/tmp/qn bash "$S" load   | jq .
QN_DATA_DIR=/tmp/qn bash "$S" stat   | jq .
```

Live-preview the UI without installing (needs `plasma-sdk`):

```sh
sudo pacman -S plasma-sdk
plasmoidviewer -a ./package -f planar     -l floating    # desktop
plasmoidviewer -a ./package -f horizontal -l topedge     # panel
QT_LOGGING_RULES="qml.debug=true" plasmoidviewer -a ./package   # console.log
```

Or, after installing:

```sh
plasmawindowed com.conqrex.quicknotes
```

## Architecture

`main.qml` owns the entire in-memory document (`root.doc`). The views are dumb
renderers that call intent functions, which apply a **pure operation** from
`code/model.js`, reassign `root.doc` (firing bindings), and schedule a debounced
save. **`code/store.sh` is the only thing that touches the filesystem**, invoked
through a single `Plasma5Support.DataSource`. Markdown rendering HTML-escapes note
bodies before producing RichText, so content can't inject markup.

## License

MIT © S. Aydin Icen
