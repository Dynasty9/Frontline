import { readFile, readdir } from "node:fs/promises";
import path from "node:path";

export async function loadCatalog(root) {
  const folder = path.join(root, "tools/showcase");
  const catalog = JSON.parse(await readFile(path.join(folder, "catalog.json"), "utf8"));
  for (const name of (await readdir(path.join(folder, "entries"))).filter(name => name.endsWith(".json")).sort()) {
    catalog.entries.push(JSON.parse(await readFile(path.join(folder, "entries", name), "utf8")));
  }
  return catalog;
}
