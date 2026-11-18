// Cars parked along the town's kerbs (TownGen.kerbside): a battle's town has
// its streets lined with them, in runs along the kerb, out of the junctions'
// mouths and never opposite one another, so a lorry or a tank still gets
// down the street.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game } from "./lib/game.mjs";

const S = 40; // between the town's parallel streets (TownGen.S)
const REACH = 56; // how far its main streets run from the middle (TownGen.REACH)
const PARK_OUT = 1.75; // a parked car's middle from the middle of its street (TownGen.PARK_OUT)
const SLOT = 4.4; // its length along the kerb (TownGen.PARK_SLOT)

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

// The town's cars standing in a street: which street (its axis and the line
// it runs along), where along it, which side of it, and how it's turned
// against it. (Its streets run along x and z, every S from the middle.)
function kerbCars(cars, town) {
  const out = [];
  for (const car of cars) {
    const dx = car.pos[0] - town[0];
    const dz = car.pos[1] - town[1];
    if (Math.abs(dx) > REACH || Math.abs(dz) > REACH) continue;
    let best = null;
    for (const [axis, across, along] of [
      ["x", dz, dx],
      ["z", dx, dz],
    ]) {
      const line = Math.round(across / S) * S;
      const off = across - line;
      // a street along x runs at yaw ±π/2 (a car's nose is its -z)
      const street = axis === "x" ? Math.PI / 2 : 0;
      const turn = Math.abs(((((car.yaw - street + Math.PI / 2) % Math.PI) + Math.PI) % Math.PI) - Math.PI / 2);
      if (Math.abs(off) < 2.2 && Math.abs(line) <= S && turn < 0.6 && (!best || Math.abs(off) < best.off)) {
        best = { id: car.id, axis, line, along, side: Math.sign(off), off: Math.abs(off), turn };
      }
    }
    if (best) out.push(best);
  }
  return out;
}

test("the town's streets are lined with parked cars, clear of junctions and never opposite", async () => {
  await game.load({ battle: true, seed: 3, static: true });
  const world = await game.query("world");
  const town = world.key_points.find((k) => k.kind === "town").pos;
  const { counters } = await game.stats();
  const { structures } = await game.query("structures", { kind: "car" });
  const parked = kerbCars(structures, town);
  assert.ok(counters.kerb_car >= 10, `a town's worth of parked cars (${counters.kerb_car})`);
  assert.equal(parked.length, counters.kerb_car, "every one of them stands at a kerb in the town's streets");
  for (const c of parked) {
    assert.ok(c.off > 0.8 && c.off < PARK_OUT + 0.1, `car ${c.id} is at the kerb, not in the middle of the road (${c.off.toFixed(2)} m out)`);
    assert.ok(c.turn < 0.45, `car ${c.id} lies along its street (turned ${c.turn.toFixed(2)})`);
    // (the main streets cross in the middle of the town, zebras on every side)
    if (c.line === 0) {
      assert.ok(Math.abs(c.along) > SLOT * 0.5 + 8.0, `car ${c.id} is out of the crossroads' mouth (${c.along.toFixed(1)} m from it)`);
    }
  }
  for (const a of parked) {
    for (const b of parked) {
      if (a.axis === b.axis && a.line === b.line && a.side < b.side) {
        assert.ok(Math.abs(a.along - b.along) >= SLOT - 0.05, `cars ${a.id} and ${b.id} aren't parked opposite each other`);
      }
    }
  }
});
