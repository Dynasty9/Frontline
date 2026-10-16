// Accounts are optional. Matchmaking works without them; an account ties a
// callsign to a player, so no one else can register it, battles they host are
// listed as theirs (verified), and the battles they play earn XP towards a rank
// and the insignia that come with it (ranks.js).
//
// Players sign in with GitHub, on the website (which signs the game in too).
// The page keeps a PKCE verifier and sends only its challenge (oauthUrl), so
// the code GitHub's sign-in comes back with is no use to anyone else
// (exchange). Email and password are for testing.
//
// Two backends with the same interface:
//   supabase  Supabase Auth for the users, and a `profiles` table for the
//             callsign, insignia and record (supabase/migrations/). Needs only
//             the project URL and its public (anon / publishable) key:
//             row-level security lets each user read and rename only their own
//             profile, and XP is only ever written by the database's own
//             functions, which time each battle on the database's clock.
//   memory    in-process, for local testing only (AUTH_BACKEND=memory).
// With neither configured, accounts are switched off.

import { createHash, randomBytes, randomUUID, scryptSync, timingSafeEqual } from 'node:crypto';
import { battleXp, insignia, isResult, lockedMessage, progress, rankOf, STARTER_ICON, unlocked } from './ranks.js';
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

// The sign-in providers players may use, and what a page asking for one sends:
// where to come back to, and its PKCE challenge (base64url SHA-256, 43 chars).
const PROVIDERS = new Set(['github']);

function checkOAuth(provider, redirectTo, challenge) {
	if (!PROVIDERS.has(provider)) throw new AuthError(400, 'Sign in with GitHub.');
	let u;
	try {
		u = new URL(String(redirectTo ?? ''));
	} catch {
		u = null;
	}
	if (!u || (u.protocol !== 'https:' && u.protocol !== 'http:')) throw new AuthError(400, 'Say which page to come back to.');
	if (!/^[A-Za-z0-9_-]{43,128}$/.test(String(challenge ?? ''))) throw new AuthError(400, 'A sign-in needs its PKCE challenge.');
	return u;
}

