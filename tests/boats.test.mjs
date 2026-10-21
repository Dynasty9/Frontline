// Boats (scenario "naval"): an RHIB with a rifle squad aboard and a patrol
// ship off the coast, two Rebel boats down it and a fighter cell dug in
// behind their beach. Both Coalition boats start lying on a boat cell (as a
// boat built at a dock does), bows pointing up the coast. A boat handles like
// one, not like a car (Vehicle._hull_tick): no brakes, and a skid in a turn.

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

test("a big hull sent astern comes about, picks up its route further on and never touches the bank", async (t) => {
  // the patrol ship turns in a 26 m circle: it used to come round, find the
  // route's first points (next to where it started) inside that circle, go
  // round again for them and run aground on the beach; on seed 4 the coast
  // bulges into the circle on the shore side, so it has to come about to seaward
  const game = await Game.start();
  t.after(() => game.close());
  for (const [seed, off] of [
    [6, [-32, -50]],
    [4, [0, -65]],
  ]) {
    await t.test(`seed ${seed}`, async () => {
      await game.load({ scenario: "naval", seed, static: true });
      const [ship] = (await game.query("vehicles", { kind: "patrol_ship" })).vehicles;
      const to = [ship.pos[0] + off[0], ship.pos[1] + off[1]];
      await game.order(0, "assault", { vehicles: [ship.id], pos: v3(...to) });
      await game.step(75);
      const [after] = (await game.query("vehicles", { ids: [ship.id] })).vehicles;
      const left = Math.hypot(after.pos[0] - to[0], after.pos[1] - to[1]);
      assert.ok(left < 10, `the ship is ${left.toFixed(1)} m from where it was sent (at ${after.pos})`);
      const { counters } = await game.stats();
      assert.ok(counters.boat_rejoin >= 1, "it picked up its route further on");
      assert.ok(!counters.boat_aground, `it ran aground ${counters.boat_aground} times`);
    });
  }
  assert.equal(await game.close(), 0);
});

test("a big hull backs into a spot not far astern rather than swing out in a loop for it", async (t) => {
  // 50 m dead astern is less than the patrol ship's turning circle is across
  const game = await Game.start();
  t.after(() => game.close());
  await game.load({ scenario: "naval", seed: 4, static: true });
  const [ship] = (await game.query("vehicles", { kind: "patrol_ship" })).vehicles;
  const to = [ship.pos[0], ship.pos[1] - 50];
  await game.order(0, "assault", { vehicles: [ship.id], pos: v3(...to) });
  await game.step(30);
  const [after] = (await game.query("vehicles", { ids: [ship.id] })).vehicles;
  const left = Math.hypot(after.pos[0] - to[0], after.pos[1] - to[1]);
  assert.ok(left < 8, `the ship is ${left.toFixed(1)} m from where it was sent after 30 s (at ${after.pos})`);
  assert.ok(!(await game.stats()).counters.boat_aground, "it never touched the bank");
  assert.equal(await game.close(), 0);
});

// (the RHIB up to speed out to sea and up the coast, from where she lies)
async function rhibAtSpeed(game) {
  const [b] = (await game.query("vehicles", { kind: "rhib" })).vehicles;
  await game.order(0, "move", { vehicles: [b.id], pos: v3(b.pos[0] + 70, b.pos[1] + 380) });
  let v = b;
  for (let i = 0; i < 40 && v.speed < 13; i++) {
    await game.step(0.5);
    [v] = (await game.query("vehicles", { ids: [b.id] })).vehicles;
  }
  assert.ok(v.speed >= 13, `the RHIB got up to speed (${v.speed} m/s)`);
  return v;
}

test("a boat has no brakes: stopped from full speed, she carries her way a long way", async (t) => {
  // the water's drag and going astern are all she has to stop with: a car
  // brakes from 50 km/h in a dozen metres, an RHIB takes three or four times that
  const game = await Game.start();
  t.after(() => game.close());
  await game.load({ scenario: "naval", seed: 1, static: true });
  const v0 = await rhibAtSpeed(game);
  await game.order(0, "stop", { vehicles: [v0.id] });
  let v = v0;
  let secs = 0;
  while (secs < 30 && Math.hypot(...v.vel) > 0.3) {
    await game.step(0.25);
    secs += 0.25;
    [v] = (await game.query("vehicles", { ids: [v0.id] })).vehicles;
  }
  const ran = Math.hypot(v.pos[0] - v0.pos[0], v.pos[1] - v0.pos[1]);
  assert.ok(secs < 30, "she did stop, going astern");
  assert.ok(ran > 30, `from ${v0.speed} m/s she stopped in ${ran.toFixed(1)} m`);
  // and, stopped, she stays stopped (not drifting on at a crawl)
  await game.step(10);
  const [after] = (await game.query("vehicles", { ids: [v0.id] })).vehicles;
  const drift = Math.hypot(after.pos[0] - v.pos[0], after.pos[1] - v.pos[1]);
  assert.ok(drift < 1.5, `she drifted ${drift.toFixed(1)} m after stopping`);
  assert.equal(await game.close(), 0);
});

test("a boat skids in a hard turn: her bow points inside the way she's going", async (t) => {
  const game = await Game.start();
  t.after(() => game.close());
  await game.load({ scenario: "naval", seed: 1, static: true });
  const v0 = await rhibAtSpeed(game);
  // hard round to port, for a point abeam
  const fwd = [-Math.sin(v0.yaw), -Math.cos(v0.yaw)];
  await game.order(0, "move", { vehicles: [v0.id], pos: v3(v0.pos[0] + fwd[1] * 60, v0.pos[1] - fwd[0] * 60) });
  let skid = 0;
  for (let i = 0; i < 24; i++) {
    await game.step(0.25);
    const [v] = (await game.query("vehicles", { ids: [v0.id] })).vehicles;
    if (Math.hypot(...v.vel) < 2) continue;
    // (+: the way she's going is to the left of her bow)
    const s = Math.atan2(Math.sin(Math.atan2(-v.vel[0], -v.vel[1]) - v.yaw), Math.cos(Math.atan2(-v.vel[0], -v.vel[1]) - v.yaw));
    skid = Math.min(skid, s);
  }
  const deg = (-skid * 180) / Math.PI;
  assert.ok(deg > 5 && deg < 40, `turning to port, her track ran up to ${deg.toFixed(1)} degrees to starboard of her bow`);
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
