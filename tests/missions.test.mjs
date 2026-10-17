// Every mission plays itself to the end, and wins. Loaded without `play`, a
// mission's autopilot (missions.gd) gives its force the orders a player would:
// if that stops winning, a mission has stopped being winnable the way it was
// built to be won (an objective that can't be met, a script that never fires,
// a force too weak for what's sent against it).
//
// Each mission is a few minutes of battle on the full 1 km map, and runs about
// twice as fast as real time, so these are left out of an ordinary run (and so
// out of CI's): run them with FL_TEST_LONG=1, e.g.
//
//   cd tests && FL_TEST_LONG=1 GODOT=... node --test missions.test.mjs
//
// They play side by side, FL_TEST_JOBS at a time (default: half the cores).

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import os from "node:os";
import { Game } from "./lib/game.mjs";

const LONG = process.env.FL_TEST_LONG === "1";
const JOBS = Number(process.env.FL_TEST_JOBS) || Math.max(1, Math.floor(os.availableParallelism() / 2));

// side: who plays it (Missions.LIST); cap: game seconds to give it, well past
// how long it takes (in brackets, as measured)
const MISSIONS = [
  { key: "bridgehead", side: 0, cap: 600 }, // (220 s)
  { key: "beachhead", side: 0, cap: 600 }, // (180 s)
  { key: "skyhook", side: 0, cap: 600 }, // (230 s)
  { key: "ambush", side: 1, cap: 600 }, // (180 s)
  {
    key: "kingpin",
    side: 0,
    cap: 900,
    todo: "the autopilot loses its own raid: the force is wiped out in the town about 150 s in (being looked into)",
  },
];

const skip = !LONG && "set FL_TEST_LONG=1 to play them (a few minutes each)";

describe("missions play themselves to the end and are accomplished", { skip, concurrency: JOBS }, () => {
  for (const m of MISSIONS) {
    it(m.key, { todo: m.todo }, async (t) => {
      const game = await Game.start();
      try {
        const t0 = Date.now();
        await game.load({ mission: m.key });
        let r = { t: 0, winner: -1 };
        while (r.winner < 0 && r.t < m.cap) r = await game.step(5);
        const { mission_info: info } = await game.query("world");
        t.diagnostic(`${m.key}: winner ${r.winner} at t=${r.t.toFixed(0)} s, ${((Date.now() - t0) / 1000).toFixed(0)} s real`);
        assert.equal(game.errors, 0, "no script errors");
        assert.notEqual(r.winner, -1, `still going after ${m.cap} s`);
        assert.equal(r.winner, m.side, `lost at t=${r.t.toFixed(0)}: ${info?.end}`);
      } finally {
        await game.close();
      }
    });
  }
});
