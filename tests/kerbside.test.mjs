// Parking bays along the town's main streets (TownGen.kerbside): a battle's
// town has a few short runs of bays marked out at the kerb by the shops, a car
// in about half of them, and no car parked in the street anywhere else. The
// runs keep out of the junctions' mouths and never face one another, so a
// lorry or a tank still gets down the street.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game } from "./lib/game.mjs";

const S = 40; // between the town's parallel streets (TownGen.S)
const REACH = 56; // how far its main streets run from the middle (TownGen.REACH)
const PARK_OUT = 1.9; // a parked car's middle from the middle of its street (TownGen.PARK_OUT)
const BAY = 4.8; // a bay's length along the kerb (TownGen.BAY_L)
const CAR = 4.2; // a car's length

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

// Things standing in the town's streets: which street (its axis and the line
// it runs along), where along it, which side of it, and how they're turned
// against it. (Its streets run along x and z, every S from the middle.) A
// car's yaw points its nose (its -z) along its street; a bay's, its +x.
function inStreet(things, town, isBay) {
  const out = [];
  for (const it of things) {
    const dx = it.pos[0] - town[0];
    const dz = it.pos[1] - town[1];
    if (Math.abs(dx) > REACH || Math.abs(dz) > REACH) continue;
    let best = null;
    for (const [axis, across, along] of [
      ["x", dz, dx],
      ["z", dx, dz],
    ]) {
      const line = Math.round(across / S) * S;
      const off = across - line;
      const street = (axis === "x") !== isBay ? Math.PI / 2 : 0;
      const turn = Math.abs(((((it.yaw - street + Math.PI / 2) % Math.PI) + Math.PI) % Math.PI) - Math.PI / 2);
      if (Math.abs(off) < 2.2 && Math.abs(line) <= S && turn < 0.6 && (!best || Math.abs(off) < best.off)) {
        best = { id: it.id, axis, line, along, side: Math.sign(off), off: Math.abs(off), turn };
      }
    }
    if (best) out.push(best);
  }
  return out;
}

test("the main streets have a few runs of parking bays, half of them taken, and no car parks anywhere else in the street", async () => {
  await game.load({ battle: true, seed: 3, static: true });
  const world = await game.query("world");
  const town = world.key_points.find((k) => k.kind === "town").pos;
  const { counters } = await game.stats();
  const { structures } = await game.query("structures", { kind: "car" });
  const { decor } = await game.query("decor", { kind: "bays" });
  const parked = inStreet(structures, town, false);
  const bays = inStreet(decor, town, true);
  assert.equal(bays.length, counters.parking_bay, "every bay is marked out in one of the town's streets");
  assert.ok(bays.length >= 6 && bays.length <= 16, `a few runs of bays (${bays.length})`);
  assert.ok(counters.kerb_car >= 3, `cars in some of them (${counters.kerb_car})`);
  assert.ok(counters.kerb_car < bays.length, `but not in all of them (${counters.kerb_car} cars, ${bays.length} bays)`);
  assert.equal(parked.length, counters.kerb_car, "no car is parked in the street but in a bay");
  for (const b of bays) {
    assert.ok(b.line === 0, `bay ${b.along.toFixed(1)} is on a main street (${b.axis} ${b.line})`); // (=== since a line just short of 0 is -0)
    assert.ok(Math.abs(b.off - PARK_OUT) < 0.05, `the bays are marked out at the kerb (${b.off.toFixed(2)} m out)`);
    assert.ok(Math.abs(b.along) > BAY * 0.5 + 8.0, `the bays keep out of the crossroads' mouth (${b.along.toFixed(1)} m from it)`);
  }
  for (const c of parked) {
    const bay = bays.find((b) => b.axis === c.axis && b.line === c.line && b.side === c.side && Math.abs(b.along - c.along) < (BAY - CAR) * 0.5 + 0.05);
    assert.ok(bay, `car ${c.id} stands in a bay (${c.axis} ${c.line} ${c.along.toFixed(1)})`);
    assert.ok(c.turn < 0.05, `car ${c.id} lies straight in it (turned ${c.turn.toFixed(2)})`);
  }
  for (const a of bays) {
    for (const b of bays) {
      if (a.axis === b.axis && a.line === b.line && a.side < b.side) {
        assert.ok(Math.abs(a.along - b.along) >= BAY, `the bays at ${a.along.toFixed(1)} and ${b.along.toFixed(1)} aren't marked out opposite each other`);
      }
    }
  }
});
