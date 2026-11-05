import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ROOT } from "./lib/game.mjs";

test("Rust cover evaluation preserves protection, lean, prone and firing lanes", async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || "godot", [
    "--headless", "--quit-after", "600", "--path", ROOT, "res://tests/fixtures/native-cover.tscn",
  ], { timeout: 120_000 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|ERROR:/);
  assert.match(stdout, /NATIVE_COVER passed queries=3000/);
  assert.match(stdout, /NATIVE_COVER_GENERATION passed structures=400/);
});
