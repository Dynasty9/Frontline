// Accounts are optional. Matchmaking works without them; an account ties a
// callsign to a player, so no one else can register it, battles they host are
// listed as theirs (verified), and the battles they play earn XP towards a rank
// and the insignia that come with it (ranks.js).
//
// Two backends with the same interface:
//   supabase  Supabase Auth for the users, and a `profiles` table for the
//             callsign, insignia and record (supabase/schema.sql). Needs only
//             the project URL and its public (anon / publishable) key:
//             row-level security lets each user read and rename only their own
//             profile, and XP is only ever written by the database's own
//             functions, which time each battle on the database's clock.
//   memory    in-process, for local testing only (AUTH_BACKEND=memory).
// With neither configured, accounts are switched off.

import { randomBytes, randomUUID, scryptSync, timingSafeEqual } from 'node:crypto';
import { battleXp, insignia, isResult, lockedMessage, progress, rankOf, STARTER_ICON, unlocked } from './ranks.js';

export class AuthError extends Error {
	constructor(status, message) {
		super(message);
		this.status = status;
	}
}

export const CALLSIGN_RE = /^[A-Za-z0-9 _.-]{3,20}$/;

export function checkCallsign(c) {
	const s = String(c ?? '').trim();
	if (!CALLSIGN_RE.test(s)) throw new AuthError(400, 'Callsigns are 3-20 letters, digits, spaces, _ . or -.');
	return s;
}

function checkCredentials(email, password) {
	if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email ?? ''))) throw new AuthError(400, 'That email address does not look right.');
	if (String(password ?? '').length < 8) throw new AuthError(400, 'Passwords need at least 8 characters.');
}

// A known insignia (whether this player may wear it is another matter).
export function checkIcon(id) {
	const ins = insignia(id);
	if (!ins) throw new AuthError(400, 'No such insignia.');
	return ins;
}

// What the game reports when a battle ends: how it went, and how long it ran.
function checkBattleEnd(result, seconds) {
	if (!isResult(result)) throw new AuthError(400, 'A battle ends in a "win", a "loss" or "left".');
	if (typeof seconds !== 'number' || !Number.isFinite(seconds) || seconds < 0) throw new AuthError(400, 'Say how long the battle ran, in seconds.');
}

// A player as the game and the website see them, wherever a user is returned.
// Only the XP is stored: the rank and where it begins and ends follow from it.
export function toUser(u) {
	return {
		id: u.id,
		email: u.email,
		callsign: u.callsign ?? '',
		icon: u.icon ?? STARTER_ICON,
		...progress(u.xp ?? 0),
		battles: u.battles ?? 0,
		wins: u.wins ?? 0,
	};
}

// `now` is the memory backend's battle clock (tests fake a battle's length with
// it); Supabase times battles on the database's own.
export function createAuth(env = process.env, { now } = {}) {
	const url = env.SUPABASE_URL;
	const key = env.SUPABASE_KEY || env.SUPABASE_PUBLISHABLE_KEY || env.SUPABASE_ANON_KEY;
	if (url && key) return new SupabaseAuth(url.replace(/\/+$/, ''), key);
	if (env.AUTH_BACKEND === 'memory') return new MemoryAuth({ now });
	return null;
}

// Verified access tokens are remembered for a minute so that a host checking in
// every few seconds doesn't cost a round trip to Supabase each time.
class TokenCache {
	constructor(ttlMs = 60_000, max = 5000) {
		this.ttlMs = ttlMs;
		this.max = max;
		this.map = new Map();
	}
	get(token) {
		const e = this.map.get(token);
		if (!e) return null;
		if (e.until < Date.now()) {
			this.map.delete(token);
			return null;
		}
		return e.user;
	}
	set(token, user) {
		if (this.map.size >= this.max) this.map.clear();
		this.map.set(token, { user, until: Date.now() + this.ttlMs });
	}
	drop(token) {
		this.map.delete(token);
	}
}

class SupabaseAuth {
	constructor(url, key) {
		this.name = 'supabase';
		this.url = url;
		this.key = key;
		this.cache = new TokenCache();
	}

	async call(path, { method = 'GET', body, token, headers = {} } = {}) {
		const h = { apikey: this.key, 'Content-Type': 'application/json', ...headers };
		// the user's token when acting as them; the legacy anon key is itself a
		// JWT and goes in both headers, the newer publishable keys only in apikey
		if (token) h.Authorization = `Bearer ${token}`;
		else if (this.key.startsWith('eyJ')) h.Authorization = `Bearer ${this.key}`;
		let res;
		try {
			res = await fetch(this.url + path, { method, headers: h, body: body === undefined ? undefined : JSON.stringify(body) });
		} catch {
			throw new AuthError(503, 'The account service is unreachable.');
		}
		const text = await res.text();
		let data = null;
		try {
			data = text ? JSON.parse(text) : null;
		} catch {
			data = null;
		}
		return { status: res.status, ok: res.ok, data };
	}

