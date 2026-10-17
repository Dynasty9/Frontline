// Boats (scenario "naval"): an RHIB with a rifle squad aboard and a patrol
// ship off the coast, two Rebel boats down it and a fighter cell dug in
// behind their beach. Both Coalition boats start lying on a boat cell (as a
// boat built at a dock does), bows pointing up the coast.

import { test } from "node:test";
import assert from "node:assert/strict";
import { Game, v3 } from "./lib/game.mjs";

test("a boat sent somewhere dead astern comes about and goes there", async (t) => {
  // its route runs straight back along its own keel line: it used to keep
  // the helm amidships and steam off the other way for good
  const game = await Game.start();
  t.after(() => game.close()); // (a failed check leaves no game running)
  await game.load({ scenario: "naval", seed: 1, static: true });
  const [ship] = (await game.query("vehicles", { kind: "patrol_ship" })).vehicles;
  const to = [ship.pos[0], ship.pos[1] - 60];
  await game.order(0, "move", { vehicles: [ship.id], pos: v3(...to) });
  await game.step(60);
  const [after] = (await game.query("vehicles", { ids: [ship.id] })).vehicles;
  const off = Math.hypot(after.pos[0] - to[0], after.pos[1] - to[1]);
  assert.ok(off < 10, `the ship is ${off.toFixed(1)} m from where it was sent (at ${after.pos})`);
  assert.equal(await game.close(), 0);
});

test("the RHIB lands its squad on the beach", async (t) => {
  const game = await Game.start();
  t.after(() => game.close());
  for (const seed of [1, 2, 3]) {
    await t.test(`seed ${seed}`, async () => {
      await game.load({ scenario: "naval", seed });
      await game.step(60);
      const { counters } = await game.stats();
      assert.ok(counters.dismount >= 1, "the squad got out");
      const ashore = (await game.query("soldiers", { team: 0 })).soldiers.filter((s) => s.life === "ALIVE" && s.riding === 0);
      assert.ok(ashore.length >= 3, `the squad is ashore (${ashore.length} of 5)`);
    });
  }
  assert.equal(await game.close(), 0);
});
