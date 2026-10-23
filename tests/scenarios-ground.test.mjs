// What each scenario about the ground and what's built on it (mapgen.gd
// scenario(): towns, fire, works, guns, and the set pieces kept for looking
// at) is there to show, as an expectation: run with its seed, it must still
// happen. See lib/expect.mjs for how a row works, and docs/DEVELOPMENT.md
// ("Scenario expectations") for how to add one.

import assert from "node:assert/strict";
import { test } from "node:test";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";
import { scenarioTests, dist } from "./lib/expect.mjs";

// The cache scenario prints who the Coalition sees under the camouflage net and
// out in the open, and who has filled up from the cache (mapgen.gd). The games
// this file starts inherit it; only that scenario looks.
process.env.FL_DEBUG_WORKS = "1";

/** The numbers in the last line of the game's output that matches `re`. */
function printed(game, re) {
  const line = game.output.findLast((l) => re.test(l));
  assert.ok(line, `the game printed a line like ${re}`);
  return re.exec(line).slice(1).map(Number);
}

/** The defensive works, as --scenario=works lays them out (MapGen.WORKS), and the trench. */
const WORKS = ["sandbags", "hesco", "barricade", "concrete_wall", "wire", "tank_trap", "mines", "ammo_cache", "mg_nest", "hmg_nest",
  "mortar_pit", "at_post", "bunker", "watchtower", "camo_net", "trench"];

scenarioTests([
  {
    scenario: "town",
    seed: 1,
    secs: 110,
    does: "a squad takes a village's dump, its lorry runs the stock to the FOB, and a Rebel cell comes to take it back",
    check: async (f) => {
      f.atLeast("town_captured", 1, "the squad took the village");
      f.atLeast("town_truck_sent", 1, "the village sent its lorry");
      f.atLeast("town_truck_delivered", 1, "which got the stock to FOB Alpha");
      const [cell] = await f.squads({ team: 1 });
      assert.ok(dist(cell.pos, [0, -19]) < 40, `the Rebel cell came back for the dump (at ${cell.pos})`);
    },
  },
  {
    scenario: "fire",
    seed: 4,
    secs: 60,
    does: "fire spreads through the wood and along the hedge, and things burn down",
    check: async (f) => {
      f.atLeast("fire_tree", 4, "the fire went through the wood (two trees were lit)");
      f.atLeast("fire_hedge", 3, "and along the hedgerow (one section was lit)");
      f.atLeast("burnt_down", 2, "things burnt down");
      // Damage and escape are forced in the fixture below: troops can avoid this fire.
    },
  },
  {
    scenario: "cache",
    seed: 1,
    secs: 20,
    does: "an empty-handed squad fills up at an ammo cache, which then cooks off; a camouflage net hides who's under it",
    check: async (f) => {
      f.atLeast("cache_draw", 1, "the squad drew ammunition from the cache");
      const [full, of] = printed(f.game, /^WORKS t=8 resupplied=(\d+)\/(\d+)/);
      assert.equal(full, of, "every man of it filled up");
      f.atLeast("cache_cook_off", 1, "the cache cooked off when it was hit");
      assert.equal((await f.structures({ kind: "ammo_cache" })).length, 0, "and is gone");
      const [hid, hidSeen, open, openSeen] = printed(f.game, /^WORKS t=2\.5 under_net=(\d+) seen=(\d+)\s+in_open=(\d+) seen=(\d+)/);
      assert.ok(hid > 0 && open > 0, "some of the Rebels are under the net, some in the open");
      assert.equal(hidSeen, 0, "the ones under the net aren't seen");
      assert.equal(openSeen, open, "the ones in the open are");
    },
  },
  {
    scenario: "guns",
    seed: 1,
    secs: 60,
    does: "every machine-gun nest and trench bay is crewed, and both sides' guns hit what's in front of them",
    check: async (f) => {
      f.atLeast("manned", 8, "all eight guns have a gunner");
      f.atLeast(/^t0_hit_by_pkm@/, 1, "the Rebel guns hit the Coalition squad");
      f.atLeast(/^t1_hit_by_mg_gunner@/, 1, "the Coalition guns hit the Rebel cell");
    },
  },
  {
    scenario: "works",
    seed: 1,
    secs: 10,
    does: "every defensive work stands finished in its row, and stays standing",
    begin: async (f) => {
      f.before = new Map((await f.structures()).map((s) => [s.id, s]));
    },
    check: async (f) => {
      const works = (await f.structures()).filter((s) => WORKS.includes(s.kind));
      for (const kind of WORKS) assert.ok(works.some((s) => s.kind === kind), `there's a ${kind}`);
      for (const s of works) {
        assert.ok(s.built && !s.wrecked, `the ${s.kind} (team ${s.team}) is finished and whole`);
        assert.equal(s.hp, f.before.get(s.id)?.hp, `the ${s.kind} (team ${s.team}) took no damage`);
      }
    },
  },
  {
    scenario: "showroom",
    seed: 1,
    secs: 10,
    does: "the showroom's vehicles stay parked and its buildings stand",
    begin: async (f) => {
      f.parked = await f.vehicles();
    },
    check: async (f) => {
      for (const v of f.parked.filter((v) => v.kind !== "truck")) {
        const [now] = await f.vehicles({ ids: [v.id] });
        assert.ok(now && dist(now.pos, v.pos) < 1, `the ${v.kind} is still parked`);
      }
      const kinds = new Set((await f.structures()).map((s) => s.kind));
      for (const k of ["barracks", "research", "factory", "medic_tent", "bunker", "hmg_nest", "mortar_pit", "watchtower", "trench", "wreck"]) {
        assert.ok(kinds.has(k), `there's a ${k}`);
      }
    },
  },
  {
    scenario: "poses",
    seed: 1,
    secs: 12,
    every: 2,
    does: "every man in the pose gallery holds his pose: nobody moves, nobody is hurt",
    during: async (f, t) => {
      // (as they're struck: the ones posed lying dead go down in the first frames)
      if (t === 2) f.posed = await f.soldiers();
    },
    check: async (f) => {
      assert.ok(f.posed.length >= 40, `the gallery is full (${f.posed.length})`);
      const now = new Map((await f.soldiers()).map((s) => [s.id, s]));
      for (const s of f.posed) {
        const n = now.get(s.id);
        assert.ok(n, `man ${s.id} is still there`);
        assert.ok(dist(n.pos, s.pos) < 0.05, `man ${s.id} stayed put (moved ${dist(n.pos, s.pos).toFixed(2)} m)`);
        assert.equal(n.life, s.life, `man ${s.id} is as he was`);
        assert.equal(n.hp, s.hp, `man ${s.id} wasn't hurt`);
      }
    },
  },
]);


test("a soldier caught in a fire is burned and flees while a distant soldier stays safe", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://tests/fixtures/fire-escape.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error/);
  assert.match(stdout, /FIRE_ESCAPE passed/);
});
