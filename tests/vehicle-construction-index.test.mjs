import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { ROOT } from './lib/game.mjs';

test('construction index follows active ownership and does not expand all dispatch branches', () => {
  const dir = mkdtempSync(join(tmpdir(), 'vehicle-index-'));
  try {
    const output = join(dir, 'index.json');
    execFileSync('python3', ['tools/vehicles/construction-index.py', '--output', output], { cwd: ROOT });
    const { models, limitations } = JSON.parse(readFileSync(output));
    assert.equal(models.blackwasp.owner, 'VmFighter');
    assert.deepEqual(models.blackwasp.shadowed, ['VmPlane']);
    assert.equal(models.wipeout.owner, 'VmAttack');
    assert.equal(models.blackfish.owner, 'VmGunship');
    assert.deepEqual(models.truck.roots, ['VmCore._truck', 'VmIndep._zamak', 'VmNato._hemtt']);
    assert.ok(models.hunter.shared_calls['VehicleFittings.jerrycan']);
    assert.ok(models.ac130.shared_calls['VehiclePropellers.blade']);
    const features = JSON.parse(readFileSync(join(ROOT, 'tools/vehicles/features.json')));
    assert.equal(features.length, 30);
    for (const feature of features) {
      const roots = new Set(Object.entries(models).filter(([key, model]) =>
        key !== 'truck' && model.shared_calls[feature.api]).flatMap(([, model]) => model.roots));
      assert.ok(roots.size >= 3, `${feature.api}: only ${roots.size} independent construction roots`);
    }
    assert.ok(!models.hunter.shared_calls['VehicleRotors.main']);
    const details = JSON.parse(readFileSync(join(ROOT, 'tools/vehicles/detail-improvements.json')));
    assert.equal(details.flatMap(d => d.improvements).length, 40);
    assert.equal(new Set(details.flatMap(d => d.improvements.map(i => i.id))).size, 40);
    for (const detail of details) for (const api of detail.apis) {
      const roots = new Set(Object.entries(models).filter(([key, model]) =>
        key !== 'truck' && model.shared_calls[api]).flatMap(([, model]) => model.roots));
      assert.ok(roots.size >= 3, `${api}: needs three distinct active builders`);
    }
    assert.ok(models.hunter.candidate_evidence.doors.length > 0);
    assert.deepEqual(models.civilian_0.roots, ['VehicleModels._car']);
    assert.ok(limitations.some(s => s.includes('Conditional branches')));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
