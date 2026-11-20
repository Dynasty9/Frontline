import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import dgram from "node:dgram";
import { ROOT } from "./lib/game.mjs";

// A client has no nav (only the host paths soldiers), yet every peer reshapes a
// trench as it is dug and shelled: its depth arriving in a snapshot used to
// call into the missing nav and stop the snapshot there.
test("a trench dug and shelled on the host changes depth on a client", { timeout: 180_000 }, async (t) => {
  const socket = dgram.createSocket("udp4");
  await new Promise((resolve) => socket.bind(0, "127.0.0.1", resolve));
  const port = socket.address().port;
  await new Promise((resolve) => socket.close(resolve));
  const args = ["--headless", "--path", ROOT, "--script", "tests/fixtures/trench-peer.gd", "--", "--no-stun", `--port=${port}`];
  const executable = process.env.GODOT || "godot";
  let hostOutput = "", clientOutput = "", client, clientExit;
  const host = spawn(executable, [...args, "--scenario=attack", "--seed=3", "--listen", "--trench-host"]);
  t.after(() => { host.kill(); client?.kill(); });
  host.stdout.on("data", (data) => {
    hostOutput += data;
    if (hostOutput.includes("TRENCH HOST ready") && !client) {
      client = spawn(executable, [...args, "--join=127.0.0.1", "--team=-1"]);
      clientExit = new Promise((resolve) => client.on("exit", resolve));
      client.stdout.on("data", (data) => { clientOutput += data; });
      client.stderr.on("data", (data) => { clientOutput += data; });
    }
  });
  host.stderr.on("data", (data) => { hostOutput += data; });
  await new Promise((resolve, reject) => { host.on("exit", resolve); host.on("error", reject); });
  await Promise.race([clientExit, new Promise((resolve) => setTimeout(resolve, 15_000))]);
  const sent = hostOutput.match(/TRENCH HOST depth ([\d.]+) built=(\w+)/);
  const got = clientOutput.match(/TRENCH CLIENT depth ([\d.]+) built=(\w+) nav=(\w+) parts=(\d+)/);
  assert.ok(sent && got, hostOutput + clientOutput);
  assert.equal(sent[2], "true");
  assert.equal(got[1], sent[1], "the client's trench is as deep as the host's");
  assert.equal(got[2], "true");
  assert.equal(got[3], "false", "a client has no nav");
  assert.ok(Number(got[4]) > 0);
  assert.doesNotMatch(hostOutput + clientOutput, /SCRIPT ERROR/);
});
