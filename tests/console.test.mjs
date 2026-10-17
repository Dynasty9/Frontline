// The in-game console (` or ~): its commands answer, the lag diagnosis reads
// the battle's own measures, settings change as Settings would change them,
// and the benchmark puts every setting back when it stops.
//
// Headless, nothing is drawn, so the renderer's numbers are zeros; what's
// checked is that each command runs and says what it should.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game } from "./lib/game.mjs";

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

const has = (out, re) => out.some((l) => re.test(l));

test("every command answers, in the menu and in a battle", async () => {
  const help = await game.console("help");
  for (const c of ["why", "bench", "graph", "top", "hitches", "render", "sys", "set", "report"]) {
    assert.ok(has(help, new RegExp(`^  ${c} `)), `help lists ${c}`);
  }
  assert.ok(has(await game.console("why"), /no battle|Not enough frames|The last/), "why, with no battle");
  assert.ok(has(await game.console("nonsense"), /No command "nonsense"/));

  await game.load({ scenario: "attack", seed: 1 });
  await game.step(3);
  for (const c of ["why", "top", "render", "sys", "net", "hitches", "errors", "graph", "graph", "perf 1", "draw normal"]) {
    const out = await game.console(c);
    assert.ok(out.length > 0, `${c} says something`);
    assert.ok(!has(out, /^No command/), `${c} is a command`);
  }
  assert.ok(has(await game.console("why"), /^The last \d+ seconds: /), "why measures the battle");
  const top = await game.console("top");
  assert.ok(has(top, /^  soldiers +\d+\.\d+/), "top has the soldiers' share of the game logic");
  assert.ok(has(await game.console("net"), /^Offline/));
});

test("set changes a setting, and refuses what it can't be", async () => {
  assert.ok(has(await game.console("set shadows off"), /^shadows: Off \(0\)/));
  assert.ok(has(await game.console("settings shadows"), /^  shadows +Off \(0\)/));
  assert.ok(has(await game.console("set aa msaa_2x"), /^aa: MSAA 2x \(2\)/), "a choice by its name");
  assert.ok(has(await game.console("set scale 77%"), /^scale: 0\.77/), "a percentage");
  assert.ok(has(await game.console("set ssao maybe"), /can't be "maybe": try on, off/));
  assert.ok(has(await game.console("set nothing 1"), /No setting "nothing"/));
  assert.ok(has(await game.console("set shadows high"), /^shadows: High \(2\)/));
});

test("the benchmark puts the settings back when stopped", async () => {
  await game.load({ scenario: "attack", seed: 1 });
  await game.step(2);
  const before = await game.console("settings");
  assert.ok(has(await game.console("bench quick"), /^Benchmarking \d+ things/));
  assert.ok(has(await game.console("set shadows off"), /Not while the benchmark runs/));
  await game.step(1);
  assert.ok(has(await game.console("bench stop"), /settings are back as they were/));
  assert.deepEqual(await game.console("settings"), before, "every setting as it was");
});

test("hitches records each stutter with what it was", async () => {
  await game.load({ scenario: "attack", seed: 1 });
  await game.step(2);
  // (every frame counts as one at a 1 ms threshold)
  assert.ok(has(await game.console("hitches 1"), /any frame over 1 ms/));
  await game.step(1);
  const out = await game.console("hitches");
  assert.ok(has(out, /^The latest stutters/), out.join("\n"));
  assert.ok(has(out, /^ +\d+:\d\d +\d+ ms \(usually \d+\): /), "each with its time and cause");
  await game.console("hitches auto");
});
