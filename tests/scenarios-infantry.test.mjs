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
      f.atLeast("t0_shots", 20, "it kept them under fire");
    },
  },
  {
    scenario: "breach",
    seed: 1,
    secs: 40,
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
      f.atLeast("house_cleared", 2, "they cleared both houses");
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
      f.atLeast("t0_hits", 5, "and hit back");
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
    // This seed brings the compact groups into grenade range.
    seed: 3,
    secs: 45,
    does: "grenades fly over the low walls, and the men they land among dive or throw them back",
    check: async (f) => {
      f.atLeast("frag_auto", 2, "grenades were thrown");
      f.atLeast("dive", 5, "men dived away from them");
      f.atLeast(/^(grenade_pickup|throwback|grenade_kick)$/, 1, "someone picked one up, threw it back or kicked it away");
    },
  },
  {
    scenario: "gdrill",
    seed: 1,
    secs: 60,
    does: "frags landing among a squad round its wounded set off every reflex: dive, kick, throw back, smother",
    check: async (f) => {
      f.atLeast("dive", 5, "men dived away");
      const reflexes = ["grenade_kick", "throwback", "smother"].filter((k) => f.n(k) > 0);
      assert.ok(reflexes.length >= 2, `more than one way of dealing with a grenade (saw ${reflexes.join(", ") || "none"})`);
    },
  },
]);
