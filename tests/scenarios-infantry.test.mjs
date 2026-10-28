// What each infantry scenario (mapgen.gd scenario()) is there to show, as an
// expectation: run with its seed, it must still happen. See lib/expect.mjs for
// how a row works, and docs/DEVELOPMENT.md ("Scenario expectations") for how to
// add one.

import assert from "node:assert/strict";
import { scenarioTests, fighting, dist } from "./lib/expect.mjs";

scenarioTests([
  {
    scenario: "attack",
    seed: 1,
    // Compact defenders hold cover longer before the assault can go in.
    secs: 120,
    does: "two squads and a gun team plan an attack on the walled yard, carry it and win",
    check: async (f) => {
      f.atLeast("plan_assault", 1, "the plan got to the assault");
      f.atLeast("plan_won", 1, "and they won it");
      f.atLeast("t0_hits", 1, "they hit the enemy");
      const cell = await f.soldiers({ team: 1 });
      assert.equal(cell.filter(fighting).length, 0, "nobody in the yard is still fighting");
    },
  },
  {
    scenario: "solo",
    seed: 1,
    secs: 60,
    does: "one squad against a stronger position goes firm and fixes it rather than charging",
    check: async (f) => {
      f.atLeast("plan_move", 1, "it planned the attack (Alpha to fix, Bravo round the flank)");
      f.atLeast("plan_fix", 1, "outnumbered, it went firm to fix them");
      f.never("plan_assault", "it didn't throw itself at them");
      // Fixing is the decision under test; survival and volley count vary with cover.
      f.atLeast("t0_shots", 1, "it returned fire");
      assert.ok((await f.soldiers({ team: 0 })).every((s) => s.pos[1] > -20), "the squad stayed short of the defenders instead of charging");
    },
  },
  {
    scenario: "breach",
    seed: 3,
    secs: 60,
    does: "two squads and a gun team breach the house and clear the fighter cell out of it",
    check: async (f) => {
      f.atLeast("breach", 1, "they stacked up on the house");
      f.atLeast(/^(door_kicked|breach_door_kick)$/, 1, "and kicked the door in");
      f.atLeast("room_entry", 1, "and went in room by room");
      f.atLeast("house_cleared", 1, "and called the house clear");
      const cell = await f.soldiers({ team: 1 });
      assert.equal(cell.filter(fighting).length, 0, "nobody in the house is still fighting");
    },
  },
  {
    scenario: "tactics",
    seed: 1,
    secs: 75,
    does: "a squad and a gun team bound 80 m up to a hamlet by teams and clear its houses",
    check: async (f) => {
      f.atLeast("bounding", 1, "they bounded, one team covering the other");
      f.atLeast("house_cleared", 1, "they entered and cleared an unoccupied house");
      const houses = await f.structures({ kind: "floor" });
      const secured = new Set((await f.squads({ team: 0 })).flatMap((s) => s.cleared_houses));
      assert.equal(houses.length, 2, "both houses are present");
      assert.ok(houses.every((h) => secured.has(h.id)), "both houses were checked or already occupied by friendlies");
      const [rifles] = await f.squads({ kind: "rifle_squad" });
      const [guns] = await f.squads({ kind: "mg_team" });
      assert.ok(dist(rifles.pos, [0, -80]) < 10, `the squad is in the hamlet (at ${rifles.pos})`);
      assert.ok(dist(guns.pos, [14, -76]) < 12, `the gun team is in the hamlet (at ${guns.pos})`);
    },
  },
  {
    scenario: "cover",
    seed: 1,
    secs: 60,
    does: "a squad fighting from behind walls, crates and a car is kept alive by its cover",
    check: async (f) => {
      f.atLeast("t1_blocked", 20, "the cover stopped the enemy's rounds");
      f.atLeast("t0_peek", 10, "the men came up from behind it to shoot");
      f.atLeast("t0_shots", 20, "they kept returning fire from cover");
      f.atLeast("t0_hits", 1, "and hit back");
      const squad = await f.soldiers({ team: 0 });
      assert.ok(squad.filter((s) => s.life === "DEAD").length <= 1, "it lost no more than a man");
    },
  },
  {
    scenario: "lean",
    seed: 2,
    secs: 30,
    every: 2,
    does: "men behind tall walls lean out round the ends to fire, this way and that",
    during: async (f) => {
      f.leans ??= [];
      const leaning = (await f.soldiers({ team: 0 })).filter((s) => s.life === "ALIVE" && s.posture.startsWith("LEAN"));
      if (leaning.length) f.leans.push(...leaning.map((s) => s.posture));
    },
    check: async (f) => {
      assert.ok(f.leans.length >= 5, `they leant out again and again (seen ${f.leans.length} times)`);
      assert.ok(f.leans.includes("LEAN_L") && f.leans.includes("LEAN_R"), "round the left end and the right");
      f.atLeast("t0_hits", 1, "and hit what they fired at");
    },
  },
  {
    scenario: "grenade",
    // Both groups reach grenade range; the winner is not part of this drill.
    seed: 1,
    secs: 45,
    does: "grenades fly over the low walls, and the men they land among dive or throw them back",
    check: async (f) => {
      f.atLeast("frag_auto", 2, "grenades were thrown");
      f.atLeast("dive", 5, "men dived away from them");
      // Handling live grenades is checked across three deliberate drills below.
    },
  },
  {
    scenario: "gdrill",
    seed: 1,
    secs: 60,
    does: "frags landing among a squad round its wounded set off every reflex: dive, kick, throw back, smother",
    check: async (f) => {
      f.atLeast("dive", 5, "men dived away");
      const kinds = ["grenade_kick", "throwback", "smother"];
      const reflexes = new Set(kinds.filter((k) => f.n(k) > 0));
      for (const seed of [2, 3]) {
        await f.game.load({ scenario: "gdrill", seed });
        await f.game.step(60);
        const { counters } = await f.game.stats();
        assert.ok(counters.dive >= 5, `seed ${seed}: men dived away`);
        for (const k of kinds) if (counters[k] > 0) reflexes.add(k);
      }
      assert.equal(reflexes.size, kinds.length, `all handling reflexes across three drills (saw ${[...reflexes].join(", ")})`);
      assert.equal(f.game.errors, 0, "the additional drills have no script errors");
    },
  },
]);
