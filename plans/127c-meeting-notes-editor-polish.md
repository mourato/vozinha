# Plan 127c: Meeting notes editor polish

**Status:** IMPLEMENTED  
**Depends on:** Plan 127b (CM6 live preview scaffold)

## Objective

Close the remaining Pane writing-feel and build-pipeline gaps: full live-preview
constructs, user theme CSS from Application Support, and Xcode editor bundle build.

## Slices

### Slice 0 — Full live preview port (L)

- [x] Port Pane `live-preview.ts` constructs (tasks, lists, gaps, fences, blank lines)
- [x] Port Pane `markdown.css` + editor tokens subset
- [x] Rebuild bundle; `addToHistory: false` on programmatic note load

### Slice 1 — Theme loader (M)

- [x] `MeetingNotesEditorThemeResolver` reads `Application Support/.../MeetingNotes/Themes/*.css`
- [x] Settings theme picker; `meetingNotesEditorTheme` stores theme basename
- [x] WebView receives resolved CSS via bridge

### Slice 2 — Xcode build phase (S)

- [x] Run `scripts/build-meeting-notes-editor.sh` before app compile when `npm` available
- [x] Document `make build-meeting-notes-editor` fallback

## Out of scope

- `⌘P` / `⌘K`, pin, history (Plan 127 follow-up)
- Retiring `MarkdownEngine` from dashboard editors

## Acceptance

1. Task lists, bullet glyphs, block gaps, and fence collapse match Pane behaviour.
2. Dropping `dark.css` into Themes folder and selecting it changes editor colours.
3. Xcode build runs editor bundle script when npm is present.
