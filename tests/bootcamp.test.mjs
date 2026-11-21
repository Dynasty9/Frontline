// Boot Camp (missions.gd, "bootcamp"): each step waits for the player to do
// it. Steps only the player's screen sees (the camera, a selection, the
// order of battle, the tactical map) arrive as "drill" orders from the HUD;
// the rest are the orders themselves. Loaded with play, so nothing happens
// unless we do it. (The whole course playing itself is in missions.test.mjs.)

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { Game } from "./lib/game.mjs";

const YOU = 1;
const ACTIVE = 1;
const DONE = 2;

let game;
before(async () => {
  game = await Game.start();
});
after(async () => {
  if (game) assert.equal(await game.close(), 0, "the game's exit code");
});

async function objectives() {
  const { mission_info: info } = await game.query("world");
  return info.objs.map((o) => ({ text: o[1], state: o[2], kind: o[3] }));
}

test("each step waits for the player, and names the keys", async () => {
  await game.load({ mission: "bootcamp", play: true });
  await game.step(5);
  let objs = await objectives();
  assert.equal(objs.length, 1, "one step at a time");
  assert.equal(objs[0].state, ACTIVE);
  assert.match(objs[0].text, /\{cam_up\}/, "the keys go to the screen as actions, for each player's own bindings");

  // doing something else doesn't count, nor does waiting
  await game.send("order", { peer: YOU, t: "drill", what: "select" });
  await game.step(20);
  objs = await objectives();
  assert.equal(objs.length, 1);
  assert.equal(objs[0].state, ACTIVE, "still waiting to see the camera move");

  await game.send("order", { peer: YOU, t: "drill", what: "camera" });
  await game.step(4);
  objs = await objectives();
  assert.equal(objs[0].state, DONE, "the camera step is done");
  assert.equal(objs[1].state, ACTIVE, "and the next is set");
  assert.match(objs[1].text, /^Select a squad/);

  await game.send("order", { peer: YOU, t: "drill", what: "select" });
  await game.step(4);
  objs = await objectives();
  assert.equal(objs.length, 2, "done steps fold away: the last one done and the one in hand");
  assert.equal(objs[0].state, DONE);
  assert.match(objs[1].text, /^Move into the sandbags/);

  // the move is met on the ground, by an order of ours
  const { squads } = await game.query("squads", { team: 0, kind: "rifle_squad" });
  const sandbags = (await game.query("world")).mission_info.objs[1][4];
  await game.send("order", { peer: YOU, t: "move", squads: squads.map((s) => s.id), pos: { v3: [sandbags[0], sandbags[2]] } });
  let met = false;
  for (let i = 0; i < 20 && !met; i++) {
    await game.step(3);
    met = (await objectives()).some((o) => /^Move into/.test(o.text) && o.state === DONE);
  }
  assert.ok(met, "the squads reached the sandbags");
  await game.step(3); // (the next step is set a moment after)
  objs = await objectives();
  assert.match(objs[objs.length - 1].text, /^Pick out one man/);
});
