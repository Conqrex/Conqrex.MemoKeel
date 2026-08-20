<p align="center">
  <img src="package/contents/icons/memokeel-banner.svg" alt="MemoKeel" width="720">
</p>

<p align="center">
  <b>Every note and task. One Plasma keel.</b><br>
  A KDE Plasma 6 widget that keeps a dashboard, notes, to-dos, kanban,
  reminders, tags and global search in one panel popup — local-first, in a
  single JSON file you own, with no account and no sync service.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-3b82f6?style=flat-square" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/KDE-Plasma%206-1d99f3?style=flat-square&logo=kde&logoColor=white" alt="KDE Plasma 6">
  <img src="https://img.shields.io/badge/Made%20with-QML-41cd52?style=flat-square&logo=qt&logoColor=white" alt="QML">
</p>

<p align="center">
  <a href="#-install">Install</a> ·
  <a href="#-features">Features</a> ·
  <a href="#-keyboard-shortcuts">Shortcuts</a> ·
  <a href="#-quick-add-tokens">Quick-add</a> ·
  <a href="#-where-your-data-lives">Data</a> ·
  <a href="#-development">Development</a>
</p>

---

## ✨ Features

|     |     |
| --- | --- |
| 🏠 **Dashboard** | The default tab: at-a-glance panes for recent notes, open to-dos and what's overdue or due today, each addable in place — no need to switch tabs. |
| 📝 **Notes** | Markdown bodies (bold/italic/code/lists/links), inline `- [ ]` checklists, per-note neon colors, pin, archive, recoverable trash, Obsidian-style `[[wiki-links]]` with backlinks. |
| ✅ **To-Do** | Status cycling (To Do → In Progress → Done), priorities, due dates, tags, quick-add. |
| 📋 **Kanban** | Separate project boards in tabs, each with fit-to-width columns, WIP limits, positional drag & drop, a card editor, and per-column quick-add. Existing cards migrate into a default board. |
| ⏰ **Reminders** | Time-chip picker (In 1h · Tonight · Tomorrow · Custom calendar), repeats, native notifications, snooze, overdue badges. |
| 🔎 **Search** | Global fuzzy search across everything, toggled from the header (Ctrl+F) instead of a permanent bar. |
| 🏷️ **Tags** | Every tag as a usage-scaled cloud; click to filter, right-click to rename, recolour or delete. |
| 🖼 **Attachments** | Drag-drop images/files; content-addressed, deduplicated, reference-counted storage. |
| 🧊 **Conqrex dark look** | Banner-style navy-neon theme out of the box; one toggle to follow your system theme. |
| 🛟 **Data safety** | Atomic flock-serialized saves, rolling backups, crash-recovery journal, JSON/Markdown export, merge/replace import. |

Navigation is a top tab bar (Dashboard, Notes, To-Do, Kanban\*, Reminders,
Board\*, Search, Tags — \*optional, toggled in Settings). The panel icon
shows live badges for **overdue reminders** and **open to-dos**, and its
tooltip previews your next reminder.

## 📦 Install

### Arch / CachyOS (AUR)

```sh
yay -S memokeel
```

### From source

```sh
git clone https://github.com/Conqrex/Conqrex.MemoKeel.git
cd Conqrex.MemoKeel
./install.sh            # installs or upgrades, per-user (no sudo)
```

Right-click your desktop or panel → **Add Widgets** → search **MemoKeel**.

<details>
<summary>Reload Plasma after upgrading a local install</summary>

```sh
kquitapp6 plasmashell && kstart plasmashell
```

</details>

Package id: `com.conqrex.memokeel`

> **Upgrading from Quick Notes?** MemoKeel installs under a new package id
> (`com.conqrex.memokeel`, was `com.conqrex.quicknotes`), so it does not
> replace an existing Quick Notes applet in place — add it to your panel
> once. Your notes migrate automatically the first time MemoKeel runs: the
> old `~/.local/share/conqrex/quicknotes/` folder is copied into
> `~/.local/share/conqrex/memokeel/` and left in place as a backup, nothing
> is moved or deleted. Once MemoKeel is on your panel and your notes are
> there, remove the superseded applet yourself with:
> ```sh
> kpackagetool6 -t Plasma/Applet -r com.conqrex.quicknotes
> ```

## ⌨️ Keyboard shortcuts

Active while the popup (or desktop widget) is open:

