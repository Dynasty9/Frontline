import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { test } from "node:test";
import { createServer } from "../matchmaker/src/server.js";

test("Rust battles upload observer archives and keep independently verified command replays", { timeout: 300_000 }, async (t) => {
  const directory = await mkdtemp(path.join(tmpdir(), "frontline-socket-broadcast-"));
  const server = createServer({ env: { REPLAY_DIR: directory }, auth: null, log: () => {} });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  t.after(async () => {
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
    assert.equal(path.dirname(directory), path.resolve(tmpdir()));
    assert.ok(path.basename(directory).startsWith("frontline-socket-broadcast-"));
    await rm(directory, { recursive: true, force: true });
  });
  const origin = `http://127.0.0.1:${server.address().port}`;
  const child = spawn(process.env.GODOT || "godot", ["--headless", "--path", path.resolve(import.meta.dirname, ".."), "--",
    "--native-replay-test", "--replay-upload-test", `--matchmaker=${origin}`, "--port=0", "--no-stun"], { stdio: ["ignore", "pipe", "pipe"] });
  const stop = () => {
    if (child.exitCode !== null) return;
    if (process.platform === "win32") spawnSync("taskkill", ["/PID", String(child.pid), "/T", "/F"], { stdio: "ignore" });
    else child.kill();
  };
  t.after(stop);
  let output = "";
  const collect = (data) => {
    output += data;
    if (/SCRIPT ERROR|Parse Error/.test(output)) stop();
  };
  child.stdout.on("data", collect);
  child.stderr.on("data", collect);
  const code = await new Promise((resolve, reject) => {
    child.once("error", reject);
    child.once("exit", resolve);
  });
  assert.equal(code, 0, output);
  assert.match(output, /RUST_REPLAY_TEST failures=0 scripts=0/);
  assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
  const listing = await (await fetch(`${origin}/replays`)).json();
  assert.equal(listing.replays.length, 1);
  const replay = await (await fetch(`${origin}/replays/${listing.replays[0].id}`)).json();
  assert.equal(replay.format, 2);
  assert.equal(replay.verified, false);
  assert.equal(replay.status, "complete");
  // The render stream samples at 15 Hz; leaving can precede its next snapshot.
  assert.ok(replay.chunks.length >= 2 && replay.duration >= 3.8);
  for (const chunk of replay.chunks) {
    const response = await fetch(`${origin}/replays/${replay.id}/chunks/${chunk.sequence}`);
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.ok(body.data.length > 0 && body.size > 0);
  }
});