const s256 = (verifier) =>
	createHash('sha256')
		.update(String(verifier ?? ''))
		.digest('base64url');

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

	// One of our database functions (supabase/migrations/), run as the player.
	rpc(fn, token, body = {}) {
		return this.call(`/rest/v1/rpc/${fn}`, { method: 'POST', token, body });
	}

	static failed(r, fallback) {
		if (r.status === 401) return new AuthError(401, 'Your sign-in has expired.');
		// a function this matchmaker expects isn't in the database yet: it was
		// deployed a moment before its migration (see profile())
		if (r.status === 404 || r.data?.code === 'PGRST202') return new AuthError(503, 'The account service is being updated: try again in a minute.');
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

	// Every column there is, not a list: Railway deploys the matchmaker and the
	// Database workflow migrates the database independently, so for a minute
	// either can be ahead. A column this code knows and the database doesn't have yet
	// reads as its default (toUser) instead of failing the whole profile.
	async profile(id, token) {
		const r = await this.call(`/rest/v1/profiles?id=eq.${encodeURIComponent(id)}&select=*`, { token });
		return r.ok && Array.isArray(r.data) && r.data[0] ? r.data[0] : {};
	}

	async signup(email, password, callsign) {
		checkCredentials(email, password);
		callsign = checkCallsign(callsign);
		const taken = await this.call('/rest/v1/rpc/callsign_taken', { method: 'POST', body: { name: callsign } });
		if (taken.ok && taken.data === true) throw new AuthError(409, 'That callsign is taken.');
		// the profile row is made by a trigger from this metadata (supabase/migrations/)
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

	// Where to send the player to sign in with GitHub: Supabase's page, which
	// comes back to `redirectTo` with ?code= (if Supabase's Redirect URLs allow
	// it; otherwise to its Site URL).
	oauthUrl(provider, redirectTo, challenge) {
		const back = checkOAuth(provider, redirectTo, challenge);
		const q = new URLSearchParams({ provider, redirect_to: back.href, code_challenge: challenge, code_challenge_method: 's256' });
		return `${this.url}/auth/v1/authorize?${q}`;
	}

	// The code GitHub's sign-in came back with, and the verifier only the page
	// that asked for it has: a session. A player new to Frontline gets their
	// profile from the database, named after their GitHub account.
	async exchange(code, verifier) {
		const r = await this.call('/auth/v1/token?grant_type=pkce', {
			method: 'POST',
			body: { auth_code: String(code ?? ''), code_verifier: String(verifier ?? '') },
		});
		if (!r.ok) throw new AuthError(r.status === 429 ? 429 : 401, SupabaseAuth.message(r.data, 'That sign-in ran out: try again.'));
		return this.session(r.data);
	}

	async refresh(refreshToken) {
		const r = await this.call('/auth/v1/token?grant_type=refresh_token', { method: 'POST', body: { refresh_token: String(refreshToken ?? '') } });
		if (!r.ok) throw new AuthError(401, 'Signed out: please sign in again.');
		return this.session(r.data);
	}

	// This session only: the game and the website each hold one of their own
	// (the website signs the game in), and signing out of one leaves the
	// other. Supabase's default would end every session the account has.
	async logout(token) {
		this.cache.drop(token);
		await this.call('/auth/v1/logout?scope=local', { method: 'POST', token });
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
				method: 'PATCH',
				token,
				body: { callsign },
				headers: { Prefer: 'return=minimal' },
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

	// --- service records (battle_records, supabase/migrations/; row-level security keeps
	// each player to their own)

	static noTable(r) {
		// the table isn't there: the migrations haven't reached this project
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

// Local testing only: forgets everything on restart. Ranks follow the same
// rules as the SQL in supabase/migrations/.
class MemoryAuth {
	constructor({ now = Date.now } = {}) {
		this.name = 'memory';
		this.now = now; // the battle clock (tests fake a battle's length with it)
		this.users = new Map(); // email -> {id, email, callsign, salt, hash, icon, xp, battles, wins, battleStarted}
		this.access = new Map(); // token -> {user, until}
		this.refreshTokens = new Map(); // token -> email
		this.codes = new Map(); // a GitHub sign-in on its way: code -> {challenge, until}
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
		const u = {
			id: randomUUID(),
			email,
			callsign,
			salt,
			hash: MemoryAuth.hash(password, salt),
			icon: STARTER_ICON,
			xp: 0,
			battles: 0,
			wins: 0,
			battleStarted: null,
		};
		this.users.set(email, u);
		return { session: this.issue(u), confirm: false };
	}

	async login(email, password) {
		const u = this.users.get(String(email ?? '').toLowerCase());
		// a GitHub player has no password
		if (!u?.hash || !timingSafeEqual(u.hash, MemoryAuth.hash(password, u.salt))) throw new AuthError(401, 'Invalid login credentials');
		return this.issue(u);
	}

	// A stand-in for GitHub: back at once, signed in as the one local GitHub
	// player, so the website's whole round trip runs without the real thing.
	oauthUrl(provider, redirectTo, challenge) {
		const back = checkOAuth(provider, redirectTo, challenge);
		const code = randomBytes(16).toString('base64url');
		this.codes.set(code, { challenge, until: Date.now() + 300_000 });
		back.searchParams.set('code', code);
		return back.href;
	}

	async exchange(code, verifier) {
		const c = this.codes.get(String(code ?? ''));
		this.codes.delete(String(code ?? ''));
		if (!c || c.until < Date.now() || s256(verifier) !== c.challenge) throw new AuthError(401, 'That sign-in ran out: try again.');
		const email = 'github-player@users.test';
		if (!this.users.has(email)) {
			let callsign = 'GitHub Player';
			for (let n = 2; this.taken(callsign); n++) callsign = `GitHub Player ${n}`;
			this.users.set(email, { id: randomUUID(), email, callsign, icon: STARTER_ICON, xp: 0, battles: 0, wins: 0, battleStarted: null });
		}
		return this.issue(this.users.get(email));
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
