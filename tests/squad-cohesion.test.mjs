import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { Game, ROOT, v3 } from "./lib/game.mjs";

const run = promisify(execFile);

test("the whole squad stacks behind one wall during contact", async (t) => {
  const game = await Game.start();
  t.after(() => game.close());
  await game.load({ scenario: "lean", seed: 2 });
  await game.step(12);
  const { soldiers } = await game.query("soldiers", { team: 0 });
  const men = soldiers.filter((s) => s.life === "ALIVE");
  assert.equal(men.length, 5);
  for (const man of men) {
    assert.ok(Math.abs(man.pos[0]) < 3.5, "every soldier stays within the middle wall's width");
    assert.ok(man.pos[1] > -10 && man.pos[1] < -6.5, "every soldier shelters within a pace of the front row");
  }
  assert.equal(game.errors, 0);
});

test("squad formations remain compact and on the same side of walls", async () => {
  const { stdout, stderr } = await run(process.env.GODOT || "godot", [
    "--headless", "--path", ROOT, "res://scripts/test/squad_cohesion_test.tscn",
  ], { timeout: 120_000, maxBuffer: 2 * 1024 * 1024 });
  assert.match(stdout, /SQUADCOHESION \d+ checks, 0 failures/);
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|TESTRUN failed/);
});


test("moving squads stay together and arrive as a compact group", async (t) => {
  const game = await Game.start();
  t.after(() => game.close());
  for (const seed of [3, 7]) {
    await game.load({ scenario: "attack", seed, static: true });
    const { squads } = await game.query("squads", { team: 0, kind: "rifle_squad" });
    const squad = squads[0];
    await game.order(0, "move", { squads: [squad.id], pos: v3(-40, 20) });
    for (let elapsed = 2; elapsed <= 40; elapsed += 2) {
      await game.step(2);
      const { soldiers } = await game.query("soldiers", { team: 0 });
      const men = soldiers.filter((s) => s.squad === squad.id && s.life === "ALIVE");
      assert.equal(men.length, squad.alive, "the quiet flank keeps the whole squad available");
      for (const a of men) for (const b of men) {
        const distance = Math.hypot(a.pos[0] - b.pos[0], a.pos[1] - b.pos[1]);
        assert.ok(distance < 16, `seed ${seed}, t=${elapsed}: squad split by ${distance.toFixed(1)} m`);
      }
      if (elapsed === 40) for (const man of men) {
        assert.ok(Math.hypot(man.pos[0] + 40, man.pos[1] - 20) < 7, "every man reaches the destination circle");
      }
    }
    assert.equal(game.errors, 0);
  }
});
