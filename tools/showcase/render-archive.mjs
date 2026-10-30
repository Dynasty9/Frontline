// Render archived evidence through a reusable editorial stage; no image retouching.
import { createRequire } from "node:module";
import { readFile, mkdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const require = createRequire(path.join(root, "web/package.json"));
const { chromium } = require("playwright");
const catalog = JSON.parse(await readFile(path.join(root, "tools/showcase/catalog.json"), "utf8"));
const filter = process.argv[2];
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1600, height: 900 }, deviceScaleFactor: 1 });
  await page.goto(pathToFileURL(path.join(root, "tools/showcase/archive-stage.html")).href);
  for (const entry of catalog.entries.filter(e => e.output && (!filter || e.entry.includes(filter)))) {
    await page.evaluate(data => window.present(data), entry);
    const overflow = await page.evaluate(() => [...document.querySelectorAll("header,footer")].some(e => e.scrollHeight > e.clientHeight + 2));
    if (overflow) throw new Error(`Text overflow: ${entry.entry}`);
    await mkdir(path.dirname(path.join(root, entry.output)), { recursive: true });
    await page.screenshot({ path: path.join(root, entry.output), type: "jpeg", quality: 84 });
    console.log(entry.output);
  }
} finally { await browser.close(); }
