import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import dgram from "node:dgram";
import { ROOT } from "./lib/game.mjs";

test("ENet clients receive produced tank, IFV and technical wreck properties", { timeout: 180_000 }, async (t) => {
  const socket = dgram.createSocket("udp4");
  await new Promise((resolve) => socket.bind(0, "127.0.0.1", resolve));
  const port = socket.address().port;
  await new Promise((resolve) => socket.close(resolve));
  const args = ["--headless", "--path", ROOT, "--script", "tests/fixtures/wreck-peer.gd", "--", "--no-stun", `--port=${port}`];
  const executable = process.env.GODOT || "godot";
  let hostOutput = "", clientOutput = "", client;
  const host = spawn(executable, [...args, "--scenario=attack", "--seed=3", "--listen", "--wreck-host"]);
  t.after(() => { host.kill(); client?.kill(); });
  host.stdout.on("data", (data) => {
    hostOutput += data;
    if (hostOutput.includes("WRECK HOST ready") && !client) {
      client = spawn(executable, [...args, "--join=127.0.0.1", "--team=-1"]);
      client.stdout.on("data", (data) => { clientOutput += data; });
      client.stderr.on("data", (data) => { clientOutput += data; });
    }
  });
  host.stderr.on("data", (data) => { hostOutput += data; });
  await new Promise((resolve, reject) => { host.on("exit", resolve); host.on("error", reject); });
  const expected = JSON.parse(hostOutput.match(/WRECK HOST properties (.*)/)?.[1] || "null");
  const received = JSON.parse(clientOutput.match(/WRECK CLIENT properties (.*)/)?.[1] || "null");
  assert.ok(expected && received, hostOutput + clientOutput);
  assert.deepEqual(received, expected);
  assert.equal(received.tank.turret_off, true);
  assert.equal(typeof received.tank.wreck_turret_yaw, "number");
  assert.equal(typeof received.tank.bent_skirts, "number");
  assert.equal(received.slammer.turret_off, true);
  assert.equal(received.technical.turret_off, false);
  assert.doesNotMatch(hostOutput + clientOutput, /SCRIPT ERROR/);
});
