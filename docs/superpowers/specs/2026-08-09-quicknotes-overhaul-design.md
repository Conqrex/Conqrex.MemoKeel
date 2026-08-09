# Quick Notes Overhaul — Design

Date: 2026-08-09
Status: approved by user (sections 1–5)

Scope: theme system, Kanban rewrite, Reminders UX, view/nav/compact polish, README rewrite. Approach: theme foundation first, everything else on top.

## 1. Theme system

New QML singleton `package/contents/ui/theme/QN.qml` (registered via `qmldir` in the same directory) holding all design tokens:

- **Surfaces**: `bg` `#0a0e1a`, `surface` `#111827`, `surfaceHi` (hover), `inputBg`, `border` (white @ 8% alpha), `borderHi`.
- **Text tiers**: `text`, `textDim`, `textFaint`.
- **Accents**: reuse `code/theme.js` neon palette (cyan/sky/violet/lime/amber/rose/slate) — it already matches the banner.
- **Effects/metrics**: `glow(color)` shadow-parameter helper, radius scale (6/10/14), spacing scale.
- **Mode switch**: config bool `followSystemTheme` (default **off** = banner dark look). When on, surface/text tokens map to `Kirigami.Theme.*`; neon accents remain. Views read only `QN.*` tokens, never raw Kirigami colors directly.

`code/theme.js` stays as the pure-JS accent lookup for the model layer (no Qt dependency). `components/NeonCard.qml` upgraded to tokens + subtle gradient border per the banner card style.

Settings → Appearance gains a "Follow system theme" checkbox (new key in `config/main.xml`).

## 2. Kanban rewrite

### Layout — fit to width
- `columnWidth = max(minCol, availableWidth / columnCount)`, `minCol ≈ 10 gridUnits`. A 3-column board never scrolls horizontally; scroll appears only with many columns or a very narrow widget.
- Column structure: header, scrollable card list (fills), **quick-add pinned at bottom, never clipped** (fixes current bug where the RowLayout height binding lets the TextField fall below the viewport).
- "Add column" becomes a slim ghost "+" column at the row end.

### Mechanics
- Drag between columns shows a drop-indicator line at the insert position; card is inserted there (use the existing `moveCard` order parameter instead of passing `null`).
- Reordering within a column uses the same drag path.
- Card click opens a card editor sheet: title, description, priority, due, tags, color, column.
- Column reordering via header menu "Move left / Move right" first; header-grip drag only if trivial to add.
- WIP over-limit: column header glows rose; count badge pulses.

## 3. Reminders UX

Add row in Reminders view (token placeholder removed):
- Text field "Remind me to…".
- Chip row: `In 1h` (preselected default) · `In 3h` · `Tonight 20:00` · `Tomorrow 9:00` · `Custom…`.
- `Custom…` popup: month-grid calendar + time field/tumbler + repeat dropdown (None/Daily/Weekly/Monthly).
- Selected time shows as a removable pill; Add always enabled.
- `^token` syntax still parsed when typed, but never advertised in placeholders or empty states.
- Editing an existing reminder's due date opens the same Custom popup (replaces the current 3-item menu).
- Empty-state hint rewritten: "Pick a time chip and add your first reminder."

## 4. Views, nav rail, compact panel

- **Nav rail**: icon-only with tooltips when narrow, icon+label when wide; active item gets neon pill + glow bar; badge dots (overdue count on Reminders, open count on To-Do).
- **All views**: NeonCard token pass; consistent section headers (colored dot + label + count); consistent empty states; quick-add bar restyled (dark input, glowing Add button).
- **Compact panel icon**: keep badges; add hover tooltip preview (next reminder + open to-do count); enforce sane popup minimum size so Kanban is never squeezed.

## 5. README

OctoPulse structure applied to existing content (reformat, don't discard):
- Centered banner image + tagline + badge row (MIT, Plasma 6, QML, release, stars).
- Anchor nav line (Install · Features · Quick-add · Data · Development).
- Features as 2-column emoji table.
- Install: from source + AUR placeholder, collapsible plasma-reload details.
- Keep data-safety, quick-add tokens, dev/preview, architecture sections.
- Sibling projects: OctoPulse, Dockswain.

The banner PNG will be replaced later by the user; README references it by its current path.

## Error handling / data layer
- No `store.sh` or schema changes. Card ordering uses the existing `moveCard` order parameter.
- Theme mode is pure presentation; toggling never touches the document.

## Testing
- `plasmoidviewer -a ./package -f planar -l floating` after each phase; also `-f horizontal -l topedge` for panel/compact checks.
- Manual checks: 3-column board fits without horizontal scroll at default popup size; quick-add visible in every column; drop indicator positions correctly; reminder chips produce expected ISO due times; system-theme toggle flips surfaces live.

## Build order
1. Theme singleton + config key + NeonCard.
2. Kanban layout + mechanics.
3. Reminders add row + custom popup.
4. Nav rail, view polish, compact panel.
5. README.