	static message(data, fallback) {
		return (data && (data.msg || data.error_description || data.message || data.error)) || fallback;
	}

	// One of our database functions (schema.sql), run as the player.
	rpc(fn, token, body = {}) {
		return this.call(`/rest/v1/rpc/${fn}`, { method: 'POST', token, body });
	}

	static failed(r, fallback) {
		if (r.status === 401) return new AuthError(401, 'Your sign-in has expired.');
		return new AuthError(r.status >= 500 ? 503 : 400, SupabaseAuth.message(r.data, fallback));
	}

	remember(token, u) {
		const user = toUser(u);
		this.cache.set(token, user);
		return user;
	}

	async session(data) {
		const user = this.remember(data.access_token, { id: data.user.id, email: data.user.email, ...(await this.profile(data.user.id, data.access_token)) });
		return { access_token: data.access_token, refresh_token: data.refresh_token, expires_in: data.expires_in, user };
	}

	async profile(id, token) {
		const r = await this.call(`/rest/v1/profiles?id=eq.${encodeURIComponent(id)}&select=callsign,icon,xp,battles,wins`, { token });
		return r.ok && Array.isArray(r.data) && r.data[0] ? r.data[0] : {};
	}

	async signup(email, password, callsign) {
		checkCredentials(email, password);
		callsign = checkCallsign(callsign);
		const taken = await this.call('/rest/v1/rpc/callsign_taken', { method: 'POST', body: { name: callsign } });
		if (taken.ok && taken.data === true) throw new AuthError(409, 'That callsign is taken.');
		// the profile row is made by a trigger from this metadata (schema.sql)
		const r = await this.call('/auth/v1/signup', { method: 'POST', body: { email, password, data: { callsign } } });
		if (!r.ok) throw new AuthError(r.status === 429 ? 429 : 400, SupabaseAuth.message(r.data, 'Could not create the account.'));
		// with "Confirm email" on, Supabase sends a link and there's no session yet
		if (!r.data.access_token) return { session: null, confirm: true };
		return { session: await this.session(r.data), confirm: false };
	}

	async login(email, password) {
		const r = await this.call('/auth/v1/token?grant_type=password', { method: 'POST', body: { email, password } });
		if (!r.ok) throw new AuthError(r.status === 429 ? 429 : 401, SupabaseAuth.message(r.data, 'Wrong email or password.'));
		return this.session(r.data);
	}

	async refresh(refreshToken) {
		const r = await this.call('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: { refresh_token: String(refreshToken ?? '') } });
		if (!r.ok) throw new AuthError(401, 'Signed out: please sign in again.');
		return this.session(r.data);
	}

	async logout(token) {
		this.cache.drop(token);
		await this.call('/auth/v1/logout', { method: 'POST', token });
	}

	async user(token) {
		const hit = this.cache.get(token);
		if (hit) return hit;
		const r = await this.call('/auth/v1/user', { token });
		if (!r.ok || !r.data?.id) return null;
		return this.remember(token, { id: r.data.id, email: r.data.email, ...(await this.profile(r.data.id, token)) });
	}

	// {callsign, icon}, either or both. The callsign is the one column a player
	// may write directly; the insignia goes through set_icon(), which checks
	// it's been unlocked.
	async updateProfile(token, user, { callsign, icon }) {
		if (callsign !== undefined) callsign = checkCallsign(callsign);
		const ins = icon !== undefined ? checkIcon(icon) : null;
		let u = user;
		if (ins) {
			const r = await this.rpc('set_icon', token, { icon: ins.id });
			if (r.data?.code === 'PT403') throw new AuthError(403, lockedMessage(ins));
			if (!r.ok) throw SupabaseAuth.failed(r, 'Could not change the insignia.');
			u = this.remember(token, { ...u, icon: ins.id });
		}
		if (callsign !== undefined) {
			const r = await this.call(`/rest/v1/profiles?id=eq.${encodeURIComponent(user.id)}`, {
				method: 'PATCH', token, body: { callsign }, headers: { Prefer: 'return=minimal' },
			});
			if (r.status === 409 || r.data?.code === '23505') throw new AuthError(409, 'That callsign is taken.');
			if (!r.ok) throw new AuthError(400, SupabaseAuth.message(r.data, 'Could not change the callsign.'));
			u = this.remember(token, { ...u, callsign });
		}
		return toUser(u);
	}

	async beginBattle(token) {
		const r = await this.rpc('begin_battle', token);
		if (!r.ok) throw SupabaseAuth.failed(r, 'Could not start the battle clock.');
	}

	async endBattle(token, user, result, seconds) {
		checkBattleEnd(result, seconds);
		const r = await this.rpc('end_battle', token, { result, seconds });
		if (!r.ok || !r.data) throw SupabaseAuth.failed(r, 'Could not record the battle.');
		const d = r.data;
		const u = this.remember(token, { ...user, callsign: d.callsign, icon: d.icon, xp: d.xp, battles: d.battles, wins: d.wins });
		return { gained: d.gained, rank_before: d.rank_before, user: u };
	}
}

// Local testing only: forgets everything on restart. Ranks follow the same
// rules as the SQL in schema.sql.
class MemoryAuth {
	constructor({ now = Date.now } = {}) {
		this.name = 'memory';
		this.now = now; // the battle clock (tests fake a battle's length with it)
		this.users = new Map(); // email -> {id, email, callsign, salt, hash, icon, xp, battles, wins, battleStarted}
		this.access = new Map(); // token -> {user, until}
		this.refreshTokens = new Map(); // token -> email
	}

