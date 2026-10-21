// What each air, sea and support scenario (mapgen.gd scenario()) is there to
// show, as an expectation: run with its seed, it must still happen. See
// lib/expect.mjs for how a row works, and docs/DEVELOPMENT.md ("Scenario
// expectations") for how to add one.

import assert from "node:assert/strict";
import { scenarioTests, out, fighting, dist } from "./lib/expect.mjs";

scenarioTests([
  {
    scenario: "air",
    seed: 1,
    secs: 45,
    does: "a gunship takes on an AA truck, a technical and two fighter cells, and comes through",
    check: async (f) => {
      f.atLeast(/^t1_hit_by_gunship_/, 1, "its guns and rockets hit");
      const [gunship] = await f.vehicles({ kind: "gunship" });
      assert.ok(gunship && gunship.hp > 0, "it's still flying");
      assert.ok(gunship.hp < gunship.max_hp, "though the AA truck hit it");
      const rebels = (await f.vehicles({ team: 1 })).filter((v) => v.kind !== "truck");
      assert.deepEqual(rebels.map((v) => v.kind), [], "the AA truck and the technical are destroyed");
      const cells = await f.soldiers({ team: 1 });
      assert.ok(cells.filter(fighting).length <= 2, `the cells are broken (${cells.filter(fighting).length} still fighting)`);
    },
  },
  {
    scenario: "support",
    seed: 1,
    secs: 30,
    does: "an airstrike falls on the Rebel cells, and the Coalition squad gets out from under a barrage",
    check: async (f) => {
      f.atLeast("support_airstrike", 1, "the airstrike came in");
      f.atLeast("support_barrage", 1, "the barrage came in");
      const rebels = await f.soldiers({ team: 1 });
      assert.ok(rebels.filter(out).length >= 3, `the airstrike hit them (${rebels.filter(out).length} out of the fight)`);
      f.atLeast("displace", 1, "the squad moved out from under the shells");
      const squad = await f.soldiers({ team: 0 });
      assert.equal(squad.filter((s) => s.life === "DEAD").length, 0, "and lost nobody");
    },
  },
  {
    scenario: "recon",
    seed: 1,
    secs: 30,
    does: "eyes on: a lookout goes up the tower, a recon pass photographs the cells, the Rebel spotters come on station",
    check: async (f) => {
      f.atLeast("tower_manned", 1, "a man went up the watchtower");
      f.atLeast("support_gryphon_recon", 1, "the recon pass flew");
      f.atLeast("recon_photo", 1, "and photographed what it passed over");
      f.atLeast("support_caesar_spotter", 1, "the Rebel spotter plane came over");
      f.atLeast("support_fenghuang_watch", 1, "and their drone");
    },
  },
  {
    scenario: "heli",
    seed: 1,
    secs: 50,
    does: "a helipad builds a supply helicopter, and it flies a load to the FOB",
    check: async (f) => {
      const helis = await f.vehicles({ kind: "heli", team: 0 });
      assert.equal(helis.length, 1, "the helicopter was built");
      f.atLeast("heli_delivered", 1, "and delivered");
    },
  },
  {
    scenario: "sling",
    seed: 1,
    secs: 45,
    does: "a Mohawk and a Taru each carry a vehicle 150 m on the sling and set it down where sent",
    check: async (f) => {
      f.atLeast("sling_hooked", 2, "both hooked on");
      f.atLeast("sling_delivered", 2, "both set down");
      const [humvee] = await f.vehicles({ kind: "humvee" });
      const [btr] = await f.vehicles({ kind: "btr" });
      assert.ok(dist(humvee.pos, [-60, -120]) < 10, `the Humvee is where the Mohawk was sent (at ${humvee.pos})`);
      assert.ok(dist(btr.pos, [220, 60]) < 10, `the BTR is where the Taru was sent (at ${btr.pos})`);
      assert.equal(humvee.hp, humvee.max_hp, "the Humvee came down in one piece");
      assert.equal(btr.hp, btr.max_hp, "and the BTR");
    },
  },
  {
    scenario: "naval",
    seed: 1,
    secs: 60,
    does: "boats on the sea: the patrol ship sinks the Rebel boats, the RHIB lands its squad",
    check: async (f, t) => {
      await t.test("the patrol ship sinks the Rebel boats and stays afloat", async () => {
        f.atLeast("boat_sunk", 2, "both Rebel boats went down");
        const boats = (await f.vehicles({ team: 1 })).filter((v) => v.kind !== "truck");
        assert.deepEqual(boats.map((v) => v.kind), [], "no Rebel boat is left");
        const [ship] = await f.vehicles({ kind: "patrol_ship" });
        assert.ok(ship && ship.hp > 0, "the patrol ship is afloat");
      });
      await t.test("the RHIB lands its squad on the beach", async () => {
        f.atLeast("dismount", 1, "the squad got out");
        const ashore = (await f.soldiers({ team: 0 })).filter((s) => s.life === "ALIVE" && s.riding === 0);
        assert.ok(ashore.length >= 3, `the squad is ashore (${ashore.length} of 5)`);
      });
    },
  },
  {
    scenario: "tunnel",
    seed: 1,
    secs: 25,
    does: "a fighter cell goes down one tunnel and comes up out of the other, 90 m away",
    check: async (f) => {
      f.atLeast("tunnel_in", 6, "all six went in");
      const cell = await f.soldiers({ team: 1 });
      assert.ok(cell.every((s) => s.life === "ALIVE"), "they all came out again");
      for (const s of cell) assert.ok(dist(s.pos, [30, 10]) < 12, `at the far tunnel (one is at ${s.pos})`);
    },
  },
]);
