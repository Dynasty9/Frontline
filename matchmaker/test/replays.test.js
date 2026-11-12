import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { createServer as createHttpServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { BucketStore, createReplays, DELAY_MS, FolderStore, Replays } from '../src/replays.js';
import { createServer } from '../src/server.js';

const lobby = { id: 'aabbcc', name: 'Bridgehead', host: 'Raven', inGame: true, locked: false };
const header = { format: 1, protocol: 9, version: 'test' };
const chunk = { sequence: 0, start: 0, end: 10, size: 3, data: 'YWJj', final: false };
const KEY = 'sb_secret_test';

/**
 * Supabase Storage's REST API, as far as the bucket store uses it: upload
 * (refusing to overwrite without x-upsert), download (a missing object is a
 * 400 that says so, as some Storage versions answer), list the top level, and
 * remove. Everything is refused without the secret key.
 */
async function fakeStorage(t) {
	const objects = new Map();
	const server = createHttpServer(async (req, res) => {
		let body = '';
		for await (const part of req) body += part;
		const answer = (status, data) => {
			res.writeHead(status, { 'Content-Type': 'application/json' });
			res.end(typeof data === 'string' ? data : JSON.stringify(data));
		};
		if (req.headers.apikey !== KEY || req.headers.authorization !== `Bearer ${KEY}`)
			return answer(400, { statusCode: '403', error: 'Unauthorized', message: 'Invalid key' });
		const url = new URL(req.url, 'http://x');
		const list = url.pathname.match(/^\/storage\/v1\/object\/list\/replays$/);
		const object = url.pathname.match(/^\/storage\/v1\/object\/replays\/(.+)$/);
		if (list && req.method === 'POST') {
			const folders = new Set([...objects.keys()].map((k) => k.split('/')[0]));
			return answer(
				200,
				[...folders].map((name) => ({ name, id: null, metadata: null })),
			);
		}
		if (object && req.method === 'POST') {
			if (objects.has(object[1]) && req.headers['x-upsert'] !== 'true') return answer(400, { statusCode: '409', error: 'Duplicate' });
			objects.set(object[1], body);
			return answer(200, { Key: `replays/${object[1]}` });
		}
		if (object && req.method === 'GET') {
			if (!objects.has(object[1])) return answer(400, { statusCode: '404', error: 'not_found', message: 'Object not found' });
			res.writeHead(200, { 'Content-Type': 'application/json' });
			return res.end(objects.get(object[1]));
		}
		if (url.pathname === '/storage/v1/object/replays' && req.method === 'DELETE') {
			const { prefixes } = JSON.parse(body);
			assert.ok(prefixes.length <= 1000, 'Storage removes at most 1000 objects a call');
			for (const p of prefixes) objects.delete(p);
			return answer(
				200,
				prefixes.map((name) => ({ name })),
			);
		}
		answer(404, { error: 'not found' });
	});
	await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
	t.after(() => new Promise((resolve) => server.close(resolve)));
	return { objects, url: `http://127.0.0.1:${server.address().port}` };
}

// Each store, the same rules: what a recording is, whatever it's kept in.
const STORES = {
	folder: async (t) => {
		const dir = mkdtempSync(join(tmpdir(), 'frontline-replays-'));
		t.after(() => rmSync(dir, { recursive: true, force: true }));
		return { make: () => new FolderStore(dir), left: async () => 0 };
	},
	supabase: async (t) => {
		const storage = await fakeStorage(t);
		return { make: () => new BucketStore({ url: storage.url, key: KEY, bucket: 'replays' }), left: async () => storage.objects.size };
	},
};

for (const [kind, setUp] of Object.entries(STORES)) {
	test(`${kind}: durable ordered chunks, delayed reads, no secret exposure, and retention`, async (t) => {
		const { make, left } = await setUp(t);
		let now = 100000;
		const replays = new Replays({ store: make(), now: () => now });
		assert.equal(replays.kind, kind);
		const { id, token } = await replays.create(lobby, header);
		await assert.rejects(replays.append(id, 'wrong', chunk), { status: 403 });
		await assert.rejects(replays.create({ ...lobby, locked: true }, header), { status: 403 });
		await assert.rejects(replays.append(id, token, { ...chunk, sequence: 1 }), { status: 409 });
		await replays.append(id, token, chunk);
		await replays.append(id, token, chunk); // A lost HTTP response can be retried safely.
		assert.equal((await replays.get(id)).chunks.length, 1);
		await assert.rejects(replays.append(id, token, { ...chunk, data: 'ZGVm' }), { status: 409 });
		await assert.rejects(replays.chunk(id, '0'), { status: 404 });
		assert.equal(replays.view(await replays.get(id)).duration, 0);
		assert.equal(JSON.stringify(await replays.list()).includes(token), false);
		assert.equal(JSON.stringify(await replays.list()).includes('secret'), false);
		now += DELAY_MS;
		assert.deepEqual(await replays.chunk(id, '0'), chunk);
		assert.equal(DELAY_MS, 1000);
		assert.equal(replays.view(await replays.get(id)).delay, 1);
		await replays.append(id, token, { ...chunk, sequence: 1, start: 10, end: 12, final: true });
		assert.equal(replays.view(await replays.get(id)).status, 'live'); // Finishing cannot bypass the delay.
		now += DELAY_MS;
		// a restart reads it all back from the store, chunks too (its memory of them is gone)
		const restarted = new Replays({ store: make(), now: () => now });
		assert.equal(restarted.view(await restarted.get(id)).status, 'complete');
		assert.equal(restarted.view(await restarted.get(id)).verified, false);
		assert.equal((await restarted.chunk(id, '1')).end, 12);
		await assert.rejects(restarted.chunk(id, '../index'), { status: 404 });
		now += 8 * 86400000;
		assert.equal((await restarted.list()).length, 0);
		if (kind === 'supabase') assert.equal(await left(), 0, 'an expired recording is removed from the bucket');
	});

	test(`${kind}: chunks sent at once land in order, and one host gets one recording`, async (t) => {
		const { make } = await setUp(t);
		let now = 100000;
		const replays = new Replays({ store: make(), now: () => now });
		const [a, b] = await Promise.all([replays.create(lobby, header), replays.create(lobby, header)]);
		assert.equal(a.id, b.id);
		const parts = [0, 1, 2, 3].map((i) => ({ ...chunk, sequence: i, start: i * 10, end: i * 10 + 10 }));
		await Promise.all(parts.map((p) => replays.append(a.id, a.token, p)));
		now += DELAY_MS;
		const restarted = new Replays({ store: make(), now: () => now });
		assert.deepEqual(
			(await restarted.get(a.id)).chunks.map((c) => c.sequence),
			[0, 1, 2, 3],
		);
		assert.equal((await restarted.chunk(a.id, '3')).start, 30);
	});
}

test('a full store refuses new recordings and chunks', async () => {
	const replays = new Replays({ store: new MemoryStore(), budget: 100 });
	const { id, token } = await replays.create(lobby, header);
	await assert.rejects(replays.append(id, token, { ...chunk, data: 'A'.repeat(200) }), { status: 507 });
});

test('an unreachable bucket: recording says so, the list stays up', async () => {
	const replays = new Replays({ store: new BucketStore({ url: 'http://127.0.0.1:9', key: KEY, bucket: 'replays' }), log: () => {} });
	await assert.rejects(replays.create(lobby, header), { status: 503 });
	assert.deepEqual(await replays.list(), []);
});

test('the settings choose the store: a folder, a bucket with the secret key, or none', () => {
	const said = [];
	const log = (m) => said.push(m);
	assert.equal(createReplays({ REPLAY_DIR: tmpdir() }, { log }).kind, 'folder');
	const bucket = createReplays({ REPLAY_BUCKET: 'replays', SUPABASE_URL: 'https://x.supabase.co', SUPABASE_SECRET_KEY: KEY }, { log });
	assert.equal(bucket.kind, 'supabase');
	assert.equal(bucket.budget, 900 * 1024 * 1024); // inside a free plan's 1 GB
	assert.equal(createReplays({ REPLAY_BUCKET: 'replays', SUPABASE_URL: 'https://x.supabase.co', REPLAY_STORAGE_MB: '400' }, { log }).kind, 'off');
	assert.match(said.join('\n'), /needs SUPABASE_URL and SUPABASE_SECRET_KEY/);
	assert.equal(
		createReplays({ REPLAY_BUCKET: 'r', SUPABASE_URL: 'https://x', SUPABASE_SERVICE_ROLE_KEY: 'eyJ', REPLAY_STORAGE_MB: '400' }).budget,
		400 * 1024 * 1024,
	);
	assert.equal(createReplays({}).enabled, false);
});

test('HTTP requires the active public lobby owner, and reports disabled storage honestly', async (t) => {
	const storage = await fakeStorage(t);
	const env = { REPLAY_BUCKET: 'replays', SUPABASE_URL: storage.url, SUPABASE_SECRET_KEY: KEY };
	const server = createServer({ env, auth: null, log: () => {} });
	await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
	t.after(() => new Promise((resolve) => server.close(resolve)));
	const base = `http://127.0.0.1:${server.address().port}`;
	const post = (path, body, headers = {}) =>
		fetch(base + path, { method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body) });
	assert.equal((await (await fetch(base + '/health')).json()).recordings, 'supabase');
	const listing = await (await post('/lobbies', { port: 7777, host: 'Raven', in_game: true })).json();
	assert.equal((await post('/replays', { ...header, lobby: listing.id })).status, 403);
	const created = await post('/replays', { ...header, lobby: listing.id }, { 'X-Lobby-Token': listing.token });
	assert.equal(created.status, 200);
	const recording = await created.json();
	assert.equal((await post(`/replays/${recording.id}/chunks`, chunk)).status, 403);
	assert.equal((await post(`/replays/${recording.id}/chunks`, chunk, { Authorization: `Bearer ${recording.token}` })).status, 200);
	assert.equal((await fetch(base + `/replays/${recording.id}/chunks/0`)).status, 404);
	await new Promise((resolve) => setTimeout(resolve, DELAY_MS + 50));
	const part = await fetch(base + `/replays/${recording.id}/chunks/0`);
	assert.equal(part.status, 200);
	// a published chunk never changes: the viewer's browser keeps it
	assert.match(part.headers.get('cache-control'), /immutable/);
	assert.deepEqual(await part.json(), chunk);
	const view = await (await fetch(base + '/replays')).json();
	assert.equal(view.enabled, true);
	assert.equal(view.replays.length, 1);
	assert.equal(view.replays[0].verified, false);
	await assert.rejects(new Replays().create(lobby, header), { status: 503 });
	// a server with no store says so, rather than listing nothing as if there were none yet
	const off = createServer({ env: {}, auth: null, log: () => {} });
	await new Promise((resolve) => off.listen(0, '127.0.0.1', resolve));
	t.after(() => new Promise((resolve) => off.close(resolve)));
	const offBase = `http://127.0.0.1:${off.address().port}`;
	assert.deepEqual(await (await fetch(offBase + '/replays')).json(), { enabled: false, replays: [] });
	assert.equal((await (await fetch(offBase + '/health')).json()).recordings, 'off');
});

/** A store in memory, for the rules that don't depend on where it's kept. */
class MemoryStore {
	constructor() {
		this.files = new Map();
		this.kind = 'memory';
	}
	async ids() {
		return [...new Set([...this.files.keys()].map((k) => k.split('/')[0]))];
	}
	async read(id, name) {
		return this.files.get(`${id}/${name}`) ?? null;
	}
	async write(id, name, text) {
		this.files.set(`${id}/${name}`, text);
	}
	async remove(id) {
		for (const k of this.files.keys()) if (k.startsWith(id + '/')) this.files.delete(k);
	}
}
