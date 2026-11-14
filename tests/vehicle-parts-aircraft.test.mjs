import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { ROOT } from './lib/game.mjs';

test('aircraft stores, engine faces, pylons and hub caps fold, keep their points, stay in their envelopes and drop wreck glass', async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || 'godot', [
    '--headless', '--path', ROOT, 'res://tests/fixtures/vehicle-parts-aircraft.tscn',
  ], { timeout: 120_000, maxBuffer: 4 * 1024 * 1024 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|Assertion failed/);
  assert.ok(stdout.includes('VEHICLE_PARTS_AIRCRAFT passed'), stdout + stderr);
});
