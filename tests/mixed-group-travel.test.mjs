import { test } from "node:test";
import assert from "node:assert/strict";
import { Game, v3 } from "./lib/game.mjs";

test("a shared Move uses foot pace until a vehicle gets a new order", async (t) => {
  const game = await Game.start();
  t.after(() => game.close());
  await game.load({ scenario: "drone", seed: 3, static: true });
  const [vehicle] = (await game.query("vehicles", { team: 0 })).vehicles;
  const [squad] = (await game.query("squads", { team: 0 })).squads;
  const move = { vehicles: [vehicle.id], pos: v3(0, -82) };
  const state = async () => (await game.query("vehicles", { ids: [vehicle.id] })).vehicles[0];

  await game.order(0, "move", { ...move, squads: [squad.id], mode: 0 });
  await game.step(4);
  const walking = await state();
  assert.ok(walking.speed > 1 && walking.speed <= 3.45, JSON.stringify(walking));

  await game.order(0, "move", move);
  await game.step(4);
  const driving = await state();
  assert.ok(driving.speed > walking.speed + 1, JSON.stringify(driving));
});