| Shortcut | Action |
| --- | --- |
| `Ctrl+1` through `Ctrl+7` | Jump to the tab in that position (matches what's actually on screen, so it shifts if Kanban/Board is off) |
| | *With both Kanban and Board enabled there are eight tabs, and the eighth — **Tags** — has no Ctrl number; reach it by clicking, or turn Board off so Tags moves into `Ctrl+7`.* |
| `Ctrl+N` | Switch to Notes and focus the add field |
| `Ctrl+T` | Switch to To-Do and focus the add field |
| `Ctrl+K` | Switch to Kanban and focus the add field (only when Kanban is enabled) |
| `Ctrl+R` | Switch to Reminders and focus the add field |
| `Ctrl+F` | Toggle the search bar (on the tabs that filter: Notes, To-Do, Kanban, Reminders, Search) |
| `Escape` | Unwind one layer at a time — overlays, then the search text, then the search bar |

Search and the tag filter apply to Notes, To-Do, Kanban, Reminders and Search.
Dashboard, Board and Tags show their own unfiltered content, so the search bar
and the filter chips are hidden there; whatever you had set comes back when you
return. While the bar is collapsed a live query is shown as a removable chip
next to the title, so a filter is never applied invisibly.

## 🔎 Quick-add tokens

Type in an add bar (Dashboard panes, Notes, To-Do, Kanban):

```
buy milk #home !2 ^tomorrow
```

- `#tag` — add a tag (repeatable)
- `!1`–`!4` or `!low` `!med` `!high` `!urgent` — priority
- `^today` `^tomorrow` `^3h` `^2d` `^14:30` — due date

Tokens are optional power-user shortcuts; Reminders has a visual time picker.
(Reminders have no priority field, so a `!` token there is left in the text
instead of being applied.)

## 🗃 Where your data lives

Everything is one JSON document (plus an `attachments/` blob store) under:

```
~/.local/share/conqrex/memokeel/
├── store.json        # the single source of truth
├── attachments/      # content-addressed image/file blobs
├── backups/          # rolling + pre-migration + pre-import snapshots
└── journal/          # last-good copy for crash recovery
```

This is **outside the widget package**, so `kpackagetool6 -u` / reinstalls never
touch your notes. Saves are flock-serialized and atomic (write-temp + fsync +
rename) with a last-good journal, so an interrupted write can't corrupt your data.

Use the widget's **☰ (Data)** menu to **Export to JSON**, **Export notes to
Markdown**, **Import** (merge or replace), **Back up now**, **Clean up
attachments**, or **Open the data folder**. The **⋮ (More)** menu toggles
**Show archived items**, opens **Trash**, and opens **Settings**, where you
can point the widget at a different **Data directory**.

> **Reminders** fire only while plasmashell is running; when you open the widget
> it catches up on anything that came due while it was closed.

## 🛠️ Development

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
QT_FORCE_STDERR_LOGGING=1 plasmoidviewer -a ./package    # console.log on stderr
```

KDE installs a message handler that sends Qt/QML output to the journal, so
without `QT_FORCE_STDERR_LOGGING=1` your terminal stays empty (and
`QT_LOGGING_RULES="qml.debug=true"` on its own changes nothing — `console.log`
is already enabled, it is just being routed elsewhere). Read it from the
journal instead with `journalctl -f -o cat` if you prefer.

Or, after installing:

```sh
plasmawindowed com.conqrex.memokeel
```

## 🏛 Architecture

`main.qml` owns the entire in-memory document (`root.doc`). The views are dumb
renderers that call intent functions, which apply a **pure operation** from
`code/model.js`, reassign `root.doc` (firing bindings), and schedule a debounced
save. **`code/store.sh` is the only thing that touches the filesystem**, invoked
through a single `Plasma5Support.DataSource`. Markdown rendering HTML-escapes note
bodies before producing RichText, so content can't inject markup.

## 🛰️ Sibling projects

- [**OctoPulse**](https://github.com/Conqrex/Conqrex.OctoPulse) — every GitHub Actions run in one panel widget.
- [**Dockswain**](https://github.com/Conqrex/Conqrex.Dockswain) — Docker host management over SSH.
- [**CrewBeacon**](https://github.com/Conqrex/Conqrex.CrewBeacon) — AI quota, live coding agents, and usage history.

## ⚠️ Known issues

- **Two copies of the widget share one theme setting.** If you add MemoKeel
  twice to the same Plasma session, the *Follow system theme* switch is not
  per-instance: flipping it in one copy re-themes both. Each copy still keeps
  its own notes, board and reminders.

## 📄 License

MIT © S. Aydin Icen
