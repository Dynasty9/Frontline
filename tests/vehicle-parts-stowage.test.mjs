import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { ROOT } from './lib/game.mjs';

test('drums and spare-wheel carriers fold, stay in their envelopes and burn on wrecks', async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || 'godot', [
    '--headless', '--path', ROOT, 'res://tests/fixtures/vehicle-parts-stowage.tscn',
  ], { timeout: 120_000, maxBuffer: 4 * 1024 * 1024 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|Assertion failed/);
  assert.ok(stdout.includes('VEHICLE_PARTS_STOWAGE passed'), stdout + stderr);
});
