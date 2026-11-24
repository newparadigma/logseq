// Collects the files published pages load from /static/ instead of CDNs into
// worker/dist/static, where the Node server (logseq.publish.node.server) serves them.
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const modules = path.join(root, "node_modules");
const appCss = path.join(root, "..", "..", "resources", "css");
const out = path.join(root, "worker", "dist", "static");

const copy = (from, to) => {
  if (!fs.existsSync(from)) {
    throw new Error(`Missing ${from}: run pnpm install`);
  }
  fs.cpSync(from, path.join(out, to), { recursive: true });
};

fs.rmSync(out, { recursive: true, force: true });

// Tabler icon fonts, the same files the app uses
copy(path.join(appCss, "tabler-icons.min.css"), "tabler-icons.min.css");
copy(path.join(appCss, "tabler-extension.css"), "tabler-extension.css");
copy(path.join(appCss, "fonts"), "fonts");

copy(path.join(modules, "inter-ui", "variable"), "inter");

copy(path.join(modules, "katex", "dist", "katex.mjs"), "katex/katex.mjs");
copy(path.join(modules, "katex", "dist", "katex.min.css"), "katex/katex.min.css");
copy(path.join(modules, "katex", "dist", "fonts"), "katex/fonts");

copy(path.join(modules, "codemirror", "lib", "codemirror.js"), "codemirror/codemirror.js");
copy(path.join(modules, "codemirror", "lib", "codemirror.css"), "codemirror/codemirror.css");
copy(path.join(modules, "codemirror", "mode", "meta.js"), "codemirror/mode/meta.js");
// Keep in step with codeMirrorModes in src/logseq/publish/publish.js
for (const mode of ["xml", "javascript", "css", "htmlmixed", "python", "markdown", "sql", "clojure"]) {
  copy(path.join(modules, "codemirror", "mode", mode, `${mode}.js`), `codemirror/mode/${mode}.js`);
}

copy(path.join(modules, "@emoji-mart", "data", "sets", "15", "native.json"), "emoji-native.json");

console.log(`Static files written to ${out}`);
