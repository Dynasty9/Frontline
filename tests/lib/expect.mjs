// Expectations for whole scenarios: a table of what each small setup is for,
// run one after another in a single game (startup is the slow part; each load
// is a fresh battle, so they can't see each other). Each row loads its
// scenario with a seed, steps it, and checks what must have happened by then:
//
//   scenarioTests([
//     {
//       scenario: "breach",       // mapgen.gd scenario()
//       seed: 1,                  // the same fight every run
//       secs: 45,                 // game time to run it for
//       does: "the fighter cell in the house is cleared out", // the test's name
//       check: async (f) => {
//         assert.ok(f.n("room_entry") >= 1, "they went in through the door");
//         assert.ok((await f.soldiers({ team: 1 })).every(out), "the cell is dead or has given up");
//       },
//     },
//   ]);
//
// Optional: `load` (more load fields, e.g. { static: true }), `begin(f)` (a
// look at the field as it's laid out, before time moves), `every` and
// `during(f, t)` (a look every so many seconds on the way, for what doesn't
// leave a counter behind; call f.update() there for the counters so far),
// `todo` (a known failure, and why). The hooks can keep what they saw on `f`.
// `check` gets the test context too, for subtests that are todo on their own.
// Every row also fails on a script error during it.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game } from "./game.mjs";

/** A man out of the fight: dead, given up, taken prisoner, or down and bleeding. */
export const out = (s) => s.life !== "ALIVE" && s.life !== "HIDDEN";
/** A man still fighting (or hidden in a building, a vehicle or a tunnel). */
export const fighting = (s) => !out(s);
/** Distance on the ground between two [x, z] points. */
export const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);

/** What a row's check sees: the counters at the end, and queries of the field. */
export class Field {
  /** Every behaviour counter (world.stat) so far. */
  counters = {};
  t = 0;

  constructor(game) {
    this.game = game;
  }

  async update() {
    const r = await this.game.stats();
    this.counters = r.counters;
    this.t = r.t;
    return this;
  }

  /** A counter: how often that behaviour happened (0 if it never did). */
  n(key) {
    return Number(this.counters[key] ?? 0);
  }

  /** All the counters whose names match, added up (e.g. /^fire_/). */
  sum(re) {
    let n = 0;
    for (const [k, v] of Object.entries(this.counters)) if (re.test(k)) n += Number(v);
    return n;
  }

  /** That a behaviour happened at least `min` times (a counter, or a pattern of them). */
  atLeast(key, min, why) {
    const n = key instanceof RegExp ? this.sum(key) : this.n(key);
    assert.ok(n >= min, `${why}: ${key} = ${n}, wanted at least ${min}`);
  }

  /** That a behaviour never happened. */
  never(key, why) {
    const n = key instanceof RegExp ? this.sum(key) : this.n(key);
    assert.equal(n, 0, `${why}: ${key} = ${n}`);
  }

  async soldiers(filters = {}) {
    return (await this.game.query("soldiers", filters)).soldiers;
  }

  async vehicles(filters = {}) {
    return (await this.game.query("vehicles", filters)).vehicles;
  }

  async squads(filters = {}) {
    return (await this.game.query("squads", filters)).squads;
  }

  async structures(filters = {}) {
    return (await this.game.query("structures", filters)).structures;
  }
}

/** Registers one test per row, all played in one game started for the file. */
export function scenarioTests(rows) {
  let game;
  before(async () => {
    game = await Game.start();
  });
  after(async () => {
    if (game) assert.equal(await game.close(), 0, "the game's exit code");
  });
  for (const row of rows) {
    test(`${row.scenario}: ${row.does}`, { todo: row.todo }, async (t) => {
      const errors = game.errors;
      await game.load({ scenario: row.scenario, seed: row.seed, ...row.load });
      const f = new Field(game);
      if (row.begin) await row.begin(f);
      const every = row.during ? (row.every ?? 1) : row.secs;
      for (let at = 0; at < row.secs - 1e-6; ) {
        const dt = Math.min(every, row.secs - at);
        await game.step(dt);
        at += dt;
        if (row.during) await row.during(f, at);
      }
      await f.update();
      if (game.errors > errors) {
        const { recent } = await game.scriptErrors();
        assert.fail(`${game.errors - errors} script error(s) in the run:\n${recent.join("\n")}`);
      }
      await row.check(f, t);
    });
  }
}
