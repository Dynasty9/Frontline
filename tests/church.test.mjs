// The parish church as a place to fight (scenario "church"): a fighter cell
// holds it, two rifle squads and a gun team are sent to clear it, one squad
// up the road to the west door under the tower, the other round to the south
// porch. They must get in by both doors and fight it out inside.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game } from "./lib/game.mjs";
import { dist, fighting } from "./lib/expect.mjs";

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

/** Whether [x, z] is inside a floor (its footprint, turned by its yaw). */
function inside(p, floor) {
  const dx = p[0] - floor.pos[0];
  const dz = p[1] - floor.pos[1];
  const c = Math.cos(-floor.yaw);
  const s = Math.sin(-floor.yaw);
  const lx = c * dx + s * dz;
  const lz = -s * dx + c * dz;
  return Math.abs(lx) < floor.size[0] / 2 && Math.abs(lz) < floor.size[2] / 2;
}

test("the church is cleared by its west door and its south door, fighting inside", async () => {
  await game.load({ scenario: "church", seed: 5 });
  const { structures: walls } = await game.query("structures", { kind: "house_wall" });
  const doors = walls.filter((w) => w.variant === 2);
  assert.equal(doors.length, 2, "the church has two doors");
  const { structures: towers } = await game.query("structures", { kind: "church" });
  assert.equal(towers.length, 1, "and its tower");
  // the west door is the one by the tower
  doors.sort((a, b) => dist(a.pos, towers[0].pos) - dist(b.pos, towers[0].pos));
  const [west, south] = doors;
  assert.ok(dist(west.pos, towers[0].pos) < 3, `the west door is under the tower (${dist(west.pos, towers[0].pos).toFixed(1)} m)`);
  const { structures: floors } = await game.query("structures", { kind: "floor" });
  assert.equal(floors.length, 2, "a nave and a chancel");

  const through = { west: new Set(), south: new Set() };
  let fightingInside = 0;
  for (let t = 0; t < 100; t += 0.5) {
    await game.step(0.5);
    const { soldiers } = await game.query("soldiers", {});
    const men = soldiers.filter((s) => s.team === 0 && s.life === "ALIVE");
    for (const m of men) {
      if (dist(m.pos, west.pos) < 1.0) through.west.add(m.id);
      if (dist(m.pos, south.pos) < 1.0) through.south.add(m.id);
    }
    // ours and theirs both standing in the church at once: a fight inside
    const ours = men.filter((m) => floors.some((f) => inside(m.pos, f)));
    const theirs = soldiers.filter((s) => s.team === 1 && fighting(s) && floors.some((f) => inside(s.pos, f)));
    if (ours.length > 0 && theirs.length > 0) fightingInside += 0.5;
    if (through.west.size > 0 && through.south.size > 0 && t > 40 && theirs.length === 0) {
      const cell = soldiers.filter((s) => s.team === 1 && fighting(s));
      if (cell.length === 0) break;
    }
  }
  assert.ok(through.west.size >= 1, "men went in by the west door");
  assert.ok(through.south.size >= 1, "and by the south door");
  assert.ok(fightingInside >= 2, `they fought it out inside (${fightingInside} s with both sides in the church)`);
  const { counters } = await game.stats();
  assert.ok((counters.door_kicked ?? 0) + (counters.breach_door_kick ?? 0) >= 2, "both doors were kicked in");
  assert.ok((counters.room_entry ?? 0) >= 2, "they went in room by room");
  assert.ok((counters.house_cleared ?? 0) >= 1, "and called the church clear");
  const { soldiers: cell } = await game.query("soldiers", { team: 1 });
  assert.equal(cell.filter(fighting).length, 0, "nobody in the church is still fighting");
});
