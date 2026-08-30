# Plan 127c: Meeting notes editor polish

**Status:** IMPLEMENTED  
**Depends on:** Plan 127b (CM6 live preview scaffold)

## Objective

Close the remaining Pane writing-feel and build-pipeline gaps: full live-preview
constructs, user theme CSS from Application Support, and an out-of-band editor
bundle build (`make build-meeting-notes-editor`).

## Slices

### Slice 0 — Full live preview port (L)

- [x] Port Pane `live-preview.ts` constructs (tasks, lists, gaps, fences, blank lines)
- [x] Port Pane `markdown.css` + editor tokens subset
- [x] Rebuild bundle; `addToHistory: false` on programmatic note load

### Slice 1 — Theme loader (M)

- [x] `MeetingNotesEditorThemeResolver` reads `Application Support/.../MeetingNotes/Themes/*.css`
- [x] Settings theme picker; `meetingNotesEditorTheme` stores theme basename
- [x] WebView receives resolved CSS via bridge

### Slice 2 — Editor bundle build (S)

- [x] `scripts/build-meeting-notes-editor.sh` rebuilds bundle when `Editor/` changed
- [x] Document `make build-meeting-notes-editor`; Xcode uses committed `dist/` only

## Out of scope

- `⌘P` / `⌘K`, pin, history (Plan 127 follow-up)
- Retiring `MarkdownEngine` from dashboard editors

## Acceptance

1. Task lists, bullet glyphs, block gaps, and fence collapse match Pane behaviour.
2. Dropping `dark.css` into Themes folder and selecting it changes editor colours.
3. App builds use the committed editor bundle; `make build-meeting-notes-editor` refreshes it after `Editor/` edits.
