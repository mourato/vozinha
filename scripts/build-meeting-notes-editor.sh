#!/usr/bin/env bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
EDITOR_DIR="$ROOT/Editor"
OUTPUT_DIR="$ROOT/Packages/MeetingAssistantCore/Sources/UI/Resources/MeetingNotesEditor/dist"

if [[ ! -d "$EDITOR_DIR" ]]; then
  echo "Editor/ package not found; using committed dist bundle." >&2
  exit 0
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found; using committed MeetingNotesEditor dist bundle." >&2
  exit 0
fi

mkdir -p "$OUTPUT_DIR"
pushd "$EDITOR_DIR" >/dev/null
npm install
npm run build
popd >/dev/null

rsync -a --delete "$EDITOR_DIR/dist/" "$OUTPUT_DIR/"
echo "Meeting notes editor bundle copied to $OUTPUT_DIR"
