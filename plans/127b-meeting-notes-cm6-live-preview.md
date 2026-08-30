# Plan 127b: CodeMirror 6 live preview editor

**Status:** IMPLEMENTED  
**Depends on:** Plan 127 (pane chrome + bridge)

## Objective

Replace the textarea scaffold with CodeMirror 6 live preview in the meeting notes
WebKit editor path — the main writing-feel gap vs Pane.

## Delivered

- `@codemirror/*` bundle with `live-preview.ts` (caret line raw, other lines rendered)
- Tokens + markdown CSS subset adapted from Pane
- Content-height reporting drives pane auto-size
- `make build-meeting-notes-editor` / `scripts/build-meeting-notes-editor.sh`

## Still not Pane 1:1

- No task checkboxes, bullet glyphs, ordered-list renumbering, find bar, format bar
- No `⌘P` / `⌘K`, pin, history, user theme folder loader
- Live preview is a **minimal** port (~120 LOC vs Pane ~800 LOC)

## Follow-up (127c)

- Port remaining live-preview constructs from Pane (tasks, lists, gaps, fences)
- Load theme CSS from Application Support `MeetingNotes/Themes/*.css`
- Editor bundle built via `make build-meeting-notes-editor` (outside Xcode)
