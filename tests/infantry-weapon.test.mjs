import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { Game, ROOT } from "./lib/game.mjs";

test("Rust infantry cover fire preserves peeking, reloads, buddy cover and randomness", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--quit-after", "2", "--path", ROOT, "res://tests/fixtures/infantry-weapon.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|ERROR:|panicked/);
  assert.match(stdout, /INFANTRY_WEAPON passed steps=168960/);
  assert.match(stdout, /INFANTRY_SHOTS rounds=/);
});

test("Rust infantry ports preserve battle fingerprints and events", async () => {
  const game = await Game.start();
  try {
    for (const scenario of ["attack", "breach", "trenches", "fire", "tank", "gdrill", "naval", "tunnel", "defense", "guns", "recon"]) {
      const runs = [];
      for (const native of [false, true]) {
        const loaded = await game.load({ scenario, seed: 3, rust_infantry: native, gdscript_cover_search: !native, gdscript_entity_registry: !native });
        assert.equal(loaded.rust_infantry, native);
        assert.equal(loaded.rust_entities, native);
        const samples = [];
        for (let t = 0; t < 60; t += 15) {
          await game.step(15);
          samples.push({ hash: await game.hash(), counters: (await game.stats()).counters });
        }
        assert.equal(game.errors, 0, game.output.join("\n"));
        runs.push(samples);
      }
      assert.deepEqual(runs[1], runs[0], `${scenario}: Rust and GDScript infantry behavior`);
    }
  } finally {
    assert.equal(await game.close(), 0);
  }
});
