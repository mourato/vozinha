export {};

declare global {
  interface Window {
    webkit?: {
      messageHandlers?: {
        vozinhaNotes?: { postMessage(message: unknown): void };
      };
    };
    vozinhaNotesLoadNote: (payload: {
      documentId?: string;
      markdown?: string;
      caretOffset?: number | null;
      textSize?: number;
      themeCSS?: string;
    }) => void;
    vozinhaNotesApplySettings: (payload: {
      textSize?: number;
      themeCSS?: string;
    }) => void;
  }
}