	static hash(password, salt) {
		return scryptSync(String(password), salt, 32);
	}

	issue(u) {
		const access = randomBytes(24).toString('base64url');
		const refresh = randomBytes(24).toString('base64url');
		this.access.set(access, { user: u, until: Date.now() + 3600_000 });
		this.refreshTokens.set(refresh, u.email);
		return { access_token: access, refresh_token: refresh, expires_in: 3600, user: toUser(u) };
	}

	taken(callsign, exceptId = null) {
		for (const u of this.users.values()) if (u.id !== exceptId && u.callsign.toLowerCase() === callsign.toLowerCase()) return true;
		return false;
	}

	async signup(email, password, callsign) {
		checkCredentials(email, password);
		callsign = checkCallsign(callsign);
		email = String(email).toLowerCase();
		if (this.users.has(email)) throw new AuthError(400, 'User already registered');
		if (this.taken(callsign)) throw new AuthError(409, 'That callsign is taken.');
		const salt = randomBytes(16);
		const u = { id: randomUUID(), email, callsign, salt, hash: MemoryAuth.hash(password, salt), icon: STARTER_ICON, xp: 0, battles: 0, wins: 0, battleStarted: null };
		this.users.set(email, u);
		return { session: this.issue(u), confirm: false };
	}

	async login(email, password) {
		const u = this.users.get(String(email ?? '').toLowerCase());
		if (!u || !timingSafeEqual(u.hash, MemoryAuth.hash(password, u.salt))) throw new AuthError(401, 'Invalid login credentials');
		return this.issue(u);
	}

	async refresh(refreshToken) {
		const email = this.refreshTokens.get(String(refreshToken ?? ''));
		if (!email) throw new AuthError(401, 'Signed out: please sign in again.');
		this.refreshTokens.delete(refreshToken);
		return this.issue(this.users.get(email));
	}

	async logout(token) {
		this.access.delete(token);
	}

	async user(token) {
		const e = this.access.get(token);
		if (!e || e.until < Date.now()) return null;
		return toUser(e.user);
	}

	async updateProfile(token, user, { callsign, icon }) {
		const u = this.users.get(user.email);
		if (callsign !== undefined) {
			callsign = checkCallsign(callsign);
			if (this.taken(callsign, u.id)) throw new AuthError(409, 'That callsign is taken.');
		}
		const ins = icon !== undefined ? checkIcon(icon) : null;
		if (ins && !unlocked(ins, rankOf(u.xp))) throw new AuthError(403, lockedMessage(ins));
		// all of it or none of it
		if (callsign !== undefined) u.callsign = callsign;
		if (ins) u.icon = ins.id;
		return toUser(u);
	}

	async beginBattle(token, user) {
		this.users.get(user.email).battleStarted = this.now();
	}

	// An end with no battle open is a retry of one already counted (or a battle
	// the clock never heard about), so it earns and counts nothing.
	async endBattle(token, user, result, seconds) {
		checkBattleEnd(result, seconds);
		const u = this.users.get(user.email);
		const rankBefore = rankOf(u.xp);
		let gained = 0;
		if (u.battleStarted !== null) {
			gained = battleXp(result, (this.now() - u.battleStarted) / 1000, seconds);
			if (result !== 'left') u.battles++;
			if (result === 'win') u.wins++;
		}
		u.xp += gained;
		u.battleStarted = null;
		return { gained, rank_before: rankBefore, user: toUser(u) };
	}
}
