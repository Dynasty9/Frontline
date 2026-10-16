// Frontline's matchmaker: a small JSON-over-HTTP service that keeps the list
// of games players are hosting and finds a game for anyone pressing "Find
// Match". It never carries game traffic: players still connect to the host
// directly over ENet (UDP), exactly as with "Join Game".
//
// No dependencies beyond Node itself (20 or newer).

import { timingSafeEqual } from 'node:crypto';
import { readFileSync } from 'node:fs';
import http from 'node:http';
import { pathToFileURL } from 'node:url';
import { AuthError, createAuth, toUser } from './auth.js';
import { ErrorLog, MAX_BODY as MAX_ERRORS, ReportError } from './errors.js';
import { HEARTBEAT_S, Lobbies, POLL_S } from './lobbies.js';
import { careerOf, cleanRecord, isUuid, MAX_BODY as MAX_RECORD, RecordError } from './records.js';

const MAX_BODY = 8 * 1024;
// routes that take more than that: a battle's after-action report, a batch of error reports
const BODY_LIMITS = { 'POST /me/battles': MAX_RECORD, 'POST /errors': MAX_ERRORS };

// The latest release of the game, baked in by the release workflow
// (.github/workflows/release.yml writes it in the release's pull request, and
// merging that redeploys us): the game's updater asks here which version is
// current and where to get it.
export function loadRelease(file = new URL('../release.json', import.meta.url)) {
	try {
		return JSON.parse(readFileSync(file, 'utf8'));
	} catch {
		return null;
	}
}

class HttpError extends Error {
	constructor(status, message) {
		super(message);
		this.status = status;
	}
}

// Fixed-window request counts per address and bucket: enough to stop someone
// hammering the sign-in or flooding the list, not a defence against a botnet.
class RateLimit {
	constructor(now = Date.now) {
		this.now = now;
		this.map = new Map();
	}
	hit(bucket, ip, limit, windowMs = 60_000) {
		const k = `${bucket}|${ip}`;
		const t = this.now();
		let e = this.map.get(k);
		if (!e || e.reset < t) {
			if (this.map.size > 50_000) this.map.clear();
			e = { n: 0, reset: t + windowMs };
			this.map.set(k, e);
		}
		e.n++;
		if (e.n > limit) throw new HttpError(429, 'Too many requests: wait a minute and try again.');
	}
}

// The player's public address. Behind Railway's proxy (or any proxy we've been
// told to trust) that's the first X-Forwarded-For hop; IPv4 arriving on an
// IPv6 socket is unwrapped so it matches what ENet expects.
function clientIp(req, trustProxy) {
	let ip = req.socket.remoteAddress || '';
	if (trustProxy) {
		const fwd = req.headers['x-forwarded-for'];
		if (fwd) ip = String(fwd).split(',')[0].trim();
		else if (req.headers['x-real-ip']) ip = String(req.headers['x-real-ip']).trim();
	}
	return ip.startsWith('::ffff:') ? ip.slice(7) : ip;
}

async function readJson(req, max = MAX_BODY) {
	if (req.method === 'GET' || req.method === 'HEAD') return {};
	const chunks = [];
	let size = 0;
	for await (const c of req) {
		size += c.length;
		if (size > max) throw new HttpError(413, 'Request too large.');
		chunks.push(c);
	}
	if (size === 0) return {};
	try {
		const v = JSON.parse(Buffer.concat(chunks).toString('utf8'));
		return v && typeof v === 'object' && !Array.isArray(v) ? v : {};
	} catch {
		throw new HttpError(400, 'Body is not valid JSON.');
	}
}

function send(res, status, data) {
	if (res.destroyed) return; // the caller hung up (a host's long poll, say)
	const body = JSON.stringify(data);
	res.writeHead(status, {
		'Content-Type': 'application/json; charset=utf-8',
		'Content-Length': Buffer.byteLength(body),
		'Cache-Control': 'no-store',
		'Access-Control-Allow-Origin': '*',
	});
	res.end(body);
}

const lobbyToken = (req) => String(req.headers['x-lobby-token'] || '');

const bearer = (req) => {
	const h = String(req.headers.authorization || '');
	return h.startsWith('Bearer ') ? h.slice(7).trim() : '';
};

const sameSecret = (a, b) => {
	const x = Buffer.from(String(a));
	const y = Buffer.from(String(b));
	return x.length === y.length && timingSafeEqual(x, y);
};

