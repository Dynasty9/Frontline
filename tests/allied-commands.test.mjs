// Shared command is tested at the server dispatcher and through a real ENet
// host/client connection. The little fixture omits map generation, not the
// command authority, selection or unit order implementations.
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import dgram from "node:dgram";
import { ROOT } from "./lib/game.mjs";

function run(t, mode, port = 0) {
  const proc = spawn(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/allied-commands.tscn", "--",
    `--command-mode=${mode}`, `--port=${port}`, "--no-stun",
  ], { stdio: ["ignore", "pipe", "pipe"] });
  let out = "";
  proc.stdout.on("data", (d) => { out += d; });
  proc.stderr.on("data", (d) => { out += d; });
  const done = new Promise((resolve, reject) => {
    proc.on("error", reject);
    proc.on("exit", (code) => resolve({ code, out }));
  });
  const timeout = setTimeout(() => proc.kill(), 120_000);
  t.after(() => { clearTimeout(timeout); proc.kill(); });
  return {
    done,
    async listening() {
      if (/ALLIED COMMANDS listening/.test(out)) return;
      let waitTimer;
      const timer = new Promise((_, reject) => { waitTimer = setTimeout(() => reject(new Error(`host never listened:\n${out}`)), 90_000); });
      const ready = new Promise((resolve, reject) => {
        proc.stdout.on("data", () => { if (/ALLIED COMMANDS listening/.test(out)) resolve(); });
        done.then(({ code, out }) => reject(new Error(`host exited ${code} before listening:\n${out}`)));
      });
      try { await Promise.race([timer, ready]); } finally { clearTimeout(waitTimer); }
    },
  };
}

function passed(result, mode) {
  assert.equal(result.code, 0, result.out);
  assert.doesNotMatch(result.out, /SCRIPT ERROR|Parse Error|^FAIL /m);
  assert.match(result.out, new RegExp(`ALLIED COMMANDS ${mode} [0-9]+/[0-9]+ passed`));
}

async function freePort() {
  const socket = dgram.createSocket("udp4");
  await new Promise((resolve, reject) => { socket.once("error", reject); socket.bind(0, "127.0.0.1", resolve); });
  const { port } = socket.address();
  await new Promise((resolve) => socket.close(resolve));
  return port;
}

test("allied control, selection, AI handoff and authority checks", async (t) => {
  passed(await run(t, "local").done, "local");
});

test("an ENet client commands host troops but cannot forge enemy or observer authority", async (t) => {
  const port = await freePort();
  const host = run(t, "host", port);
  await host.listening();
  const client = run(t, "client", port);
  const [h, c] = await Promise.all([host.done, client.done]);
  passed(h, "host");
  passed(c, "client");
});
