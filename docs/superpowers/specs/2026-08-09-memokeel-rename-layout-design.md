# MemoKeel Rename + Layout Design

Date: 2026-08-09
Status: approved by user

Follows the completed overhaul (`2026-08-09-quicknotes-overhaul-design.md`). Reference: the MemoKeel banner supplied by the owner. **The theme is unchanged** — the `T.QN` token singleton and the `code/theme.js` neon palette are shared across all Conqrex widgets and must not drift. This pass is naming, placement and two new views.

## 1. Rename with data migration

- Package id `com.conqrex.quicknotes` → `com.conqrex.memokeel`; `KPlugin.Name` → `MemoKeel`; icon file `icons/com.conqrex.quicknotes.svg` → `icons/com.conqrex.memokeel.svg`, and every `source:`/`fallback:` reference follows.
- Data directory `~/.local/share/conqrex/quicknotes/` → `~/.local/share/conqrex/memokeel/`.
- **Migration** lives in `store.sh init`: when the new dir has no `store.json` and the legacy dir does, copy `store.json`, `attachments/`, `backups/` and `journal/` across, then proceed normally. The legacy directory is never modified or deleted. The copy is guarded by the same flock as other writes, is idempotent, and reports migration in `init`'s JSON output so the UI can toast it once.
- `QN_DATA_DIR` override keeps working and disables migration (an explicit path is authoritative).
- `install.sh` installs the new id and prints how to remove the old applet (`kpackagetool6 -t Plasma/Applet -r com.conqrex.quicknotes`). It never removes it automatically. Plasma treats the new id as a different widget, so the user re-adds MemoKeel to the panel once.
- Dead code removed, not renamed: `ui/index.js`, `ui/QuickNotesApp.js`, `ui/QuickNotesReminderIntegration.js`, `ui/ReminderUI.js`, `ui/ReminderManager.js`, `ui/reminders/ReminderForm.js`. Verified as a closed island — `index.js` is imported by nothing in the running app.
- Notification app-name and any user-visible "Quick Notes" string become "MemoKeel".

## 2. Top tab bar replaces the nav rail

New `ui/TabBar.qml`; `ui/NavRail.qml` is deleted along with the `sidebarCollapsed` config key.

- Tabs, in order: Dashboard, Notes, To-Do, Kanban, Reminders, Search, Tags. Kanban still honours `enableKanban`; the legacy `enableBoard`/`BoardView` stays as-is behind its existing default-off flag.
- Active tab: accent pill and glow, matching the rail's current active treatment so the family look is preserved.
- Count badges ride on the tabs: overdue on Reminders, open to-dos on To-Do.
- Responsive: labels hide below ~26 gridUnits of available width, leaving icons with tooltips; the strip scrolls horizontally if even icons overflow.
- `lastMode` gains `dashboard` and `tags`; default becomes `dashboard`.
- Kanban reclaims the rail's 7 gridUnits, which is the width it was short of.

## 3. Header, footer, shortcuts

- Header: hamburger (data menu) · icon + "MemoKeel" · spacer · overdue bell badge · open-todo badge · search toggle · ⋮ menu. The existing tag-filter chip stays.
- Search collapses into the toggle rather than always holding a row; toggling reveals the existing `SearchBar` and focuses it. The Search tab is unaffected.
- Footer: item count, archive and trash buttons on the left; last-saved time and an Open data folder button on the right.
- Shortcuts (Ctrl, not ⌘ — this is Linux): Ctrl+N / Ctrl+T / Ctrl+K focus the note / to-do / card add field, switching tabs if needed; Ctrl+F toggles search; Ctrl+1…7 select tabs; Escape closes any open overlay. Each add field renders its hint (e.g. `Ctrl+N`) right-aligned inside the field.

## 4. Dashboard mode

New `ui/DashboardView.qml`, the default tab.

- Three panes side by side: **Notes** (most recent, inline add), **To-Do** (grouped by status, inline add), **Due Today / Overdue** (two sections, overdue first with the negative accent).
- Each pane: header with title, count, and its own add row; the pane body scrolls independently.
- Below ~34 gridUnits the panes stack vertically inside one scroll area.
- Clicking a pane's header jumps to that mode's full tab.
- No mini-Kanban: three columns inside a third of a ~600px popup is unreadable. Kanban keeps its own full-width tab.

## 5. Tags mode

New `ui/TagsView.qml`.

- Tag cloud, chip size scaled by usage count across notes, todos, cards and reminders.
- Per-tag context actions: rename, recolour (existing `ColorPicker`), delete. All already exist as controller intents (`renameTag`, `setTagColor`, `deleteTag`).
- Clicking a tag sets the global tag filter and switches to Search.
- Empty state when no tags exist.

## 6. README and assets

- README title, badges, feature table, install block, package id and data paths updated to MemoKeel; the new banner replaces `assets/quick-notes-banner.png` (owner supplies the file; the README references `assets/memokeel-banner.png`).
- A short upgrade note: MemoKeel is a new package id, so add it to your panel once, and your notes migrate automatically on first run with the old folder kept as a backup.

## Non-goals

- No change to `T.QN`, `code/theme.js`, the neon palette, or the on-disk document schema.
- No pixel-copy of the banner; it is 1983px wide and a Plasma popup is roughly 600.

## Testing

No test framework exists. Per task: Qt6 `qmllint` clean on touched files, a `plasmoidviewer` load in planar and panel form factors, and headless probes for logic (migration behaviour, tag counting, responsive breakpoints). Migration additionally gets a real shell test against scratch directories under `/tmp` covering: fresh install, legacy data present, both present, `QN_DATA_DIR` override, and a re-run proving idempotence.

## Build order

1. Rename + data migration + dead-code removal.
2. TabBar replacing NavRail, header/footer chrome, shortcuts.
3. Dashboard mode.
4. Tags mode.
5. README and assets.
