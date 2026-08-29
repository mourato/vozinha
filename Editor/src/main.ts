const handler = window.webkit?.messageHandlers?.vozinhaNotes;

function post(type: string, payload: Record<string, unknown> = {}) {
  handler?.postMessage({ type, payload });
}

let editor: HTMLTextAreaElement | null = null;

function applyTheme(themeCSS: string) {
  let style = document.getElementById("vozinha-theme") as HTMLStyleElement | null;
  if (!style) {
    style = document.createElement("style");
    style.id = "vozinha-theme";
    document.head.appendChild(style);
  }
  style.textContent = themeCSS || "";
}

function ensureEditor(initialText = ""): HTMLTextAreaElement {
  if (editor) {
    return editor;
  }

  const root = document.getElementById("editor-root");
  if (!root) {
    throw new Error("Missing #editor-root");
  }

  const textarea = document.createElement("textarea");
  textarea.value = initialText;
  textarea.style.width = "100%";
  textarea.style.height = "100%";
  textarea.style.border = "0";
  textarea.style.resize = "none";
  textarea.style.background = "transparent";
  textarea.style.color = "CanvasText";
  textarea.style.font = "inherit";
  textarea.style.padding = "12px";
  textarea.addEventListener("input", () => {
    post("edited", { markdown: textarea.value });
    post("contentHeight", { height: root.scrollHeight });
  });
  root.replaceChildren(textarea);
  editor = textarea;
  return editor;
}

declare global {
  interface Window {
    vozinhaNotesLoadNote: (payload: {
      documentId?: string;
      markdown?: string;
      textSize?: number;
      themeCSS?: string;
    }) => void;
    vozinhaNotesApplySettings: (payload: {
      textSize?: number;
      themeCSS?: string;
    }) => void;
  }
}

window.vozinhaNotesLoadNote = (payload) => {
  document.documentElement.style.setProperty("--notes-font-size", `${payload.textSize || 15}px`);
  applyTheme(payload.themeCSS || "");
  const instance = ensureEditor(payload.markdown || "");
  instance.value = payload.markdown || "";
  const root = document.getElementById("editor-root");
  post("contentHeight", { height: root?.scrollHeight ?? 0 });
};

window.vozinhaNotesApplySettings = (payload) => {
  document.documentElement.style.setProperty("--notes-font-size", `${payload.textSize || 15}px`);
  applyTheme(payload.themeCSS || "");
};

post("ready");
