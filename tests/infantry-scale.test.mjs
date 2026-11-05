import { test } from "node:test";
import assert from "node:assert/strict";
import { Game } from "./lib/game.mjs";

async function compareBattle(settings, seconds, interval) {
  const game = await Game.start();
  try {
    const runs = [];
    for (const native of [false, true]) {
      const loaded = await game.load({ ...settings, seed: 3, rust_infantry: native,
        gdscript_cover_search: !native, gdscript_entity_registry: !native });
      assert.equal(loaded.rust_infantry, native);
      assert.equal(loaded.rust_entities, native);
      if (settings.units) assert.equal(loaded.soldiers, settings.units);
      const samples = [{ hash: await game.hash(), counters: (await game.stats()).counters }];
      for (let t = 0; t < seconds; t += interval) {
        await game.step(interval);
        samples.push({ hash: await game.hash(), counters: (await game.stats()).counters });
      }
      assert.equal(game.errors, 0, game.output.join("\n"));
      runs.push(samples);
    }
    assert.deepEqual(runs[1], runs[0], "Rust and GDScript infantry battle state and events");
  } finally {
    assert.equal(await game.close(), 0);
  }
}

test("Rust infantry ports preserve a generated battle with commanders for 120 seconds", () =>
  compareBattle({ battle: true }, 120, 30));

test("Rust infantry ports preserve 500 soldiers fighting on a 2048 m map", () =>
  compareBattle({ scenario: "stress", map_size: 2048, units: 500, scenery: 200 }, 30, 10));
