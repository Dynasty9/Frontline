// Error reports from players' copies of the game: what went wrong, where in
// the game's code, and on what kind of machine. The game sends them as they
// happen, and a crash at the next launch (from the log the engine left).
//
// We keep a tally in memory, one entry per distinct error with how often it
// has been seen and on which versions, systems and graphics cards, and write
// each new one to the log in full (the log outlives a redeploy; the tally
// doesn't). Nothing in a report says who sent it: the game strips paths and
// addresses out before sending, and we never record where a report came from.

import { createHash } from 'node:crypto';
import { cleanText } from './lobbies.js';

export const KINDS = ['error', 'script', 'shader', 'crash'];
export const MAX_REPORTS = 24; // in one request
export const MAX_FRAMES = 24;
export const MAX_LINES = 40; // a crash's last log lines
export const MAX_ENTRIES = 500;
export const MAX_BODY = 48 * 1024;
// how many different values of a field (versions, GPUs) an entry keeps count of
const MAX_TALLY = 20;
// an entry's sessions, counted up to this many (one session is one launch of the game)
const MAX_SESSIONS = 1000;

export class ReportError extends Error {
	constructor(message) {
		super(message);
		this.status = 400;
	}
}

const lines = (v, n, len) => (Array.isArray(v) ? v.slice(0, n).map((s) => cleanText(s, len)) : []);

// What makes two reports the same error: where it happened, how we got there,
// and what it said with the numbers taken out ("index 7 out of 3" and "index 9
// out of 5" are one bug).
const signature = (r) =>
	createHash('sha1')
		.update([r.kind, r.where, r.message.replace(/\d+/g, '#'), r.backtrace[0] || ''].join('\n'))
		.digest('hex')
		.slice(0, 12);

const bump = (tally, key) => {
	if (!key) return;
	if (key in tally) tally[key]++;
	else if (Object.keys(tally).length < MAX_TALLY) tally[key] = 1;
};

export class ErrorLog {
	constructor({ log = console.log, now = Date.now } = {}) {
		this.log = log;
		this.now = now;
		this.entries = new Map(); // signature -> entry, least recently seen first
		this.received = 0;
	}

	// A request from the game: {game_version, os, gpu, driver, session, reports: [...]}.
	add(body) {
		if (!body || typeof body !== 'object') throw new ReportError('No report.');
		const meta = {
			version: cleanText(body.game_version, 20),
			os: cleanText(body.os, 60),
			gpu: cleanText(body.gpu, 80),
			driver: cleanText(body.driver, 80),
			session: cleanText(body.session, 32),
		};
		const reports = Array.isArray(body.reports) ? body.reports.slice(0, MAX_REPORTS) : [];
		if (reports.length === 0) throw new ReportError('No errors in that report.');
		let accepted = 0;
		for (const raw of reports) {
			if (!raw || typeof raw !== 'object') continue;
			const kind = String(raw.kind ?? '');
			if (!KINDS.includes(kind)) continue;
			const r = {
				kind,
				message: cleanText(raw.message, 500),
				condition: cleanText(raw.condition, 200),
				where: cleanText(raw.where, 200),
				context: cleanText(raw.context, 20),
				backtrace: lines(raw.backtrace, MAX_FRAMES, 200),
				log: kind === 'crash' ? lines(raw.log, MAX_LINES, 300) : [],
			};
			if (!r.message && !r.where) continue;
			const count = Math.min(1e6, Math.max(1, Math.round(Number(raw.count)) || 1));
			this.#record(r, count, meta);
			accepted++;
		}
		if (accepted === 0) throw new ReportError('No errors in that report.');
		this.received++;
		return { ok: true, accepted };
	}

	#record(r, count, meta) {
		const id = signature(r);
		const t = new Date(this.now()).toISOString();
		let e = this.entries.get(id);
		if (e) {
			this.entries.delete(id); // (re-inserted below: most recently seen last)
		} else {
			e = { id, ...r, count: 0, first: t, versions: {}, os: {}, gpus: {}, drivers: {}, sessions: new Set() };
			const where = [r.where, r.context && `in the ${r.context}`].filter(Boolean).join(', ');
			const trace = r.backtrace.length ? `\n  ${r.backtrace.join('\n  ')}` : '';
			const tail = r.log.length ? `\n  | ${r.log.join('\n  | ')}` : '';
			this.log(
				`${r.kind} ${id} (${meta.version || 'no version'}, ${meta.os || '?'}, ${meta.gpu || '?'}): ${r.message}${where ? ` at ${where}` : ''}${trace}${tail}`,
			);
			while (this.entries.size >= MAX_ENTRIES) this.entries.delete(this.entries.keys().next().value);
		}
		const before = e.count;
		e.count += count;
		e.last = t;
		bump(e.versions, meta.version);
		bump(e.os, meta.os);
		bump(e.gpus, meta.gpu);
		bump(e.drivers, meta.driver);
		if (meta.session && e.sessions.size < MAX_SESSIONS) e.sessions.add(meta.session);
		this.entries.set(id, e);
		// and again whenever it passes another power of ten, so the log shows a
		// common one growing without a line for every time it happens
		let next = 10;
		while (next <= before) next *= 10;
		if (e.count >= next) this.log(`${r.kind} ${id} seen ${e.count} times in ${e.sessions.size} sessions: ${r.message}`);
	}

	// Everything since the service started, the most common first.
	summary() {
		const errors = [...this.entries.values()]
			.toSorted((a, b) => b.count - a.count || (a.last < b.last ? 1 : -1))
			.map(({ sessions, ...e }) => ({ ...e, sessions: sessions.size }));
		return { received: this.received, errors };
	}
}
