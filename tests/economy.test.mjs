// The skirmish economy: HQ's lorries feed every start FOB alike whatever the
// map, the old vehicles wait for their research, and a fallen dump is half
// burnt (tests/fixtures/economy.gd checks those rules on their own).

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { Game, ROOT } from "./lib/game.mjs";

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

test("tier gates, captured dumps and HQ priority follow the rules", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/economy.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error/);
  assert.match(stdout, /ECONOMY passed/, stdout);
});

// Seed 3 puts the Coalition's start FOB 20 m from HQ by road and the Rebels'
// nearly 80: HQ's lorries used to turn round as fast as they could, so the
// Coalition drew three times the Rebels' income and won on the map. And
// neither side's first lorry left before the network was next rebuilt (about
// two minutes in), since the start roads were laid before the ground was
// surveyed.
test("both start FOBs are supplied from the first minute, at the same pace", async () => {
  await game.load({ battle: true, seed: 3 });
  await game.step(125);
  const { counters, report } = await game.stats();
  assert.ok(counters.road_resurveyed >= 2, "the start roads were laid again once the ground was surveyed");
  const got = (side) => {
    const m = new RegExp(`${side} kills=[^\\n]*delivered=([0-9]+)`).exec(String(report));
    assert.ok(m, `the after-action summary gives ${side}'s deliveries: ${JSON.stringify(report)}`);
    return Number(m[1]);
  };
  const [coal, reb] = [got("Coalition"), got("Rebels")];
  assert.ok(coal >= 230 && reb >= 260, `both sides had two loads or more from HQ (Coalition ${coal}, Rebels ${reb})`);
  assert.ok(coal < reb * 1.6, `the FOB nearer HQ is not fed faster (Coalition ${coal}, Rebels ${reb})`);
});
