import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { ROOT } from './lib/game.mjs';

test('track guards, tow cables, spare links, exhausts, wishbones, air cleaners, searchlights and light bars fold, stay in their envelopes and drop wreck lenses', async () => {
  const { stdout, stderr } = await promisify(execFile)(process.env.GODOT || 'godot', [
    '--headless', '--path', ROOT, 'res://tests/fixtures/vehicle-parts-gear.tscn',
  ], { timeout: 120_000, maxBuffer: 4 * 1024 * 1024 });
  assert.doesNotMatch(stdout + stderr, /SCRIPT ERROR|Parse Error|Assertion failed/);
  assert.ok(stdout.includes('VEHICLE_PARTS_GEAR passed'), stdout + stderr);
});
