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
  { key: "kingpin", side: 0, cap: 600 }, // (180 s)
];

const skip = !LONG && "set FL_TEST_LONG=1 to play them (a few minutes each)";

describe("missions play themselves to the end and are accomplished", { skip, concurrency: JOBS }, () => {
  for (const m of MISSIONS) {
    it(m.key, { todo: m.todo }, async (t) => {
      const game = await Game.start();
      try {
        const t0 = Date.now();
        await game.load({ mission: m.key, verbose: true });
        const reserves = [];
        const joined = new Set();
        let reaction = null;
        let reactionMoved = false;
        if (m.key === "beachhead") {
          const { mission_info: initial } = await game.query("world");
          const beach = initial.objs.find((o) => o[3] === "reach")[4];
          const { squads } = await game.query("squads", { team: 1 });
          reserves.push(...squads.filter((s) => s.kind === "fighter_cell" && s.pos[0] < beach[0] - 80).map((s) => s.id));
          assert.equal(reserves.length, 2, "both inland infantry reserves exist before the landing");
        }
        let r = { t: 0, winner: -1 };
        while (r.winner < 0 && r.t < m.cap) {
          r = await game.step(5);
          if (m.key === "ambush") {
            const { mission_info: current } = await game.query("world");
            if (current.objs.some((o) => o[1] === "Reaction force moves in" && o[2] === 2)) {
              const { vehicles } = await game.query("vehicles", { team: 0 });
              if (!reaction) reaction = vehicles.filter((v) => v.kind === "hunter_hmg").sort((a, b) => b.id - a.id)[0];
              if (reaction) {
                const v = vehicles.find((v) => v.id === reaction.id);
                if (!v || Math.hypot(v.pos[0] - reaction.pos[0], v.pos[1] - reaction.pos[1]) >= 25) reactionMoved = true;
              }
            }
          }
          if (reserves.length) {
            const { mission_info: current } = await game.query("world");
            const harbour = current.objs.find((o) => o[1] === "Clear the harbour")?.[4];
            if (harbour) {
              const { squads } = await game.query("squads", { team: 1 });
              for (const id of reserves) {
                const s = squads.find((s) => s.id === id);
                if (!s || !s.alive || Math.hypot(s.pos[0] - harbour[0], s.pos[1] - harbour[2]) <= 110) joined.add(id);
              }
            }
          }
        }
        const { mission_info: info } = await game.query("world");
        t.diagnostic(`${m.key}: winner ${r.winner} at t=${r.t.toFixed(0)} s, ${((Date.now() - t0) / 1000).toFixed(0)} s real`);
        assert.equal(game.errors, 0, "no script errors");
        assert.notEqual(r.winner, -1, `still going after ${m.cap} s`);
        assert.equal(r.winner, m.side, `lost at t=${r.t.toFixed(0)}: ${info?.end}`);
        if (m.key === "beachhead") {
          assert.equal(joined.size, reserves.length, "both reserves reach the harbour fight or are defeated on the approach");
        }
        if (m.key === "ambush") {
          assert.ok(reactionMoved, "the ground reaction force advances or is defeated, rather than spawning stuck beyond the road");
          const wipeout = info.objs.find((o) => o[1] === "Destroy all four convoy vehicles");
          assert.equal(wipeout?.[7], true, "the fourth vehicle is an optional risk, not an extraction requirement");
        }
        if (m.key === "bridgehead") {
          for (const text of ["Regroup: cover the bridge and the ford", "Repel the bridge counterattack", "Secure the bridgehead for Lancer"]) {
            assert.equal(info.objs.find((o) => o[1] === text)?.[2], 2, `${text} completed before victory`);
          }
        }
        if (m.key === "skyhook") {
          assert.equal(info.objs.find((o) => o[3] === "deliver")?.[2], 2, "the airlift is completed");
          const column = info.objs.find((o) => o[3] === "destroy");
          assert.equal(column?.[2], 2, "the whole column is destroyed");
          assert.equal(column?.[6], "3/3");
        }
      } finally {
        await game.close();
      }
    });
  }
});
