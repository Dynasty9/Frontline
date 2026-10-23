// Spectator recordings are files, not account records. Mount REPLAY_DIR on a
// persistent volume; a service without one advertises no recording support.
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { mkdirSync, readFileSync, readdirSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

export const REPLAY_BODY = 12 * 1024 * 1024;
export const DELAY_MS = 1_000;
const RETENTION_MS = 7 * 86400_000;
const MAX_RECORDING = 256 * 1024 * 1024;
const MAX_STORAGE = 5 * 1024 * 1024 * 1024;
const ID = /^[a-f0-9]{24}$/;
const hash = (s) => createHash('sha256').update(s).digest('hex');

export class ReplayError extends Error {
	constructor(status, message) {
		super(message);
		this.status = status;
	}
}

export class Replays {
	constructor({ dir, now = Date.now } = {}) {
		this.dir = dir;
		this.now = now;
		this.records = new Map();
		if (!dir) return;
		mkdirSync(dir, { recursive: true });
		for (const id of readdirSync(dir).filter((s) => ID.test(s))) {
			try {
				const record = JSON.parse(readFileSync(join(dir, id, 'index.json'), 'utf8'));
				if (record.id === id) this.records.set(id, record);
			} catch {
				/* An interrupted creation has no published recording. */
			}
		}
		this.sweep();
	}

	sweep() {
		for (const [id, r] of this.records) {
			if (this.now() - r.created <= RETENTION_MS) continue;
			rmSync(join(this.dir, id), { recursive: true, force: true });
			this.records.delete(id);
		}
	}

	save(r) {
		const path = join(this.dir, r.id, 'index.json');
		writeFileSync(path + '.tmp', JSON.stringify(r));
		renameSync(path + '.tmp', path);
	}

	create(lobby, body) {
		if (!this.dir) throw new ReplayError(503, 'Battle recording is not enabled on this server.');
		if (!lobby || lobby.locked || !lobby.inGame) throw new ReplayError(403, 'Only the host of a public active battle can broadcast it.');
		if (body.format !== 1 || !Number.isInteger(body.protocol) || typeof body.version !== 'string' || body.version.length > 40)
			throw new ReplayError(400, 'Unsupported recording version.');
		this.sweep();
		const token = hash(String(lobby.token) + ':replay');
		const existing = [...this.records.values()].find((r) => r.lobby === lobby.id);
		if (existing) return { id: existing.id, token, delay: DELAY_MS / 1000 };
		if (this.records.size >= 500 || [...this.records.values()].reduce((n, r) => n + r.bytes, 0) >= MAX_STORAGE)
			throw new ReplayError(507, 'Recording storage is full.');
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
		mkdirSync(join(this.dir, r.id));
		this.save(r);
		this.records.set(r.id, r);
		return { id: r.id, token, delay: DELAY_MS / 1000 };
	}

	get(id) {
		const r = ID.test(id) && this.records.get(id);
		if (!r || this.now() - r.created > RETENTION_MS) throw new ReplayError(404, 'Recording unavailable or expired.');
		return r;
	}

	append(id, token, body) {
		const r = this.get(id);
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
		if (sequence < r.chunks.length && r.chunks[sequence].hash === digest) return { ok: true, sequence };
		if (r.finished || sequence !== r.chunks.length || (sequence > 0 && start !== r.chunks.at(-1).end))
			throw new ReplayError(409, 'Recording chunks must arrive in order.');
		const bytes = Buffer.byteLength(payload);
		if (r.bytes + bytes > MAX_RECORDING || [...this.records.values()].reduce((n, v) => n + v.bytes, 0) + bytes > MAX_STORAGE)
			throw new ReplayError(507, 'Recording storage is full.');
		writeFileSync(join(this.dir, id, `${sequence}.json.tmp`), payload);
		renameSync(join(this.dir, id, `${sequence}.json.tmp`), join(this.dir, id, `${sequence}.json`));
		r.chunks.push({ sequence, start, end, available: this.now() + DELAY_MS, hash: digest });
		r.updated = this.now();
		r.bytes += bytes;
		r.finished = final;
		this.save(r);
		return { ok: true, sequence };
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

	list() {
		this.sweep();
		return [...this.records.values()]
			.toSorted((a, b) => b.created - a.created)
			.slice(0, 100)
			.map((r) => this.view(r));
	}

	chunk(id, sequence) {
		const r = this.get(id);
		if (!/^\d+$/.test(sequence) || !r.chunks[Number(sequence)] || r.chunks[Number(sequence)].available > this.now())
			throw new ReplayError(404, 'This part of the broadcast is not available yet.');
		return JSON.parse(readFileSync(join(this.dir, id, `${Number(sequence)}.json`), 'utf8'));
	}
}
