import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { Game, ROOT } from "./lib/game.mjs";

test("complete Rust infantry checkpoints retain pending work and safely reject malformed state", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--quit-after", "2", "--path", ROOT, "res://tests/fixtures/infantry-state.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|ERROR:|panicked/);
  assert.match(stdout, /INFANTRY_STATE passed actors=256 removed=5/);
});

test("Rust actor checkpoints retain real battle state without changing the running simulation", async () => {
  const game = await Game.start();
  try {
    for (const scenario of ["attack", "breach", "trenches", "gdrill", "fire", "tank", "naval", "tunnel", "defense", "guns", "recon"]) {
      await game.load({ scenario, seed: 3 });
      for (const seconds of [0, 10, 20]) {
        if (seconds) await game.step(seconds);
        const before = await game.hash();
        const checkpoint = await game.send("infantry_checkpoints");
        assert.ok(checkpoint.actors > 0, scenario);
        assert.ok(checkpoint.bytes > checkpoint.actors * 100, scenario);
        const squads = await game.send("squad_checkpoints");
        assert.ok(squads.squads > 0, scenario);
        assert.ok(squads.bytes > squads.squads * 100, scenario);
        const structures = await game.send("structure_checkpoints");
        assert.ok(structures.structures > 0, scenario);
        assert.ok(structures.bytes > structures.structures * 100, scenario);
        assert.equal(await game.hash(), before, `Capturing ${scenario} must not alter the battle`);
      }
    }
    await game.load({ scenario: "stress", map_size: 2048, units: 500, scenery: 200, seed: 3 });
    const before = await game.hash();
    assert.equal((await game.send("infantry_checkpoints")).actors, 500);
    assert.ok((await game.send("squad_checkpoints")).squads > 0);
    assert.ok((await game.send("structure_checkpoints")).structures > 0);
    assert.equal(await game.hash(), before);
    await game.load({ scenario: "attack", seed: 3, map_size: 1024 });
    assert.ok((await game.send("infantry_checkpoints")).actors > 0);
    await game.step(1);
    assert.equal(game.errors, 0, game.output.join("\n"));
  } finally {
    assert.equal(await game.close(), 0, game.output.join("\n"));
  }
});
