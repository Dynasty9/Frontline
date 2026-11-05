import { test } from "node:test";
import assert from "node:assert/strict";
import { runFixture } from "./lib/fixture.mjs";

test("Rust automatic grenades preserve contact scores, scatter, ammo, cooldowns and cooking", async () => {
  const stdout = await runFixture("grenade-attack");
  assert.match(stdout, /GRENADE_ATTACK passed decisions=12288 mortar_memory=65/);
});
