import { build } from "esbuild";
import { cpSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const dist = join(root, "dist");
mkdirSync(dist, { recursive: true });

await build({
  entryPoints: [join(root, "src/main.ts")],
  outfile: join(dist, "main.js"),
  bundle: true,
  format: "esm",
  target: "es2022",
  sourcemap: false,
});

for (const asset of ["index.html", "meeting-notes.css"]) {
  cpSync(join(root, "src", asset), join(dist, asset));
}

console.log("Built meeting notes editor bundle");
