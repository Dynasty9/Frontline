// Local synthetic fixture only: no production endpoints or credentials.
import assert from "node:assert/strict";
import { createServer as http } from "node:http";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { BucketStore, Replays } from "../../matchmaker/src/replays.js";
import { createServer } from "../../matchmaker/src/server.js";
const root = process.argv[3];
if (!root || !["ingest", "serve"].includes(process.argv[2]))
  throw new Error(
    "Usage: node tools/showcase/replay_storage_fixture.mjs ingest|serve SYNTHETIC_FIXTURE_DIRECTORY",
  );
const key = "fixture-only-not-a-secret";
await mkdir(root, { recursive: true });
let objects = {};
try {
  objects = JSON.parse(await readFile(`${root}/objects.json`, "utf8"));
} catch (e) {
  if (e.code !== "ENOENT") throw e;
}
const storage = http(async (req, res) => {
  let body = "";
  for await (const p of req) body += p;
  const answer = (status, value) => {
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(typeof value === "string" ? value : JSON.stringify(value));
  };
  if (
    req.headers.apikey !== key ||
    req.headers.authorization !== `Bearer ${key}`
  )
    return answer(403, { error: "fixture key required" });
  const path = new URL(req.url, "http://localhost").pathname;
  const match = path.match(/^\/storage\/v1\/object\/replays\/(.+)$/);
  if (path === "/storage/v1/object/list/replays")
    return answer(
      200,
      [...new Set(Object.keys(objects).map((p) => p.split("/")[0]))].map(
        (name) => ({ name, id: null }),
      ),
    );
  if (match && req.method === "POST") {
    if (objects[match[1]] && req.headers["x-upsert"] !== "true")
      return answer(409, { error: "duplicate" });
    objects[match[1]] = body;
    await writeFile(`${root}/objects.json`, JSON.stringify(objects));
    return answer(200, { Key: match[1] });
  }
  if (match && req.method === "GET")
    return objects[match[1]]
      ? answer(200, objects[match[1]])
      : answer(400, { statusCode: "404", message: "Object not found" });
  if (path === "/storage/v1/object/replays" && req.method === "DELETE") {
    for (const p of JSON.parse(body).prefixes) delete objects[p];
    await writeFile(`${root}/objects.json`, JSON.stringify(objects));
    return answer(200, []);
  }
  answer(404, {});
});
await new Promise((resolve) => storage.listen(0, "127.0.0.1", resolve));
const replays = new Replays({
  store: new BucketStore({
    url: `http://127.0.0.1:${storage.address().port}`,
    key,
    bucket: "replays",
  }),
});
await replays.ready();
const manifest = JSON.parse(
  await readFile(`${root}/synthetic-attack/index.json`, "utf8"),
);
let id;
if (process.argv[2] === "ingest") {
  const created = await replays.create(
    {
      id: "fixture-attack",
      name: "Synthetic attack seed 3",
      host: "Test fixture",
      inGame: true,
      locked: false,
    },
    manifest,
  );
  id = created.id;
  for (const part of manifest.chunks)
    await replays.append(
      id,
      created.token,
      JSON.parse(
        await readFile(
          `${root}/synthetic-attack/${part.sequence}.json`,
          "utf8",
        ),
      ),
    );
  await writeFile(`${root}/replay-id.txt`, id);
  console.log(
    `INGESTED ${id} ${manifest.chunks.length} authentic synthetic chunks`,
  );
  await new Promise((resolve) => storage.close(resolve));
} else {
  id = (await readFile(`${root}/replay-id.txt`, "utf8")).trim();
  for (const part of manifest.chunks)
    assert.deepEqual(
      await replays.chunk(id, String(part.sequence)),
      JSON.parse(
        await readFile(
          `${root}/synthetic-attack/${part.sequence}.json`,
          "utf8",
        ),
      ),
    );
  assert.equal(replays.view(await replays.get(id)).status, "complete");
  const server = createServer({ env: {}, auth: null, replays, log: () => {} });
  await new Promise((resolve) => server.listen(18974, "127.0.0.1", resolve));
  console.log(
    `RESTART VERIFIED: ${manifest.chunks.length} exact payloads; http://127.0.0.1:18974/replays/${id}`,
  );
  await writeFile(
    `${root}/replay-url.txt`,
    `http://127.0.0.1:18974/replays/${id}`,
  );
}
