// The parish church as a place to fight (scenario "church"): a fighter cell
// holds it, two rifle squads and a gun team are sent to clear it, one squad
// up the road to the west door under the tower, the other round to the south
// porch. They kick both doors in, go in by both, and the church is theirs:
// the cell is killed in it, or breaks and runs out across the fields behind
// (which, varies from seed to seed - so the test asks for neither), and the
// men who went in call it clear. On seed 8 both doors are blown out in the
// fight and the first pairs sent to clear it are hit at the door: the next
// go is through the gap where the west door stood.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game } from "./lib/game.mjs";
import { dist, fighting, within } from "./lib/expect.mjs";

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

for (const seed of [5, 8]) {
  test(`the church is cleared by its west door and its south door (seed ${seed})`, async () => {
    await game.load({ scenario: "church", seed });
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
    // in it, in the tower porch, or just outside its walls (in the porches, under the windows)
    const church = [...floors, towers[0]];
    const atChurch = (s) => church.some((st) => within(s.pos, st, 2.5));

    const through = { west: new Set(), south: new Set() };
    let counters = {};
    for (let t = 0; t < 100; t += 0.5) {
      await game.step(0.5);
      const { soldiers } = await game.query("soldiers", {});
      for (const m of soldiers.filter((s) => s.team === 0 && s.life === "ALIVE")) {
        if (dist(m.pos, west.pos) < 1.0) through.west.add(m.id);
        if (dist(m.pos, south.pos) < 1.0) through.south.add(m.id);
      }
      ({ counters } = await game.stats());
      const held = soldiers.some((s) => s.team === 1 && fighting(s) && atChurch(s));
      if (through.west.size > 0 && through.south.size > 0 && !held && (counters.house_cleared ?? 0) >= 1) break;
    }
    assert.ok(through.west.size >= 1, "men went in by the west door");
    assert.ok(through.south.size >= 1, "and by the south door");
    assert.ok((counters.door_kicked ?? 0) + (counters.breach_door_kick ?? 0) >= 2, "both doors were kicked in");
    assert.ok((counters.room_entry ?? 0) >= 1, "they stacked on a door and went in");
    assert.ok((counters.house_cleared ?? 0) >= 1, "and called the church clear");
    const { soldiers: cell } = await game.query("soldiers", { team: 1 });
    const left = cell.filter((s) => fighting(s) && atChurch(s));
    assert.equal(left.length, 0, `nobody in the church is still fighting (${left.map((s) => `${s.id} at ${s.pos}`).join(", ")})`);
  });
}
