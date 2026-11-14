// Pure report-contract checks. These do not launch Godot or measure a GPU.
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { assertCinematicCoverage } from "./lib/gpu-bench-report.mjs";

// Read the actual preset keys so adding an unaccounted setting still fails.
const settings = fs.readFileSync(new URL("../scripts/autoload/settings.gd", import.meta.url), "utf8");
const keys = JSON.parse(settings.match(/const CINEMATIC_KEYS := (\[[^\n]+\])/)[1]);
const report = () => ({
  scope: "stationary", battle_time_start: 1, battle_time_end: 1,
  cinematic_keys: keys,
  settings: [...keys.filter((key) => key !== "time_passes"), "cloud_shadows", "scale"].map((key) => ({ key })),
  unmeasured_settings: [{
    key: "time_passes", requires: "advancing_battle_clock",
    reason: "The battle clock is held still; relighting needs advancing battle time.",
  }],
});

test("stationary coverage explicitly leaves advancing-clock cost unmeasured", () => {
  assertCinematicCoverage(report());
});

test("stationary coverage still rejects every missing priced setting", () => {
  for (const { key } of report().settings) {
    const missing = report();
    missing.settings = missing.settings.filter((s) => s.key !== key);
    assert.throws(() => assertCinematicCoverage(missing), new RegExp(`${key} was priced`));
  }
});

test("stationary coverage rejects unreviewed exemptions and invented clock prices", () => {
  const missing = report();
  missing.unmeasured_settings = [];
  assert.throws(() => assertCinematicCoverage(missing));
  const extra = report();
  extra.unmeasured_settings.push({ key: "lens", reason: "not measured" });
  assert.throws(() => assertCinematicCoverage(extra));
  const priced = report();
  priced.settings.push({ key: "time_passes", cost_ms: 0 });
  assert.throws(() => assertCinematicCoverage(priced), /cannot price Time passes/);
  const silent = report();
  silent.unmeasured_settings[0].reason = "";
  assert.throws(() => assertCinematicCoverage(silent));
});

test("stationary coverage rejects an advancing clock, duplicates and unknown Cinematic keys", () => {
  const moving = report();
  moving.battle_time_end += 1;
  assert.throws(() => assertCinematicCoverage(moving), /clock was held/);
  const duplicate = report();
  duplicate.settings.push(duplicate.settings[0]);
  assert.throws(() => assertCinematicCoverage(duplicate), /only once/);
  const added = report();
  added.cinematic_keys = [...keys, "future_setting"];
  assert.throws(() => assertCinematicCoverage(added), /future_setting was priced/);
});
