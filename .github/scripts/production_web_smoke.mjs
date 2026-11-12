// Check content as well as HTTP status: the SPA fallback can return HTML for
// missing viewer files, while a stale static-only deployment still looks online.
import assert from "node:assert/strict";

const origin =
  process.env.WEB_ORIGIN || "https://web-production-5a4c1.up.railway.app";
async function get(path) {
  const response = await fetch(new URL(path, origin), {
    signal: AbortSignal.timeout(30_000),
    headers: { "Cache-Control": "no-cache" },
  });
  assert.equal(response.status, 200, `${path}: HTTP ${response.status}`);
  return response;
}

const home = await get("/");
assert.match(await home.text(), /<div id="root"/);
// A bundle from an older build must be missing, not answered with the page:
// a tab opened before a deploy can then reload onto the new one.
const stale = await fetch(new URL("/assets/stale-build-check.js", origin), {
  signal: AbortSignal.timeout(30_000),
});
assert.equal(
  stale.status,
  404,
  `A missing bundle answers HTTP ${stale.status}`,
);
// Each page has its own card for links (scripts/prerender.mjs), an address
// with no page is a real 404, and a player's page (made as it's visited) isn't.
const manual = await (await get("/manual")).text();
assert.match(
  manual,
  /og:title" content="Field Manual/,
  "/manual has no card of its own",
);
const missing = await fetch(new URL("/no-such-page-check", origin), {
  signal: AbortSignal.timeout(30_000),
});
assert.equal(
  missing.status,
  404,
  `A missing page answers HTTP ${missing.status}`,
);
assert.match(
  await missing.text(),
  /<div id="root"/,
  "The 404 isn't the site's",
);
assert.match(await (await get("/player/smoke-check")).text(), /<div id="root"/);
assert.match(await (await get("/robots.txt")).text(), /^Sitemap: /m);
assert.match(await (await get("/sitemap.xml")).text(), /<urlset/);
const manifest = await (await get("/game/viewer.json")).json();
assert.equal(manifest.format, 1);
assert.ok(
  manifest.manual >= 3,
  "The production Field Manual viewer is out of date",
);
const wasm = await get("/game/index.wasm");
const reader = wasm.body.getReader();
let prefix = Buffer.alloc(0);
try {
  while (prefix.length < 4) {
    const { value, done } = await reader.read();
    assert.ok(!done, "Truncated WASM response");
    prefix = Buffer.concat([prefix, value]);
  }
  assert.equal(
    prefix.subarray(0, 4).toString("hex"),
    "0061736d",
    "Missing WASM binary",
  );
} finally {
  await reader.cancel();
}
console.log(
  "Production website, its pages, viewer manifest, and WASM are available.",
);
