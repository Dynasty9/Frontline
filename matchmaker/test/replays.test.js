import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { DELAY_MS, Replays } from '../src/replays.js';
import { createServer } from '../src/server.js';

const lobby = { id: 'aabbcc', name: 'Bridgehead', host: 'Raven', inGame: true, locked: false };
const header = { format: 1, protocol: 9, version: 'test' };
const chunk = { sequence: 0, start: 0, end: 10, size: 3, data: 'YWJj', final: false };

test('durable ordered chunks, delayed reads, no secret exposure, and retention', (t) => {
	const dir = mkdtempSync(join(tmpdir(), 'frontline-replays-'));
	t.after(() => rmSync(dir, { recursive: true, force: true }));
	let now = 100000;
	const replays = new Replays({ dir, now: () => now });
	const { id, token } = replays.create(lobby, header);
	assert.throws(() => replays.append(id, 'wrong', chunk), { status: 403 });
	assert.throws(() => replays.create({ ...lobby, locked: true }, header), { status: 403 });
	assert.throws(() => replays.append(id, token, { ...chunk, sequence: 1 }), { status: 409 });
	replays.append(id, token, chunk);
	replays.append(id, token, chunk); // A lost HTTP response can be retried safely.
	assert.equal(replays.get(id).chunks.length, 1);
	assert.throws(() => replays.append(id, token, { ...chunk, data: 'ZGVm' }), { status: 409 });
	assert.throws(() => replays.chunk(id, '0'), { status: 404 });
	assert.equal(replays.view(replays.get(id)).duration, 0);
	assert.equal(JSON.stringify(replays.list()).includes(token), false);
	assert.equal(JSON.stringify(replays.list()).includes('secret'), false);
	now += DELAY_MS;
	assert.deepEqual(replays.chunk(id, '0'), chunk);
	assert.equal(DELAY_MS, 1000);
	assert.equal(replays.view(replays.get(id)).delay, 1);
	replays.append(id, token, { ...chunk, sequence: 1, start: 10, end: 12, final: true });
	assert.equal(replays.view(replays.get(id)).status, 'live'); // Finishing cannot bypass the delay.
	now += DELAY_MS;
	const restarted = new Replays({ dir, now: () => now });
	assert.equal(restarted.view(restarted.get(id)).status, 'complete');
	assert.equal(restarted.view(restarted.get(id)).verified, false);
	assert.equal(restarted.chunk(id, '1').end, 12);
	assert.throws(() => restarted.chunk(id, '../index'), { status: 404 });
	now += 8 * 86400000;
	assert.equal(restarted.list().length, 0);
});

test('HTTP requires the active public lobby owner, and reports disabled storage honestly', async (t) => {
	const dir = mkdtempSync(join(tmpdir(), 'frontline-replays-http-'));
	const server = createServer({ env: { REPLAY_DIR: dir }, auth: null, log: () => {} });
	await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
	t.after(async () => {
		await new Promise((resolve) => server.close(resolve));
		rmSync(dir, { recursive: true, force: true });
	});
	const base = `http://127.0.0.1:${server.address().port}`;
	const post = (path, body, headers = {}) =>
		fetch(base + path, { method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body) });
	const listing = await (await post('/lobbies', { port: 7777, host: 'Raven', in_game: true })).json();
	assert.equal((await post('/replays', { ...header, lobby: listing.id })).status, 403);
	const created = await post('/replays', { ...header, lobby: listing.id }, { 'X-Lobby-Token': listing.token });
	assert.equal(created.status, 200);
	const recording = await created.json();
	assert.equal((await post(`/replays/${recording.id}/chunks`, chunk)).status, 403);
	assert.equal((await post(`/replays/${recording.id}/chunks`, chunk, { Authorization: `Bearer ${recording.token}` })).status, 200);
	assert.equal((await fetch(base + `/replays/${recording.id}/chunks/0`)).status, 404);
	const view = await (await fetch(base + '/replays')).json();
	assert.equal(view.enabled, true);
	assert.equal(view.replays.length, 1);
	assert.equal(view.replays[0].verified, false);
	assert.throws(() => new Replays().create(lobby, header), { status: 503 });
});
