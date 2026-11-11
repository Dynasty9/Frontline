import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { test } from "node:test";
import { loadCatalog } from "./catalog.mjs";

test("renderer combines legacy and independent records in deterministic order", async () => {
  const root = await mkdtemp(path.join(tmpdir(), "showcase-catalog-"));
  try {
    const folder = path.join(root, "tools/showcase");
    await mkdir(path.join(folder, "entries"), { recursive: true });
    await writeFile(path.join(folder, "catalog.json"), JSON.stringify({
      schema: 1, entries: [{ entry: "legacy" }], layout_capture: { preserved: true },
    }));
    assert.deepEqual((await loadCatalog(root)).entries, [{ entry: "legacy" }]);
    await writeFile(path.join(folder, "entries/z.json"), '{"entry":"z","output":"z.jpg"}');
    await writeFile(path.join(folder, "entries/a.json"), '{"entry":"a","sources":[]}');
    await writeFile(path.join(folder, "entries/README.md"), "Instructions, not a record");
    assert.deepEqual(await loadCatalog(root), {
      schema: 1,
      entries: [{ entry: "legacy" }, { entry: "a", sources: [] }, { entry: "z", output: "z.jpg" }],
      layout_capture: { preserved: true },
    });
    await writeFile(path.join(folder, "entries/bad.json"), "not JSON");
    await assert.rejects(loadCatalog(root), SyntaxError);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
