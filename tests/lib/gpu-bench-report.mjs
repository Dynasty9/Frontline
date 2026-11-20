import assert from "node:assert/strict";

// Only the moving clock is outside this stationary harness. A new Cinematic
// setting must still be priced; an arbitrary exemption cannot hide a regression.
export function assertCinematicCoverage(report) {
  assert.equal(report.scope, "stationary");
  assert.ok(Number.isFinite(report.battle_time_start));
  assert.equal(report.battle_time_end, report.battle_time_start, "the battle clock was held throughout");
  const priced = new Set(report.settings.map((s) => s.key));
  assert.equal(priced.size, report.settings.length, "settings are priced only once");
  assert.deepEqual(report.unmeasured_settings.map((s) => s.key), ["time_passes"]);
  const dynamic = report.unmeasured_settings[0];
  assert.equal(dynamic.requires, "advancing_battle_clock");
  assert.match(dynamic.reason, /battle clock.*held still/);
  assert.match(dynamic.reason, /advancing battle time/);
  assert.ok(!priced.has("time_passes"), "a held clock cannot price Time passes");
  assert.ok(report.cinematic_keys.includes("time_passes"), "Time passes remains a Cinematic setting");
  for (const key of [...report.cinematic_keys, "cloud_shadows", "scale"]) {
    if (key !== "time_passes") assert.ok(priced.has(key), `${key} was priced`);
  }
}
