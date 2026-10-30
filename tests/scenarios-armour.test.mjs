// What each armour scenario (mapgen.gd scenario()) is there to show, as an
// expectation: run with its seed, it must still happen. See lib/expect.mjs for
// how a row works, and docs/DEVELOPMENT.md ("Scenario expectations") for how to
// add one.

import assert from "node:assert/strict";
import { scenarioTests, out, fighting, dist } from "./lib/expect.mjs";

scenarioTests([
  {
    scenario: "tank",
    seed: 1,
    secs: 45,
    does: "a tank drives through an RPG team and a fighter cell, takes their rockets and breaks them",
    check: async (f) => {
      f.atLeast("at_hit", 1, "the RPGs hit it");
      f.atLeast("cannon", 3, "it fired its gun");
      const [tank] = await f.vehicles({ kind: "tank" });
      assert.ok(tank && tank.hp > 0, "and came through");
      const rebels = await f.soldiers({ team: 1 });
      // Survivors who withdrew out of contact are also a broken attack.
      const fightingHere = rebels.filter((s) => fighting(s) && dist(s.pos, tank.pos) < 50);
      assert.ok(fightingHere.length <= 1, `the Rebels no longer contest the tank (${fightingHere.length} still in contact)`);
      assert.ok(rebels.filter(out).length >= rebels.length / 2, "the RPG team and cell suffered heavy losses");
    },
  },
  {
    scenario: "drone",
    seed: 1,
    secs: 60,
    does: "an FPV team sends drones at a tank: one gets through, and the squad beside it shoots one down",
    check: async (f) => {
      f.atLeast("drone_launch", 2, "drones went up");
      f.atLeast("drone_boom", 1, "one struck");
      f.atLeast("drone_shot_down", 1, "the riflemen shot one down");
      const [tank] = await f.vehicles({ kind: "tank" });
      assert.ok(tank.hp < tank.max_hp, `the tank was hit (${tank.hp} of ${tank.max_hp})`);
    },
  },
  {
    scenario: "defense",
    seed: 1,
    secs: 90,
    does: "a dug-in position, crewed, holds off three fighter cells, a technical and an old tank",
    check: async (f) => {
      f.atLeast("manned", 3, "the crews got on their guns");
      f.atLeast("mortar_round", 1, "the mortar fired");
      f.atLeast("at_launch", 1, "the AT post fired at the armour");
      const armour = (await f.vehicles({ team: 1 })).filter((v) => v.kind !== "truck");
      assert.ok(armour.every((v) => v.hp < v.max_hp * 0.5 && v.pos[1] < -70),
        "enemy armour is destroyed or badly damaged and driven back beyond the attack");
      // The works occupy x=-20..18. A withdrawn/flanking cell 75 m west
      // is outside the position even if it crosses the front trench's z line.
      const inside = (await f.soldiers({ team: 1 })).filter((s) => fighting(s) && Math.abs(s.pos[0]) < 35 && s.pos[1] > -15);
      assert.equal(inside.length, 0, "no Rebel got into the position");
      const lost = (await f.soldiers({ team: 0 })).filter(out).length;
      assert.ok(lost <= 5, `the defenders held on (${lost} of 16 lost)`);
    },
  },
  {
    scenario: "trenches",
    seed: 2,
    secs: 90,
    does: "tanks, IFVs and two rifle squads assault a Rebel trench system and break into it",
    check: async (f) => {
      f.atLeast("plan_assault", 1, "the infantry put in an assault");
      f.atLeast("cannon", 10, "the tanks shelled the trenches");
      f.atLeast("dismount", 1, "the IFVs dropped their squads");
      const tanks = await f.vehicles({ kind: "tank" });
      assert.ok(tanks.some((v) => v.pos[1] < -15), `a tank got up to the front trench (tanks at ${tanks.map((v) => v.pos).join(" ")})`);
      const rebels = await f.soldiers({ team: 1 });
      assert.ok(rebels.filter(out).length >= 8, `the defenders lost half their men (${rebels.filter(out).length} of ${rebels.length})`);
    },
  },
  {
    scenario: "roster",
    seed: 1,
    secs: 20,
    does: "every vehicle both sides field takes the field at once, and each kind of weapon gets used",
    check: async (f) => {
      f.atLeast("cannon", 10, "the tanks and IFVs fired");
      f.atLeast("at_hit", 10, "anti-tank weapons hit");
      f.atLeast("veh_atgm", 1, "a guided missile was fired");
      f.atLeast("veh_sam", 1, "an anti-aircraft missile was fired");
      f.atLeast("arty_mission", 1, "the artillery fired");
      f.atLeast("dismount", 5, "the carriers dropped their squads");
      f.atLeast("veh_repaired", 1, "a repair truck patched a vehicle up");
      for (const team of [0, 1]) {
        const lost = (await f.soldiers({ team })).filter(out).length;
        assert.ok(lost >= 5, `both sides lost men (team ${team}: ${lost})`);
      }
    },
  },
]);
