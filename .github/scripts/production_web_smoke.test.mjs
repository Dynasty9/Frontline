import { createServer } from "node:http";
import { spawn } from "node:child_process";
import assert from "node:assert/strict";
let mode = "valid";
const server = createServer((req, res) => {
  if (req.url === "/") res.end('<div id="root"></div>');
  else if (req.url === "/manual")
    res.end(
      '<meta property="og:title" content="Field Manual · Frontline" /><div id="root"></div>',
    );
  else if (req.url.startsWith("/player/")) res.end('<div id="root"></div>');
  else if (req.url === "/robots.txt")
    res.end("User-agent: *\nAllow: /\n\nSitemap: http://x/sitemap.xml\n");
  else if (req.url === "/sitemap.xml") res.end("<urlset></urlset>");
  else if (req.url.startsWith("/no-such-page")) {
    // a deployment that answers an address with no page as if it had one
    res.statusCode = mode === "soft-404" ? 200 : 404;
    res.end('<div id="root"></div>');
  } else if (req.url.startsWith("/assets/")) {
    // a deployment that answers a missing bundle with the page
    res.statusCode = mode === "stale-asset" ? 200 : 404;
    res.end(mode === "stale-asset" ? '<div id="root"></div>' : "");
  } else if (req.url === "/game/viewer.json")
    res.end(
      mode === "fallback"
        ? "<html>fallback</html>"
        : JSON.stringify({ format: 1, manual: 3 }),
    );
  else
    res.end(
      mode === "bad-wasm"
        ? "<html>fallback</html>"
        : Buffer.from([0, 97, 115, 109]),
    );
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
try {
  for (const item of [
    "valid",
    "fallback",
    "bad-wasm",
    "stale-asset",
    "soft-404",
  ]) {
    mode = item;
    const child = spawn(
      process.execPath,
      [".github/scripts/production_web_smoke.mjs"],
      {
        env: {
          ...process.env,
          WEB_ORIGIN: `http://127.0.0.1:${server.address().port}`,
        },
        stdio: "ignore",
      },
    );
    const code = await new Promise((r) => child.on("exit", r));
    assert.equal(code === 0, item === "valid", item);
    console.log(`${item}: expected result`);
  }
} finally {
  server.close();
}
