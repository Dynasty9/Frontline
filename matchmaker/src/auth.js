// Accounts are optional. Matchmaking works without them; an account only ties a
// callsign to a player, so no one else can register it, and battles they host
// are listed as theirs (verified).
//
// Two backends with the same interface:
//   supabase  Supabase Auth for the users, and a `profiles` table for the
//             callsign (supabase/schema.sql). Needs only the project URL and
//             its public (anon / publishable) key: row-level security lets each
//             user read and rename only their own profile.
//   memory    in-process, for local testing only (AUTH_BACKEND=memory).
// With neither configured, accounts are switched off.

import { randomBytes, randomUUID, scryptSync, timingSafeEqual } from 'node:crypto';
import { HEAD } from './records.js';

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

export function createAuth(env = process.env) {
	const url = env.SUPABASE_URL;
	const key = env.SUPABASE_KEY || env.SUPABASE_PUBLISHABLE_KEY || env.SUPABASE_ANON_KEY;
	if (url && key) return new SupabaseAuth(url.replace(/\/+$/, ''), key);
	if (env.AUTH_BACKEND === 'memory') return new MemoryAuth();
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

	async session(data) {
		const user = { id: data.user.id, email: data.user.email, callsign: await this.callsign(data.user.id, data.access_token) };
		this.cache.set(data.access_token, user);
		return { access_token: data.access_token, refresh_token: data.refresh_token, expires_in: data.expires_in, user };
	}

	async callsign(id, token) {
		const r = await this.call(`/rest/v1/profiles?id=eq.${encodeURIComponent(id)}&select=callsign`, { token });
		return r.ok && Array.isArray(r.data) && r.data[0] ? r.data[0].callsign : '';
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
		const user = { id: r.data.id, email: r.data.email, callsign: await this.callsign(r.data.id, token) };
		this.cache.set(token, user);
		return user;
	}

	async setCallsign(token, user, callsign) {
		callsign = checkCallsign(callsign);
		const r = await this.call(`/rest/v1/profiles?id=eq.${encodeURIComponent(user.id)}`, {
			method: 'PATCH',
			token,
			body: { callsign },
			headers: { Prefer: 'return=minimal' },
		});
		if (r.status === 409 || r.data?.code === '23505') throw new AuthError(409, 'That callsign is taken.');
		if (!r.ok) throw new AuthError(400, SupabaseAuth.message(r.data, 'Could not change the callsign.'));
		user.callsign = callsign;
		this.cache.set(token, user);
		return user;
	}

	// --- service records (battle_records in schema.sql; row-level security keeps
	// each player to their own)

	static noTable(r) {
		// the table isn't there: schema.sql hasn't been run on this project
		if (r.status === 404 || r.data?.code === 'PGRST205' || r.data?.code === '42P01')
			throw new AuthError(503, 'Battle records are not set up on this server yet.');
	}

	async saveBattle(token, user, rec) {
		const r = await this.call('/rest/v1/battle_records?select=id,played_at', {
			method: 'POST',
			token,
			body: { ...rec, user_id: user.id },
			headers: { Prefer: 'return=representation' },
		});
		SupabaseAuth.noTable(r);
		if (!r.ok || !Array.isArray(r.data) || !r.data[0])
			throw new AuthError(r.status >= 500 ? 503 : 400, SupabaseAuth.message(r.data, 'Could not record the battle.'));
		return { id: r.data[0].id, played_at: r.data[0].played_at };
	}

	async listBattles(token, user, { limit = 20, before = '' } = {}) {
		let q = `/rest/v1/battle_records?select=${HEAD.join(',')}&user_id=eq.${encodeURIComponent(user.id)}&order=played_at.desc&limit=${limit}`;
		if (before) q += `&played_at=lt.${encodeURIComponent(before)}`;
		const r = await this.call(q, { token });
		SupabaseAuth.noTable(r);
		if (!r.ok || !Array.isArray(r.data)) throw new AuthError(503, SupabaseAuth.message(r.data, 'Could not read your battles.'));
		return r.data;
	}

	async getBattle(token, user, id) {
		const r = await this.call(`/rest/v1/battle_records?select=*&id=eq.${encodeURIComponent(id)}&user_id=eq.${encodeURIComponent(user.id)}`, { token });
		SupabaseAuth.noTable(r);
		if (!r.ok || !Array.isArray(r.data)) throw new AuthError(503, SupabaseAuth.message(r.data, 'Could not read that battle.'));
		return r.data[0] || null;
	}
}

// Local testing only: forgets everything on restart.
class MemoryAuth {
	constructor() {
		this.name = 'memory';
		this.users = new Map(); // email -> {id, email, callsign, salt, hash}
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
		return { access_token: access, refresh_token: refresh, expires_in: 3600, user: { id: u.id, email: u.email, callsign: u.callsign } };
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
		const u = { id: randomUUID(), email, callsign, salt, hash: MemoryAuth.hash(password, salt) };
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
		return { id: e.user.id, email: e.user.email, callsign: e.user.callsign };
	}

	async setCallsign(token, user, callsign) {
		callsign = checkCallsign(callsign);
		if (this.taken(callsign, user.id)) throw new AuthError(409, 'That callsign is taken.');
		this.users.get(user.email).callsign = callsign;
		return { ...user, callsign };
	}

	// service records: user id -> rows, oldest first
	battles(user) {
		if (!this.records) this.records = new Map();
		if (!this.records.has(user.id)) this.records.set(user.id, []);
		return this.records.get(user.id);
	}

	async saveBattle(token, user, rec) {
		const rows = this.battles(user);
		// the clock may not have moved since the last one: keep them in order
		const last = rows.length ? Date.parse(rows[rows.length - 1].played_at) : 0;
		const row = { id: randomUUID(), user_id: user.id, played_at: new Date(Math.max(Date.now(), last + 1)).toISOString(), ...rec };
		rows.push(row);
		return { id: row.id, played_at: row.played_at };
	}

	async listBattles(token, user, { limit = 20, before = '' } = {}) {
		const rows = this.battles(user).filter((r) => !before || r.played_at < before);
		// newest first
		const out = [];
		for (let i = rows.length - 1; i >= Math.max(0, rows.length - limit); i--) {
			out.push(Object.fromEntries(HEAD.map((k) => [k, rows[i][k]])));
		}
		return out;
	}

	async getBattle(token, user, id) {
		return this.battles(user).find((r) => r.id === id) || null;
	}
}