export function createServer({
	env = process.env,
	auth = createAuth(env),
	lobbies = new Lobbies(),
	release = loadRelease(),
	log = console.log,
	errors = new ErrorLog({ log }),
} = {}) {
	const trustProxy = env.TRUST_PROXY ? env.TRUST_PROXY === '1' : !!(env.RAILWAY_ENVIRONMENT_NAME || env.RAILWAY_ENVIRONMENT);
	const limits = new RateLimit();

	const needAuth = () => {
		if (!auth) throw new HttpError(503, 'Accounts are not enabled on this server.');
	};
	// The signed-in player, if any. A bad or expired token on a route where the
	// account is optional is an error, not a silent fall back to anonymous: the
	// game refreshes its token and tries again.
	const account = async (req, required) => {
		const token = bearer(req);
		if (!token) {
			if (required) throw new HttpError(401, 'Sign in first.');
			return null;
		}
		needAuth();
		const user = await auth.user(token);
		if (!user) throw new HttpError(401, 'Your sign-in has expired.');
		return { ...user, token };
	};

	const routes = {
		'GET /health': async () => ({ ok: true, accounts: auth ? auth.name : 'off', release: release?.version ?? null, ...lobbies.stats() }),

		'GET /release': async () => {
			if (!release) throw new HttpError(404, 'No release has been published yet.');
			return release;
		},

		'GET /lobbies': async ({ url }) => ({ lobbies: lobbies.list(url.searchParams.get('version') || '') }),

		'POST /lobbies': async ({ req, ip, body }) => {
			limits.hit('host', ip, 12);
			const r = lobbies.create(ip, body, await account(req, false));
			if (r.error) throw new HttpError(400, r.error);
			const l = r.lobby;
			log(
				`lobby ${l.id} up: ${l.host} at ${ip}:${l.port}, stun ${l.punch ? `${l.punch.ip}:${l.punch.port}` : 'none'}, nat ${l.nat}, ${l.version || 'no version'}`,
			);
			return { id: l.id, token: l.token, address: ip, heartbeat: HEARTBEAT_S, poll: POLL_S, lobby: lobbies.view(l) };
		},

		// unknown lobby on any of the host's calls: it expired, or the matchmaker
		// restarted. The host just lists it again.
		'POST /lobbies/:id/heartbeat': async ({ req, params, body }) => {
			if (!lobbies.heartbeat(params.id, lobbyToken(req), body)) throw new HttpError(404, 'No such lobby.');
			return { ok: true };
		},

		'POST /lobbies/:id/poll': async ({ req, res, params, url }) => {
			const wait = Math.min(POLL_S, Math.max(0, Number(url.searchParams.get('wait') ?? POLL_S) || 0));
			const token = lobbyToken(req);
			const pending = lobbies.poll(params.id, token, wait * 1000);
			// A host always has a poll open, so that connection dropping before
			// we answer means the game quit, crashed or lost its network: take
			// the listing down now instead of letting players try it until it
			// times out. (If it was only a blip, the host's next poll gets a 404
			// and lists the battle again.)
			res.on('close', () => {
				if (!res.writableFinished && lobbies.remove(params.id, token)) log(`lobby ${params.id} gone: its host hung up`);
			});
			const joins = await pending;
			if (!joins) throw new HttpError(404, 'No such lobby.');
			return { joins };
		},

		'DELETE /lobbies/:id': async ({ req, params }) => {
			const ok = lobbies.remove(params.id, lobbyToken(req));
			if (ok) log(`lobby ${params.id} closed`);
			return { ok };
		},

		// body: the joiner's STUN endpoint {ip, port}, if it has one
		'POST /lobbies/:id/join': async ({ ip, params, body }) => {
			limits.hit('join', ip, 30);
			const r = lobbies.join(params.id, ip, body);
			if (!r) throw new HttpError(404, 'That battle is no longer listed.');
			return r;
		},

		'POST /match': async ({ ip, body }) => {
			limits.hit('match', ip, 30);
			const exclude = Array.isArray(body.exclude) ? body.exclude.slice(0, 32) : [];
			return { lobby: lobbies.match(String(body.version || ''), exclude) };
		},

		'POST /auth/signup': async ({ ip, body }) => {
			needAuth();
			limits.hit('auth', ip, 10);
			return auth.signup(body.email, body.password, body.callsign);
		},

		'POST /auth/login': async ({ ip, body }) => {
			needAuth();
			limits.hit('auth', ip, 10);
			return { session: await auth.login(body.email, body.password) };
		},

		'POST /auth/refresh': async ({ ip, body }) => {
			needAuth();
			limits.hit('refresh', ip, 30);
			return { session: await auth.refresh(body.refresh_token) };
		},

		'POST /auth/logout': async ({ req }) => {
			needAuth();
			const token = bearer(req);
			if (token) await auth.logout(token);
			return { ok: true };
		},

		'GET /me': async ({ req }) => ({ user: toUser(await account(req, true)) }),

		// {callsign, icon}, either or both. Renaming counts against the sign-in
		// limit as it always has; a player trying on insignia gets more goes.
		'PATCH /me': async ({ req, ip, body }) => {
			if (body.callsign !== undefined) limits.hit('auth', ip, 10);
			else limits.hit('icon', ip, 30);
			const a = await account(req, true);
			if (body.callsign === undefined && body.icon === undefined) throw new HttpError(400, 'Nothing to change.');
			return { user: await auth.updateProfile(a.token, a, { callsign: body.callsign, icon: body.icon }) };
		},

		// The battle clock, started when a signed-in player's battle begins.
		// There's no game server to referee a battle (players host them), so
		// the game reports its own result. The time it's worth is measured here,
		// on our clock, from this call to the end: a modified game can't claim
		// hours of play in seconds, so XP is bounded by real time played.
		// Calling it again starts over, forfeiting a battle left open.
		'POST /me/battle': async ({ req, ip }) => {
			limits.hit('battle', ip, 20);
			const a = await account(req, true);
			await auth.beginBattle(a.token, a);
			return { ok: true };
		},

		// {result: "win" | "loss" | "left", seconds}: {gained, rank_before, user}
		'POST /me/battle/end': async ({ req, ip, body }) => {
			limits.hit('battle', ip, 20);
			const a = await account(req, true);
			return auth.endBattle(a.token, a, body.result, body.seconds);
		},

		// the player's service record: every battle they fought signed in
		'POST /me/battles': async ({ req, ip, body }) => {
			limits.hit('record', ip, 20);
			const a = await account(req, true);
			return auth.saveBattle(a.token, a, cleanRecord(body));
		},

		// newest first; ?before=<played_at of the last one you have> for more
		'GET /me/battles': async ({ req, ip, url }) => {
			limits.hit('records', ip, 60);
			const a = await account(req, true);
			const limit = Math.min(50, Math.max(1, Number(url.searchParams.get('limit')) || 20));
			const before = String(url.searchParams.get('before') || '');
			if (before && Number.isNaN(Date.parse(before))) throw new HttpError(400, 'before: a time, please.');
			const rows = await auth.listBattles(a.token, a, { limit: limit + 1, before });
			return { battles: rows.slice(0, limit), more: rows.length > limit };
		},

		'GET /me/battles/:id': async ({ req, ip, params }) => {
			limits.hit('records', ip, 60);
			const a = await account(req, true);
			if (!isUuid(params.id)) throw new HttpError(404, 'No such battle.');
			const b = await auth.getBattle(a.token, a, params.id);
			if (!b) throw new HttpError(404, 'No such battle.');
			return { battle: b };
		},

		// errors from players' games (see errors.js): anyone may send them, and
		// only whoever holds ERRORS_TOKEN can read the tally back
		'POST /errors': async ({ ip, body }) => {
			limits.hit('errors', ip, 12);
			return errors.add(body);
		},

		'GET /errors': async ({ req }) => {
			if (!env.ERRORS_TOKEN) throw new HttpError(404, 'Not found.');
			if (!sameSecret(bearer(req), env.ERRORS_TOKEN)) throw new HttpError(401, 'That token is not the one.');
			return errors.summary();
		},

		// the totals of every battle on the record
		'GET /me/career': async ({ req, ip }) => {
			limits.hit('records', ip, 60);
			const a = await account(req, true);
			const rows = [];
			let before = '';
			for (let page = 0; page < 10; page++) {
				const got = await auth.listBattles(a.token, a, { limit: 500, before });
				rows.push(...got);
				if (got.length < 500) break;
				before = got[got.length - 1].played_at;
			}
			return { career: careerOf(rows) };
		},
	};

	// "METHOD /path/:param" -> matcher
	const table = Object.entries(routes).map(([key, fn]) => {
		const [method, path] = key.split(' ');
		const parts = path.split('/');
		return { method, parts, fn, max: BODY_LIMITS[key] || MAX_BODY };
	});
	const route = (method, pathname) => {
		const segs = pathname.replace(/\/+$/, '').split('/');
		if (segs.length === 1) segs.push('');
		let pathFound = false;
		for (const r of table) {
			if (r.parts.length !== segs.length) continue;
			const params = {};
			if (!r.parts.every((p, i) => (p.startsWith(':') ? ((params[p.slice(1)] = decodeURIComponent(segs[i])), true) : p === segs[i]))) continue;
			pathFound = true;
			if (r.method === method) return { fn: r.fn, params, max: r.max };
		}
		return pathFound ? 'method' : null;
	};

	return http.createServer(async (req, res) => {
		const ip = clientIp(req, trustProxy);
		try {
			if (req.method === 'OPTIONS') {
				res.writeHead(204, {
					'Access-Control-Allow-Origin': '*',
					'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE',
					'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Lobby-Token',
				});
				return res.end();
			}
			const url = new URL(req.url, 'http://x');
			const r = route(req.method, url.pathname);
			if (r === null) throw new HttpError(404, 'Not found.');
			if (r === 'method') throw new HttpError(405, 'Method not allowed.');
			limits.hit('all', ip, 240);
			const body = await readJson(req, r.max);
			send(res, 200, await r.fn({ req, res, ip, url, body, params: r.params }));
		} catch (e) {
			if (e instanceof HttpError || e instanceof AuthError || e instanceof RecordError || e instanceof ReportError)
				return send(res, e.status, { error: e.message });
			log(`error on ${req.method} ${req.url}: ${e && e.stack ? e.stack : e}`);
			send(res, 500, { error: 'Server error.' });
		}
	});
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
	const port = Number(process.env.PORT) || 8080;
	const auth = createAuth();
	const server = createServer({ auth });
	server.listen(port, () => {
		console.log(`Frontline matchmaker on port ${port}; accounts: ${auth ? auth.name : 'off (set SUPABASE_URL and SUPABASE_KEY)'}`);
	});
	const stop = () => server.close(() => process.exit(0));
	process.on('SIGTERM', stop);
	process.on('SIGINT', stop);
}
