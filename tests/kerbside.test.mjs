// The main streets' parking lanes (TownGen.PARK_LANE, TownGen.kerbside): a
// battle's town has its two main streets a parking lane wider each side than
// the side streets, marked off from the traffic lanes by a solid line; a few
// short runs of bays are marked out in them by the shops, a car in about half
// of them, and no car is parked in the street anywhere else. The runs keep out
// of the junctions' mouths, and both traffic lanes stay open past them.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game } from "./lib/game.mjs";

const S = 40; // between the town's parallel streets (TownGen.S)
const REACH = 56; // how far its main streets run from the middle (TownGen.REACH)
const CURB = 2.9; // a side street's kerb, and the edge of a main street's traffic lanes, from its middle (TownGen.CURB)
const LANE = 2.2; // a main street's parking lane (TownGen.PARK_LANE)
const PARK_OUT = CURB + LANE / 2; // a parked car's middle from the middle of its street (TownGen.PARK_OUT)
const BAY = 5.8; // a bay's length along the kerb (TownGen.BAY_L)
const CAR = 4.2; // a car's length

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

// Things standing in the town's streets, up to `reach` from the middle of
// one: which street (its axis and the line it runs along), where along it,
// which side of it, how far out, and how they're turned against it. (Its
// streets run along x and z, every S from the middle.) A car's yaw points its
// nose (its -z) along its street; decor's, its +x.
function inStreet(things, town, isDecor, reach) {
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
      const street = (axis === "x") !== isDecor ? Math.PI / 2 : 0;
      const turn = Math.abs(((((it.yaw - street + Math.PI / 2) % Math.PI) + Math.PI) % Math.PI) - Math.PI / 2);
      if (Math.abs(off) < reach && Math.abs(line) <= S && turn < 0.6 && (!best || Math.abs(off) < best.off)) {
        best = { id: it.id, axis, line, along, side: Math.sign(off), off: Math.abs(off), turn };
      }
    }
    if (best) out.push(best);
  }
  return out;
}

test("the main streets have parking lanes, a few runs of bays in them half taken, and no car parks anywhere else in the street", async () => {
  await game.load({ battle: true, seed: 3, static: true });
  const world = await game.query("world");
  const town = world.key_points.find((k) => k.kind === "town").pos;
  const { counters } = await game.stats();
  const { structures } = await game.query("structures", { kind: "car" });
  const { decor: bayDecor } = await game.query("decor", { kind: "bays" });
  const { decor: lineDecor } = await game.query("decor", { kind: "lane_edge" });
  const { decor: kerbDecor } = await game.query("decor", { kind: "curb" });
  const { decor: wide } = await game.query("decor", { kind: "street_wide" });
  const reach = CURB + LANE;
  const parked = inStreet(structures, town, false, reach);
  const bays = inStreet(bayDecor, town, true, reach);
  const lines = inStreet(lineDecor, town, true, reach);
  const kerbs = inStreet(kerbDecor, town, true, reach + 0.5);

  // the street plan: the main streets (through the middle) a parking lane wider each side
  assert.equal(wide.length, 2, "both main streets are drawn wide");
  assert.ok(kerbs.length > 8, `the kerbs (${kerbs.length})`);
  for (const k of kerbs) {
    const want = (k.line === 0 ? reach : CURB) + 0.09;
    assert.ok(Math.abs(k.off - want) < 0.05, `the kerb along ${k.axis} ${k.line} stands ${want.toFixed(2)} m out (${k.off.toFixed(2)})`);
  }
  for (const axis of ["x", "z"]) {
    for (const side of [-1, 1]) {
      assert.ok(
        lines.some((l) => l.axis === axis && l.line === 0 && l.side === side),
        `a line marks off the parking lane down side ${side} of the main street along ${axis}`,
      );
    }
  }
  for (const l of lines) {
    assert.ok(l.line === 0, `lane lines only on the main streets (${l.axis} ${l.line})`); // (=== since a line just short of 0 is -0)
    assert.ok(Math.abs(l.off - (CURB + 0.06)) < 0.05, `between the traffic and the parking lane (${l.off.toFixed(2)} m out)`);
  }

  // the bays, and the cars in them
  assert.equal(bays.length, counters.parking_bay, "every bay is marked out in one of the town's streets");
  assert.ok(bays.length >= 4 && bays.length <= 16, `a few runs of bays (${bays.length})`);
  assert.ok(counters.kerb_car >= 2, `cars in some of them (${counters.kerb_car})`);
  assert.ok(counters.kerb_car < bays.length, `but not in all of them (${counters.kerb_car} cars, ${bays.length} bays)`);
  assert.equal(parked.length, counters.kerb_car, "no car is parked in the street but in a bay");
  for (const b of bays) {
    assert.ok(b.line === 0, `bay ${b.along.toFixed(1)} is on a main street (${b.axis} ${b.line})`);
    assert.ok(Math.abs(b.off - PARK_OUT) < 0.05, `the bays are marked out in the parking lane (${b.off.toFixed(2)} m out)`);
    assert.ok(Math.abs(b.along) > BAY * 0.5 + 8.0, `the bays keep out of the crossroads' mouth (${b.along.toFixed(1)} m from it)`);
  }
  for (const c of parked) {
    const bay = bays.find((b) => b.axis === c.axis && b.line === c.line && b.side === c.side && Math.abs(b.along - c.along) < (BAY - CAR) * 0.5 + 0.05);
    assert.ok(bay, `car ${c.id} stands in a bay (${c.axis} ${c.line} ${c.along.toFixed(1)})`);
    assert.ok(c.turn < 0.05, `car ${c.id} lies straight in it (turned ${c.turn.toFixed(2)})`);
    assert.ok(Math.abs(c.off - PARK_OUT) < 0.05, `car ${c.id} is out of the traffic lanes (${c.off.toFixed(2)} m out)`);
  }
});
