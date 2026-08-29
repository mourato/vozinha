/*
 * Minimal live preview: rendered markdown everywhere except the caret line.
 * ponytail: subset of Pane's live-preview.ts — no task widgets, list glyphs, or text constructs.
 * Upgrade path: port remaining constructs from Pane when cursor stability is proven here.
 */

import { syntaxTree } from "@codemirror/language";
import { RangeSetBuilder } from "@codemirror/state";
import {
  Decoration,
  type DecorationSet,
  EditorView,
  ViewPlugin,
  type ViewUpdate,
} from "@codemirror/view";

const hide = Decoration.replace({});

const BLOCK_LINE: Record<string, string> = {
  ATXHeading1: "notes-line-h1",
  ATXHeading2: "notes-line-h2",
  ATXHeading3: "notes-line-h3",
  ATXHeading4: "notes-line-h3",
  ATXHeading5: "notes-line-h3",
  ATXHeading6: "notes-line-h3",
  SetextHeading1: "notes-line-h1",
  SetextHeading2: "notes-line-h2",
  FencedCode: "notes-line-code",
  CodeBlock: "notes-line-code",
  Blockquote: "notes-line-quote",
};

const INLINE_STYLE: Record<string, string> = {
  StrongEmphasis: "notes-strong",
  Emphasis: "notes-em",
  Strikethrough: "notes-strike",
  InlineCode: "notes-code",
  Link: "notes-link",
};

const MARKER_NODES = new Set([
  "HeaderMark",
  "EmphasisMark",
  "StrikethroughMark",
  "CodeMark",
  "QuoteMark",
  "LinkMark",
  "URL",
  "CodeInfo",
]);

function activeLineNumber(view: EditorView): number {
  return view.state.doc.lineAt(view.state.selection.main.head).number;
}

function buildDecorations(view: EditorView): DecorationSet {
  const builder = new RangeSetBuilder<Decoration>();
  const activeLine = activeLineNumber(view);
  const decoratedLines = new Set<number>();

  for (const { from, to } of view.visibleRanges) {
    syntaxTree(view.state).iterate({
      from,
      to,
      enter(node) {
        const line = view.state.doc.lineAt(node.from).number;
        const onActiveLine = line === activeLine;

        if (MARKER_NODES.has(node.name)) {
          if (!onActiveLine) {
            builder.add(node.from, node.to, hide);
          }
          return;
        }

        if (onActiveLine) {
          return;
        }

        const blockClass = BLOCK_LINE[node.name];
        if (blockClass && !decoratedLines.has(line)) {
          decoratedLines.add(line);
          const lineStart = view.state.doc.lineAt(node.from).from;
          builder.add(lineStart, lineStart, Decoration.line({ class: blockClass }));
        }

        const inlineClass = INLINE_STYLE[node.name];
        if (inlineClass) {
          builder.add(node.from, node.to, Decoration.mark({ class: inlineClass }));
        }
      },
    });
  }

  return builder.finish();
}

export function livePreview() {
  return ViewPlugin.fromClass(
    class {
      decorations: DecorationSet;

      constructor(view: EditorView) {
        this.decorations = buildDecorations(view);
      }

      update(update: ViewUpdate) {
        if (update.docChanged || update.selectionSet || update.viewportChanged) {
          this.decorations = buildDecorations(update.view);
        }
      }
    },
    { decorations: (plugin) => plugin.decorations },
  );
}
