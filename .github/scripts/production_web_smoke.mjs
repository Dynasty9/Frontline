// Check content as well as HTTP status: the SPA fallback can return HTML for
// missing viewer files, while a stale static-only deployment still looks online.
import assert from 'node:assert/strict';

const origin = process.env.WEB_ORIGIN || 'https://web-production-5a4c1.up.railway.app';
async function get(path) {
  const response = await fetch(new URL(path, origin), {
    signal: AbortSignal.timeout(30_000),
    headers: { 'Cache-Control': 'no-cache' },
  });
  assert.equal(response.status, 200, `${path}: HTTP ${response.status}`);
  return response;
}

const home = await get('/');
assert.match(await home.text(), /<div id="root"/);
const manifest = await (await get('/game/viewer.json')).json();
assert.equal(manifest.format, 1);
assert.ok(manifest.manual >= 3, 'The production Field Manual viewer is out of date');
const wasm = await get('/game/index.wasm');
const reader = wasm.body.getReader();
let prefix = Buffer.alloc(0);
try {
  while (prefix.length < 4) {
    const { value, done } = await reader.read();
    assert.ok(!done, 'Truncated WASM response');
    prefix = Buffer.concat([prefix, value]);
  }
  assert.equal(prefix.subarray(0, 4).toString('hex'), '0061736d', 'Missing WASM binary');
} finally {
  await reader.cancel();
}
console.log('Production website, viewer manifest, and WASM are available.');
