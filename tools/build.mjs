// Bundles src/ into a single self-contained dist/index.html (no external assets).
// Usage: node tools/build.mjs
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const files = JSON.parse(readFileSync(join(root, 'tools/files.json'), 'utf8'));
const css = readFileSync(join(root, 'src/styles.css'), 'utf8');
const js = files.map(f => `/* ---- ${f} ---- */\n` + readFileSync(join(root, 'src', f), 'utf8')).join('\n');
let html = readFileSync(join(root, 'src/index.html'), 'utf8');
html = html.replace('<link rel="stylesheet" href="styles.css">', `<style>\n${css}\n</style>`);
html = html.replace('<!--SCRIPTS-->', () => `<script>\n${js.replace(/<\/script/g, '<\\/script')}\n</script>`);
mkdirSync(join(root, 'dist'), { recursive: true });
writeFileSync(join(root, 'dist/index.html'), html);
// dev page loading individual modules
const dev = readFileSync(join(root, 'src/index.html'), 'utf8').replace('<!--SCRIPTS-->', files.map(f => `<script src="${f}"></script>`).join('\n'));
writeFileSync(join(root, 'src/dev.html'), dev);
console.log(`Built dist/index.html (${(html.length / 1024).toFixed(0)} KB, ${files.length} modules)`);
