// Spectator recordings: a battle the host broadcasts, kept a week for anyone
// to watch. They're files, not account records: each recording is an
// index.json (what it is, and its chunks) and one JSON file per chunk of play,
// a few seconds each. The files live in a store: a folder on a persistent
// volume (REPLAY_DIR), or a bucket in the accounts' Supabase project
// (REPLAY_BUCKET), which costs nothing extra on its free plan within its
// limits. A service with neither advertises no recording support.
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { mkdir, readFile, readdir, rename, rm, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

export const REPLAY_BODY = 12 * 1024 * 1024;
export const DELAY_MS = 1_000;
const RETENTION_MS = 7 * 86400_000;
const MAX_RECORDING = 256 * 1024 * 1024;
const MB = 1024 * 1024;
// What all the recordings together may take: a volume's 5 GB, or 900 MB of a
// Supabase free plan's 1 GB of storage (REPLAY_STORAGE_MB sets another).
const FOLDER_BUDGET = 5 * 1024 * MB;
const BUCKET_BUDGET = 900 * MB;
// Recent chunks kept in memory: everyone watching a live broadcast asks for
// the same newest chunk, and a bucket charges for each download of it.
const CACHE_BYTES = 64 * MB;
const ID = /^[a-f0-9]{24}$/;
const hash = (s) => createHash('sha256').update(s).digest('hex');

export class ReplayError extends Error {
	constructor(status, message) {
		super(message);
		this.status = status;
	}
}

/** Recordings as files in a folder: REPLAY_DIR/<id>/index.json and <id>/<sequence>.json. */
export class FolderStore {
	constructor(dir) {
		this.dir = dir;
		this.kind = 'folder';
	}

	async ids() {
		await mkdir(this.dir, { recursive: true });
		return (await readdir(this.dir)).filter((s) => ID.test(s));
	}

	async read(id, name) {
		try {
			return await readFile(join(this.dir, id, name), 'utf8');
		} catch (e) {
			if (e.code === 'ENOENT') return null;
			throw e;
		}
	}

	async write(id, name, text) {
		await mkdir(join(this.dir, id), { recursive: true });
		const path = join(this.dir, id, name);
		// written whole or not at all: a crash mid-write leaves the old file
		await writeFile(path + '.tmp', text);
		await rename(path + '.tmp', path);
	}

	async remove(id) {
		await rm(join(this.dir, id), { recursive: true, force: true });
	}
}

/**
 * Recordings as objects in a private Supabase Storage bucket, through its REST
 * API with the project's secret key (which bypasses the bucket's row-level
 * security: nobody else can read or write it). A migration creates the bucket
 * (supabase/migrations/), so it's there before this service asks.
 */
export class BucketStore {
	constructor({ url, key, bucket, fetch = globalThis.fetch }) {
		this.base = `${url.replace(/\/+$/, '')}/storage/v1`;
		this.key = key;
		this.bucket = bucket;
		this.fetch = fetch;
		this.kind = 'supabase';
	}

	async call(method, path, { body, type = 'application/json', headers = {} } = {}) {
		let res;
		try {
			res = await this.fetch(`${this.base}${path}`, {
				method,
				headers: { apikey: this.key, Authorization: `Bearer ${this.key}`, 'Content-Type': type, ...headers },
				body,
			});
		} catch {
			throw new ReplayError(503, 'Recording storage is unreachable.');
		}
		return res;
	}

	async ids() {
		// the bucket's top level: a folder per recording (no more than 500 are ever kept)
		const res = await this.call('POST', `/object/list/${this.bucket}`, {
			body: JSON.stringify({ prefix: '', limit: 1000, offset: 0, sortBy: { column: 'name', order: 'asc' } }),
		});
		if (!res.ok) throw new ReplayError(503, `Recording storage answered ${res.status}.`);
		const entries = await res.json();
		return entries.map((e) => e.name).filter((s) => ID.test(s));
	}

	async read(id, name) {
		const res = await this.call('GET', `/object/${this.bucket}/${id}/${name}`);
		if (res.ok) return res.text();
		// a missing object is a 404, or a 400 that says so, depending on the Storage version
		const text = res.status === 400 ? await res.text() : '';
		if (res.status === 404 || /not.?found/i.test(text)) return null;
		throw new ReplayError(503, `Recording storage answered ${res.status}.`);
	}

	async write(id, name, text) {
		const res = await this.call('POST', `/object/${this.bucket}/${id}/${name}`, {
			body: text,
			// the index is rewritten as chunks arrive; a chunk sent again is the same chunk
			headers: { 'x-upsert': 'true' },
		});
		if (!res.ok) throw new ReplayError(503, `Recording storage answered ${res.status}.`);
	}

	async remove(id, names) {
		// Keep the index until every chunk is gone, so a restart can retry a partial removal.
		const chunks = names.filter((name) => name !== 'index.json');
		const batches = [];
		for (let i = 0; i < chunks.length; i += 1000) batches.push(chunks.slice(i, i + 1000));
		if (names.includes('index.json')) batches.push(['index.json']);
		for (const batch of batches) {
			const res = await this.call('DELETE', `/object/${this.bucket}`, {
				body: JSON.stringify({ prefixes: batch.map((n) => `${id}/${n}`) }),
			});
			if (!res.ok && res.status !== 404) throw new ReplayError(503, `Recording storage answered ${res.status}.`);
		}
	}
}

/** The recordings this service keeps, from its settings: a folder, a bucket, or none. */
export function createReplays(env = process.env, { log = console.log, fetch } = {}) {
	const mb = Number(env.REPLAY_STORAGE_MB);
	const budget = mb > 0 ? mb * MB : undefined;
	if (env.REPLAY_DIR) return new Replays({ store: new FolderStore(env.REPLAY_DIR), budget: budget ?? FOLDER_BUDGET, log });
	if (env.REPLAY_BUCKET) {
		const key = env.SUPABASE_SECRET_KEY || env.SUPABASE_SERVICE_ROLE_KEY;
		if (env.SUPABASE_URL && key) {
			const store = new BucketStore({ url: env.SUPABASE_URL, key, bucket: env.REPLAY_BUCKET, fetch });
			return new Replays({ store, budget: budget ?? BUCKET_BUDGET, log });
		}
		log('Recordings are off: REPLAY_BUCKET needs SUPABASE_URL and SUPABASE_SECRET_KEY.');
	}
	return new Replays({ log });
}

export class Replays {
	constructor({
		dir,
		store = dir ? new FolderStore(dir) : null,
		budget = store?.kind === 'supabase' ? BUCKET_BUDGET : FOLDER_BUDGET,
		now = Date.now,
		log = () => {},
	} = {}) {
		this.store = store;
		this.budget = budget;
		this.now = now;
		this.log = log;
		this.records = new Map();
		this.pending = new Map();
		this.queues = new Map();
		this.cache = new Map();
		this.cached = 0;
		this.loading = null;
		this.loaded = false;
	}

	get enabled() {
		return !!this.store;
	}

	/** Where they're kept, for /health: "folder", "supabase" or "off". */
	get kind() {
		return this.store?.kind ?? 'off';
	}

	// What was kept before a restart, read once (and again, if the store couldn't be reached).
	async ready() {
		if (!this.store || this.loaded) return;
		this.loading ??= (async () => {
			try {
				for (const id of await this.store.ids()) {
					const index = await this.store.read(id, 'index.json');
					let record;
					try {
						record = JSON.parse(index ?? 'null');
					} catch {
						continue; // An interrupted creation has no published recording.
					}
					if (record?.id !== id || !Array.isArray(record.chunks)) continue;
					// A chunk may have landed before its index write failed or the service stopped.
					// A failed read must retry initialization, rather than leave those bytes uncharged.
					const pending = await this.store.read(id, `${record.chunks.length}.json`);
					this.records.set(id, record);
					if (pending !== null) this.pending.set(id, Buffer.byteLength(pending));
					else this.pending.delete(id);
				}
				this.loaded = true;
			} finally {
				this.loading = null;
			}
		})();
		await this.loading;
		await this.sweep();
	}

	// One write at a time for each recording, in the order they came: a chunk
	// and the index that lists it land before the next chunk is looked at.
	serial(id, fn) {
		const run = (this.queues.get(id) ?? Promise.resolve()).then(fn, fn);
		const tail = run.catch(() => {});
		this.queues.set(id, tail);
		tail.then(() => this.queues.get(id) === tail && this.queues.delete(id));
		return run;
	}

	async sweep() {
		for (const [id, r] of this.records) {
			if (this.now() - r.created <= RETENTION_MS) continue;
			await this.serial(id, async () => {
				if (this.records.get(id) !== r) return;
				// Wait for queued writes before naming the chunks. Failed removal keeps its budget and can be retried.
				const names = ['index.json', ...Array.from({ length: r.chunks.length + 1 }, (_, i) => `${i}.json`)];
				await this.store.remove(id, names);
				this.records.delete(id);
				this.pending.delete(id);
				for (const key of this.cache.keys()) if (key.startsWith(id + '/')) this.forget(key);
			}).catch((e) => this.log(`replays: couldn't remove ${id}: ${e.message}`));
		}
	}

	save(r) {
		return this.store.write(r.id, 'index.json', JSON.stringify(r));
	}

	used() {
		return [...this.records.values()].reduce((n, r) => n + r.bytes, 0) + [...this.pending.values()].reduce((n, bytes) => n + bytes, 0);
	}

	async create(lobby, body) {
		if (!this.store) throw new ReplayError(503, 'Battle recording is not enabled on this server.');
		if (!lobby || lobby.locked || !lobby.inGame) throw new ReplayError(403, 'Only the host of a public active battle can broadcast it.');
		if (body.format !== 1 || !Number.isInteger(body.protocol) || typeof body.version !== 'string' || body.version.length > 40)
			throw new ReplayError(400, 'Unsupported recording version.');
		await this.ready();
		await this.sweep();
		// one at a time, so a host asking twice at once still gets one recording
		return this.serial('create', async () => {
			const token = hash(String(lobby.token) + ':replay');
			const existing = [...this.records.values()].find((r) => r.lobby === lobby.id && this.now() - r.created <= RETENTION_MS);
			if (existing) return { id: existing.id, token, delay: DELAY_MS / 1000 };
			if (this.records.size >= 500 || this.used() >= this.budget) throw new ReplayError(507, 'Recording storage is full.');
			const r = {
				id: randomBytes(12).toString('hex'),
				lobby: lobby.id,
				name: lobby.name,
				host: lobby.host,
				format: 1,
				protocol: body.protocol,
				version: body.version,
				created: this.now(),
				updated: this.now(),
				secret: hash(token),
				chunks: [],
				bytes: 0,
				finished: false,
			};
			await this.save(r);
			this.records.set(r.id, r);
			return { id: r.id, token, delay: DELAY_MS / 1000 };
		});
	}

	async get(id) {
		await this.ready();
		const r = ID.test(id) && this.records.get(id);
		if (!r || this.now() - r.created > RETENTION_MS) throw new ReplayError(404, 'Recording unavailable or expired.');
		return r;
	}

	async append(id, token, body) {
		const r = await this.get(id);
		if (!timingSafeEqual(Buffer.from(hash(token)), Buffer.from(r.secret))) throw new ReplayError(403, 'Invalid recording token.');
		const { sequence, start, end, data, size, final = false } = body;
		if (
			!Number.isInteger(sequence) ||
			sequence < 0 ||
			sequence > 7200 ||
			!Number.isFinite(start) ||
			!Number.isFinite(end) ||
			start < 0 ||
			end < start ||
			end > 14400 ||
			end - start > 15 ||
			!Number.isInteger(size) ||
			size < 1 ||
			size > 64 * 1024 * 1024 ||
			typeof final !== 'boolean' ||
			typeof data !== 'string' ||
			data.length > REPLAY_BODY - 1024 ||
			!/^[A-Za-z0-9+/]+={0,2}$/.test(data) ||
			data.length % 4
		)
			throw new ReplayError(400, 'Invalid recording chunk.');
		const payload = JSON.stringify({ sequence, start, end, size, data, final });
		const digest = hash(payload);
		return this.serial(id, async () => {
			if (this.records.get(id) !== r || this.now() - r.created > RETENTION_MS) throw new ReplayError(404, 'Recording unavailable or expired.');
			if (sequence < r.chunks.length && r.chunks[sequence].hash === digest) return { ok: true, sequence };
			if (r.finished || sequence !== r.chunks.length || (sequence > 0 && start !== r.chunks.at(-1).end))
				throw new ReplayError(409, 'Recording chunks must arrive in order.');
			const bytes = Buffer.byteLength(payload);
			const previous = this.pending.get(id) ?? 0;
			const reserved = Math.max(previous, bytes);
			if (r.bytes + reserved > MAX_RECORDING || this.used() + reserved - previous > this.budget) throw new ReplayError(507, 'Recording storage is full.');
			// Reserve before yielding: other recordings share this budget. Keep uncertain writes charged until retried or removed.
			this.pending.set(id, reserved);
			// the chunk first, then the index that lists it: an index never names a chunk that isn't there
			await this.store.write(id, `${sequence}.json`, payload);
			this.pending.set(id, bytes);
			const next = {
				...r,
				chunks: [...r.chunks, { sequence, start, end, available: this.now() + DELAY_MS, hash: digest }],
				updated: this.now(),
				bytes: r.bytes + bytes,
				finished: final,
			};
			await this.save(next);
			Object.assign(r, next);
			this.pending.delete(id);
			this.remember(`${id}/${sequence}`, payload);
			return { ok: true, sequence };
		});
	}

	view(r) {
		const chunks = r.chunks.filter((c) => c.available <= this.now()).map(({ sequence, start, end }) => ({ sequence, start, end }));
		return {
			id: r.id,
			lobby: r.lobby,
			name: r.name,
			host: r.host,
			format: r.format,
			protocol: r.protocol,
			version: r.version,
			created: r.created,
			delay: DELAY_MS / 1000,
			verified: false,
			status: r.finished && chunks.length === r.chunks.length ? 'complete' : this.now() - r.updated > 120_000 ? 'interrupted' : 'live',
			duration: chunks.at(-1)?.end ?? 0,
			chunks,
		};
	}

	async list() {
		if (!this.store) return [];
		try {
			await this.ready();
		} catch (e) {
			// the list comes back by itself once the store answers again
			this.log(`replays: couldn't read the store: ${e.message}`);
			return [];
		}
		await this.sweep();
		return [...this.records.values()]
			.filter((r) => this.now() - r.created <= RETENTION_MS)
			.toSorted((a, b) => b.created - a.created)
			.slice(0, 100)
			.map((r) => this.view(r));
	}

	async chunk(id, sequence) {
		const r = await this.get(id);
		if (!/^\d+$/.test(sequence) || !r.chunks[Number(sequence)] || r.chunks[Number(sequence)].available > this.now())
			throw new ReplayError(404, 'This part of the broadcast is not available yet.');
		const key = `${id}/${Number(sequence)}`;
		let payload = this.cache.get(key);
		if (payload === undefined) {
			payload = await this.store.read(id, `${Number(sequence)}.json`);
			if (payload === null) throw new ReplayError(404, 'This part of the broadcast is missing.');
			this.remember(key, payload);
		} else {
			// most recently asked for: last out
			this.cache.delete(key);
			this.cache.set(key, payload);
		}
		return JSON.parse(payload);
	}

	remember(key, payload) {
		if (payload.length > CACHE_BYTES / 4) return;
		this.forget(key);
		this.cache.set(key, payload);
		this.cached += payload.length;
		for (const old of this.cache.keys()) {
			if (this.cached <= CACHE_BYTES) break;
			this.forget(old);
		}
	}

	forget(key) {
		const payload = this.cache.get(key);
		if (payload === undefined) return;
		this.cache.delete(key);
		this.cached -= payload.length;
	}
}
