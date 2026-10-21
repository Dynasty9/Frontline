// frontline:// links reach the game that's open. A link starts a second copy,
// which hands it to the running game over a local socket and quits. Only one
// copy can hold that socket, so a game that started while another still had
// it (the copy an update replaces quits only after starting the new one)
// takes it over once that one has gone, rather than leaving every link to
// start a second game.

import { test, after } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import { Game, ROOT } from "./lib/game.mjs";

/** A port nothing is listening on, so these copies keep to themselves. */
const freePort = () =>
  new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.on("error", reject);
    srv.listen(0, "127.0.0.1", () => {
      const { port } = srv.address();
      srv.close(() => resolve(port));
    });
  });

/**
 * Runs a game on a little at a time until it prints a line matching `re`. (The
 * test port holds the frame between commands, and the game looks for the
 * port, and reads its links, only as its frames run.)
 */
async function until(game, re) {
  for (let i = 0; i < 200; i++) {
    if (game.output.some((line) => re.test(line))) return;
    await game.step(0.1);
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  assert.fail(`never printed ${re}:\n${game.output.slice(-20).join("\n")}`);
}

/** The copy a browser starts with `link`: {code, out} once it has quit. */
function openLink(link) {
  // (the switch makes it a test run that quits, should it end up a game of its own)
  const args = ["--headless", "--fixed-fps", "30", "--path", ROOT, "--", link, "--quit-after=20"];
  const proc = spawn(process.env.GODOT || "godot", args, { stdio: ["ignore", "pipe", "pipe"] });
  let out = "";
  proc.stdout.on("data", (d) => (out += d));
  proc.stderr.on("data", (d) => (out += d));
  return new Promise((resolve) => proc.on("exit", (code) => resolve({ code, out })));
}

process.env.FL_LINKS_PORT = String(await freePort());
process.env.FL_DEBUG_ONLINE = "1";
// a fresh account, never the one on this computer
const account = path.join(os.tmpdir(), `frontline-links-test-${process.pid}.cfg`);
const games = await Game.startMany(2, { args: ["--links", `--account=${account}`] });
after(() => Promise.all(games.map((g) => g.close())));

test("a link reaches the game that's open, after the copy that had the port quits", async () => {
  // they started together: one took the port, and the other found it taken
  const holds = games.map((g) => g.output.some((line) => line.includes("LINKS listening for links")));
  assert.equal(holds.filter(Boolean).length, 1, "exactly one copy holds the port");
  const [gone, open] = holds[0] ? games : [games[1], games[0]];
  assert.equal(await gone.close(), 0);
  await open.load({ scenario: "attack", seed: 1, static: true });
  await until(open, /LINKS listening for links/);
  const second = await openLink("frontline://sign-in/a-state/a-token");
  assert.match(second.out, /LINKS handed sign-in to the running game/);
  assert.equal(second.code, 0);
  await until(open, /LINKS got sign-in from a second copy/);
});
