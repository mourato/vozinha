const handler = window.webkit?.messageHandlers?.vozinhaNotes;

function post(type, payload = {}) {
  handler?.postMessage({ type, payload });
}

let editorView = null;
let currentDocumentId = "";

function applyTheme(themeCSS) {
  let style = document.getElementById("vozinha-theme");
  if (!style) {
    style = document.createElement("style");
    style.id = "vozinha-theme";
    document.head.appendChild(style);
  }
  style.textContent = themeCSS || "";
}

function ensureEditor(initialText = "") {
  if (editorView) {
    return editorView;
  }

  const root = document.getElementById("editor-root");
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
  editorView = textarea;
  return editorView;
}

window.vozinhaNotesLoadNote = (payload) => {
  currentDocumentId = payload.documentId || "";
  document.documentElement.style.setProperty("--notes-font-size", `${payload.textSize || 15}px`);
  applyTheme(payload.themeCSS || "");
  const editor = ensureEditor(payload.markdown || "");
  editor.value = payload.markdown || "";
  post("contentHeight", { height: document.getElementById("editor-root").scrollHeight });
};

window.vozinhaNotesApplySettings = (payload) => {
  document.documentElement.style.setProperty("--notes-font-size", `${payload.textSize || 15}px`);
  applyTheme(payload.themeCSS || "");
};

post("ready");
