// End-to-end tests against a real server on a random port. Run: npm test

import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { test } from 'node:test';
import { createAuth } from '../src/auth.js';
import { ErrorLog, MAX_ENTRIES } from '../src/errors.js';
import { Lobbies } from '../src/lobbies.js';
import { battleXp, insignia, MAX_RANK, progress, rankOf, xpFor } from '../src/ranks.js';
import { createServer } from '../src/server.js';

async function start(env, authOptions) {
	const server = createServer({ env, auth: createAuth(env, authOptions), log: () => {} });
	await new Promise((r) => server.listen(0, '127.0.0.1', r));
	// don't hold the test run open once the tests are done
	server.unref();
	const base = `http://127.0.0.1:${server.address().port}`;
	const call = async (method, path, body, headers = {}) => {
		const res = await fetch(base + path, {
			method,
			headers: { 'Content-Type': 'application/json', ...headers },
			body: body === undefined ? undefined : JSON.stringify(body),
		});
		return { status: res.status, data: await res.json() };
	};
	return { server, call, base };
}

const open = await start({});
const withAccounts = await start({ AUTH_BACKEND: 'memory' });
const reporting = await start({ ERRORS_TOKEN: 'tally-token' });
// For the ranks: the battle clock is ours to wind on, and each player calls
// from an address of their own (X-Forwarded-For) so the rate limits don't mix.
let clock = 1_000_000;
const ranked = await start({ AUTH_BACKEND: 'memory', TRUST_PROXY: '1' }, { now: () => clock });

// --- matchmaking without accounts
{
	const s = open;

	test('health says accounts are off', async () => {
		const r = await s.call('GET', '/health');
		assert.equal(r.status, 200);
		assert.equal(r.data.accounts, 'off');
	});

	test('host, list, find, join, heartbeat, close', async () => {
		const host = await s.call('POST', '/lobbies', { port: 7777, host: 'Alpha', version: 'v1', max_players: 2, players: 1, lan: '192.168.1.20', nat: 'cone' });
		assert.equal(host.status, 200);
		assert.equal(host.data.address, '127.0.0.1');
		assert.equal(host.data.lobby.host, 'Alpha');
		assert.equal(host.data.lobby.verified, false);
		const { id, token } = host.data;

		const list = await s.call('GET', '/lobbies?version=v1');
		assert.equal(list.data.lobbies.length, 1);
		assert.equal(list.data.lobbies[0].nat, 'cone');
		// addresses are only handed out on join
		assert.equal(list.data.lobbies[0].address, undefined);
		assert.equal((await s.call('GET', '/lobbies?version=v2')).data.lobbies.length, 0);

		// same public address as the host: we're handed its LAN address
		const j = await s.call('POST', `/lobbies/${id}/join`, {});
		assert.deepEqual(j.data.connect, { address: '192.168.1.20', port: 7777, via: 'lan' });
		assert.equal((await s.call('POST', '/lobbies/nope/join', {})).status, 404);

		// a different version never matches
		assert.equal((await s.call('POST', '/match', { version: 'v2' })).data.lobby, null);
		const m = await s.call('POST', '/match', { version: 'v1' });
		assert.equal(m.data.lobby.id, id);
		// that seat is held for the player we sent, so the 2-player game is now full
		assert.equal((await s.call('POST', '/match', { version: 'v1' })).data.lobby, null);

		assert.equal((await s.call('POST', `/lobbies/${id}/heartbeat`, { players: 1 }, { 'X-Lobby-Token': 'wrong' })).status, 404);
		const hb = await s.call('POST', `/lobbies/${id}/heartbeat`, { players: 2, in_game: true, drop_in: false }, { 'X-Lobby-Token': token });
		assert.equal(hb.status, 200);
		assert.equal((await s.call('GET', '/lobbies')).data.lobbies[0].in_game, true);

		assert.equal((await s.call('DELETE', `/lobbies/${id}`, undefined, { 'X-Lobby-Token': 'wrong' })).data.ok, false);
		assert.equal((await s.call('DELETE', `/lobbies/${id}`, undefined, { 'X-Lobby-Token': token })).data.ok, true);
		assert.equal((await s.call('GET', '/lobbies')).data.lobbies.length, 0);
	});

	test('the host hears about a joiner on its long poll', async () => {
		const host = await s.call('POST', '/lobbies', { port: 7790, punch: { ip: '127.0.0.1', port: 50123 } });
		const { id, token } = host.data;
		const t0 = Date.now();
		const poll = s.call('POST', `/lobbies/${id}/poll?wait=10`, undefined, { 'X-Lobby-Token': token });
		await new Promise((r) => setTimeout(r, 100));
		const j = await s.call('POST', `/lobbies/${id}/join`, { ip: '127.0.0.1', port: 40404 });
		// no LAN address given: we connect to the host's STUN endpoint
		assert.deepEqual(j.data.connect, { address: '127.0.0.1', port: 50123, via: 'punch' });
		const p = await poll;
		assert.equal(p.status, 200);
		assert.deepEqual(p.data.joins, [{ ip: '127.0.0.1', port: 40404 }]);
		assert.ok(Date.now() - t0 < 2000, 'the poll returned as soon as someone joined');

		// nobody joins: the poll times out empty
		const idle = await s.call('POST', `/lobbies/${id}/poll?wait=0.2`, undefined, { 'X-Lobby-Token': token });
		assert.deepEqual(idle.data.joins, []);
		// closing the lobby ends a pending poll with 404, so the host lists again
		const gone = s.call('POST', `/lobbies/${id}/poll?wait=10`, undefined, { 'X-Lobby-Token': token });
		await new Promise((r) => setTimeout(r, 50));
		await s.call('DELETE', `/lobbies/${id}`, undefined, { 'X-Lobby-Token': token });
		assert.equal((await gone).status, 404);
	});

	test('a host hanging up its poll takes the listing down', async () => {
		const host = await s.call('POST', '/lobbies', { port: 7791, version: 'hangup' });
		const { id, token } = host.data;
		const ctl = new AbortController();
		const poll = fetch(`${s.base}/lobbies/${id}/poll?wait=10`, { method: 'POST', headers: { 'X-Lobby-Token': token }, signal: ctl.signal }).catch(() => null);
		await new Promise((r) => setTimeout(r, 100));
		assert.equal((await s.call('GET', '/lobbies?version=hangup')).data.lobbies.length, 1);
		ctl.abort();
		await poll;
		await new Promise((r) => setTimeout(r, 100));
		assert.equal((await s.call('GET', '/lobbies?version=hangup')).data.lobbies.length, 0);
	});

	test('the release the matchmaker was deployed with', async () => {
		const r = await s.call('GET', '/release');
		assert.equal(r.status, 200);
		assert.match(r.data.version, /^\d+\.\d+\.\d+$/);
		assert.equal(r.data.tag, `v${r.data.version}`);
		for (const p of ['windows', 'linux']) {
			assert.match(r.data.assets[p].url, new RegExp(`/releases/download/v${r.data.version}/Frontline-${p}\\.zip$`));
			assert.match(r.data.assets[p].sha256, /^[0-9a-f]{64}$/);
		}
		assert.equal((await s.call('GET', '/health')).data.release, r.data.version);
	});

	test('bad input is refused', async () => {
		assert.equal((await s.call('POST', '/lobbies', { port: 80 })).status, 400);
		assert.equal((await s.call('POST', '/lobbies', { port: 'x' })).status, 400);
		assert.equal((await s.call('GET', '/nope')).status, 404);
		assert.equal((await s.call('PUT', '/lobbies')).status, 405);
		assert.equal((await s.call('POST', '/auth/login', { email: 'a@b.cd', password: 'x' })).status, 503);
		// a token on an optional-account route, with accounts off
		assert.equal((await s.call('POST', '/lobbies', { port: 7777 }, { Authorization: 'Bearer abc' })).status, 503);
	});
}

// --- matchmaking with accounts (memory backend)
{
	const s = withAccounts;

	test('sign up, sign in, refresh, rename, host as yourself', async () => {
		assert.equal((await s.call('POST', '/auth/signup', { email: 'bad', password: 'longenough', callsign: 'Viper' })).status, 400);
		assert.equal((await s.call('POST', '/auth/signup', { email: 'a@b.cd', password: 'short', callsign: 'Viper' })).status, 400);
		assert.equal((await s.call('POST', '/auth/signup', { email: 'a@b.cd', password: 'longenough', callsign: 'x' })).status, 400);

		const up = await s.call('POST', '/auth/signup', { email: 'a@b.cd', password: 'longenough', callsign: 'Viper' });
		assert.equal(up.status, 200);
		assert.equal(up.data.session.user.callsign, 'Viper');
		assert.equal((await s.call('POST', '/auth/signup', { email: 'z@b.cd', password: 'longenough', callsign: 'viper' })).status, 409);

		assert.equal((await s.call('POST', '/auth/login', { email: 'a@b.cd', password: 'wrongwrong' })).status, 401);
		const login = await s.call('POST', '/auth/login', { email: 'A@b.cd', password: 'longenough' });
		assert.equal(login.status, 200);
		const auth = { Authorization: `Bearer ${login.data.session.access_token}` };
		assert.equal((await s.call('GET', '/me', undefined, auth)).data.user.callsign, 'Viper');
		assert.equal((await s.call('GET', '/me')).status, 401);

		const ref = await s.call('POST', '/auth/refresh', { refresh_token: login.data.session.refresh_token });
		assert.equal(ref.status, 200);
		// refresh tokens are single use
		assert.equal((await s.call('POST', '/auth/refresh', { refresh_token: login.data.session.refresh_token })).status, 401);

		const auth2 = { Authorization: `Bearer ${ref.data.session.access_token}` };
		assert.equal((await s.call('PATCH', '/me', { callsign: 'Viper Two' }, auth2)).data.user.callsign, 'Viper Two');

		// the listing carries the account's callsign, not what the client claims
		const host = await s.call('POST', '/lobbies', { port: 7777, host: 'Somebody Else' }, auth2);
		assert.equal(host.data.lobby.host, 'Viper Two');
		assert.equal(host.data.lobby.verified, true);
		// hosting again replaces your listing
		const again = await s.call('POST', '/lobbies', { port: 7778 }, auth2);
		const list = (await s.call('GET', '/lobbies')).data.lobbies;
		assert.equal(list.length, 1);
		assert.equal(list[0].id, again.data.id);

		assert.equal((await s.call('POST', '/lobbies', { port: 7777 }, { Authorization: 'Bearer expired' })).status, 401);
		await s.call('POST', '/auth/logout', undefined, auth2);
		assert.equal((await s.call('GET', '/me', undefined, auth2)).status, 401);
	});
}

// --- one account, two sessions: the website signs the game in with a session of
// its own, and signing out of either leaves the other signed in
{
	test('signing out ends that session only', async () => {
		const ip = { 'X-Forwarded-For': '10.8.0.1' };
		const bearer = (session) => ({ ...ip, Authorization: `Bearer ${session.access_token}` });
		const cred = { email: 'two@places.io', password: 'longenough' };
		assert.equal((await ranked.call('POST', '/auth/signup', { ...cred, callsign: 'Two Places' }, ip)).status, 200);
		const game = (await ranked.call('POST', '/auth/login', cred, ip)).data.session;
		const site = (await ranked.call('POST', '/auth/login', cred, ip)).data.session;
		await ranked.call('POST', '/auth/logout', undefined, bearer(site));
		assert.equal((await ranked.call('GET', '/me', undefined, bearer(site))).status, 401);
		assert.equal((await ranked.call('GET', '/me', undefined, bearer(game))).status, 200);
		assert.equal((await ranked.call('POST', '/auth/refresh', { refresh_token: game.refresh_token }, ip)).status, 200);
	});

	test('Supabase is asked to end that session, not every one the account has', async () => {
		const auth = createAuth({ SUPABASE_URL: 'https://db.test', SUPABASE_KEY: 'sb_publishable_test' });
		const realFetch = globalThis.fetch;
		const urls = [];
		globalThis.fetch = async (url) => {
			urls.push(String(url));
			return new Response(null, { status: 204 });
		};
		try {
			await auth.logout('access-token');
		} finally {
			globalThis.fetch = realFetch;
		}
		assert.deepEqual(urls, ['https://db.test/auth/v1/logout?scope=local']);
	});
}

// --- signing in with GitHub: the page keeps a PKCE verifier and sends its
// challenge; the code it comes back with is only any use with that verifier
{
	const verifier = 'v'.repeat(43);
	const challenge = createHash('sha256').update(verifier).digest('base64url');
	const PAGE = 'https://site.test/';

	test('GitHub sign-in: off to sign in, back with a code, swapped for a session', async () => {
		const ip = { 'X-Forwarded-For': '10.8.1.1' };
		const go = await ranked.call('POST', '/auth/oauth', { provider: 'github', redirect_to: PAGE, code_challenge: challenge }, ip);
		assert.equal(go.status, 200);
		// the stand-in for GitHub comes straight back to the page
		const back = new URL(go.data.url);
		assert.equal(back.origin + back.pathname, PAGE);
		const code = back.searchParams.get('code');
		const r = await ranked.call('POST', '/auth/exchange', { code, code_verifier: verifier }, ip);
		assert.equal(r.status, 200);
		assert.equal(r.data.session.user.callsign, 'GitHub Player');
		const me = await ranked.call('GET', '/me', undefined, { ...ip, Authorization: `Bearer ${r.data.session.access_token}` });
		assert.equal(me.data.user.callsign, 'GitHub Player');
		// a code works once
		assert.equal((await ranked.call('POST', '/auth/exchange', { code, code_verifier: verifier }, ip)).status, 401);
	});

	test("GitHub sign-in: a code is no use without the page's verifier", async () => {
		const ip = { 'X-Forwarded-For': '10.8.1.2' };
		const go = await ranked.call('POST', '/auth/oauth', { provider: 'github', redirect_to: PAGE, code_challenge: challenge }, ip);
		const code = new URL(go.data.url).searchParams.get('code');
		assert.equal((await ranked.call('POST', '/auth/exchange', { code, code_verifier: 'w'.repeat(43) }, ip)).status, 401);
	});

	test('GitHub sign-in: a provider, a page to come back to and a challenge, or nothing', async () => {
		const ip = { 'X-Forwarded-For': '10.8.1.3' };
		const go = (body) => ranked.call('POST', '/auth/oauth', { provider: 'github', redirect_to: PAGE, code_challenge: challenge, ...body }, ip);
		assert.equal((await go({ provider: 'myspace' })).status, 400);
		assert.equal((await go({ redirect_to: 'javascript:alert(1)' })).status, 400);
		assert.equal((await go({ code_challenge: 'short' })).status, 400);
		assert.equal((await open.call('POST', '/auth/oauth', { provider: 'github', redirect_to: PAGE, code_challenge: challenge })).status, 503);
	});

	test('GitHub sign-in with Supabase: its authorize page with the challenge, then the PKCE grant', async () => {
		const auth = createAuth({ SUPABASE_URL: 'https://db.test', SUPABASE_KEY: 'sb_publishable_test' });
		const url = new URL(auth.oauthUrl('github', PAGE, challenge));
		assert.equal(url.origin + url.pathname, 'https://db.test/auth/v1/authorize');
		assert.deepEqual(Object.fromEntries(url.searchParams), {
			provider: 'github',
			redirect_to: PAGE,
			code_challenge: challenge,
			code_challenge_method: 's256',
		});
		const realFetch = globalThis.fetch;
		const calls = [];
		globalThis.fetch = async (u, init) => {
			calls.push([String(u), init.body && JSON.parse(init.body)]);
			if (String(u).includes('/auth/v1/token')) {
				return Response.json({ access_token: 'a', refresh_token: 'r', expires_in: 3600, user: { id: 'u1', email: 'octo@github.test' } });
			}
			return Response.json([{ id: 'u1', callsign: 'octocat', xp: 0 }]);
		};
		try {
			const s = await auth.exchange('the-code', verifier);
			assert.equal(s.refresh_token, 'r');
			assert.equal(s.user.callsign, 'octocat');
		} finally {
			globalThis.fetch = realFetch;
		}
		assert.deepEqual(calls[0], ['https://db.test/auth/v1/token?grant_type=pkce', { auth_code: 'the-code', code_verifier: verifier }]);
	});
}

// --- ranks, XP and insignia
{
	const s = ranked;
	const minutes = (m) => {
		clock += m * 60_000;
	};
	let n = 0;
	// a new player, signed in, calling from their own address
	const player = async () => {
		n++;
		const ip = { 'X-Forwarded-For': `10.9.0.${n}` };
		const up = await s.call('POST', '/auth/signup', { email: `p${n}@ranks.io`, password: 'longenough', callsign: `Ranker ${n}` }, ip);
		assert.equal(up.status, 200);
		const h = { ...ip, Authorization: `Bearer ${up.data.session.access_token}` };
		const call = (method, path, body) => s.call(method, path, body, h);
		// a whole battle: started, `wall` minutes on our clock, then ended
		const battle = async (result, wall, seconds = wall * 60) => {
			assert.equal((await call('POST', '/me/battle')).status, 200);
			minutes(wall);
			const r = await call('POST', '/me/battle/end', { result, seconds });
			assert.equal(r.status, 200);
			return r.data;
		};
		return { ip, h, call, battle, session: up.data.session };
	};

	test('the XP curve: 150 for rank 1, 32,000 for rank 50, and no further', () => {
		assert.equal(xpFor(0), 0);
		assert.equal(xpFor(1), 150);
		assert.equal(xpFor(2), 320);
		assert.equal(xpFor(MAX_RANK), 32000);
		assert.equal(rankOf(0), 0);
		assert.equal(rankOf(149), 0);
		assert.equal(rankOf(150), 1);
		assert.equal(rankOf(31999), 49);
		assert.equal(rankOf(32000), 50);
		assert.equal(rankOf(10_000_000), 50);
		assert.equal(rankOf(-5), 0);
		for (let r = 1; r <= MAX_RANK; r++) {
			assert.equal(rankOf(xpFor(r) - 1), r - 1);
			assert.equal(rankOf(xpFor(r)), r);
		}
		assert.deepEqual(progress(0), { xp: 0, rank: 0, rank_xp: 0, next_xp: 150 });
		assert.deepEqual(progress(1234), { xp: 1234, rank: 6, rank_xp: 1200, next_xp: 1470 });
		assert.deepEqual(progress(40000), { xp: 40000, rank: 50, rank_xp: 32000, next_xp: null });
	});

	test('insignia ids: ten starters, a patch per rank, awards and units locked', () => {
		assert.deepEqual(insignia('s01'), { id: 's01', group: 'starter', unlock: 0 });
		assert.deepEqual(insignia('s10'), { id: 's10', group: 'starter', unlock: 0 });
		assert.deepEqual(insignia('r07'), { id: 'r07', group: 'rank', unlock: 7 });
		assert.deepEqual(insignia('r50'), { id: 'r50', group: 'rank', unlock: 50 });
		assert.deepEqual(insignia('m01'), { id: 'm01', group: 'award', unlock: null });
		assert.deepEqual(insignia('u50'), { id: 'u50', group: 'unit', unlock: null });
		for (const bad of ['s00', 's11', 'r00', 'r51', 'm51', 'x01', 'R01', 'r1', 'r001', ' s01', '', null, undefined, 5, {}]) {
			assert.equal(insignia(bad), null, String(bad));
		}
	});

	test('battle XP: a point per tenth of a minute, times the result', () => {
		assert.equal(battleXp('loss', 1200, 1200), 200);
		assert.equal(battleXp('win', 1200, 1200), 300);
		assert.equal(battleXp('left', 1200, 1200), 100);
		assert.equal(battleXp('left', 1206, 1206), 100); // 201 tenths, halved and rounded down
		// under two minutes is nothing; two minutes exactly counts
		assert.equal(battleXp('win', 119.9, 600), 0);
		assert.equal(battleXp('win', 120, 600), 30);
		// the shorter of our clock and the game's, at most 45 minutes
		assert.equal(battleXp('loss', 1800, 300), 50);
		assert.equal(battleXp('loss', 300, 1800), 50);
		assert.equal(battleXp('win', 86400, 86400), 675);
	});

	test('the user object on sign-up, sign-in and /me', async () => {
		const p = await player();
		const fresh = { icon: 's01', xp: 0, rank: 0, rank_xp: 0, next_xp: 150, battles: 0, wins: 0 };
		const keys = ['battles', 'callsign', 'email', 'icon', 'id', 'next_xp', 'rank', 'rank_xp', 'wins', 'xp'];
		const check = (u) => {
			assert.deepEqual(Object.keys(u).toSorted(), keys);
			assert.equal(u.callsign, `Ranker ${n}`);
			for (const [k, v] of Object.entries(fresh)) assert.equal(u[k], v, k);
		};
		check(p.session.user);
		const login = await s.call('POST', '/auth/login', { email: `p${n}@ranks.io`, password: 'longenough' }, p.ip);
		check(login.data.session.user);
		check((await p.call('GET', '/me')).data.user);

		await p.battle('win', 20);
		const me = (await p.call('GET', '/me')).data.user;
		assert.deepEqual([me.xp, me.rank, me.rank_xp, me.next_xp, me.battles, me.wins], [300, 1, 150, 320, 1, 1]);
		// a new sign-in sees the same record
		const again = await s.call('POST', '/auth/login', { email: `p${n}@ranks.io`, password: 'longenough' }, p.ip);
		assert.equal(again.data.session.user.xp, 300);
	});

	test('a battle is worth the time it ran, on our clock', async () => {
		const p = await player();
		// nothing open: nothing gained or counted
		let r = await p.call('POST', '/me/battle/end', { result: 'win', seconds: 1200 });
		assert.equal(r.status, 200);
		assert.deepEqual([r.data.gained, r.data.rank_before, r.data.user.xp, r.data.user.battles], [0, 0, 0, 0]);

		// too short to earn anything (but it was a battle)
		r = await p.battle('win', 1);
		assert.deepEqual([r.gained, r.user.battles, r.user.wins], [0, 1, 1]);

		// a 20-minute win: 200 tenths of a minute, times 1.5
		r = await p.battle('win', 20);
		assert.deepEqual([r.gained, r.rank_before, r.user.xp, r.user.rank, r.user.battles, r.user.wins], [300, 0, 300, 1, 2, 2]);
		// the same end sent twice (a retry) counts once
		r = (await p.call('POST', '/me/battle/end', { result: 'win', seconds: 1200 })).data;
		assert.deepEqual([r.gained, r.user.xp, r.user.battles, r.user.wins], [0, 300, 2, 2]);

		r = await p.battle('loss', 20);
		assert.deepEqual([r.gained, r.rank_before, r.user.rank, r.user.battles, r.user.wins], [200, 1, 2, 3, 2]);
		// leaving is worth half, and isn't a battle fought to the end
		r = await p.battle('left', 20);
		assert.deepEqual([r.gained, r.user.battles, r.user.wins], [100, 3, 2]);

		// the game says 5 minutes of game time (it was paused), our clock 30
		r = await p.battle('loss', 30, 300);
		assert.equal(r.gained, 50);
		// the game claims an hour that took 3 minutes on our clock
		r = await p.battle('win', 3, 3600);
		assert.equal(r.gained, 45);
		// at most 45 minutes count
		r = await p.battle('win', 50, 3000);
		assert.equal(r.gained, 675);
		assert.deepEqual([r.user.xp, r.user.battles, r.user.wins], [300 + 200 + 100 + 50 + 45 + 675, 6, 4]);

		// starting again forfeits the battle left open: the clock starts over
		assert.equal((await p.call('POST', '/me/battle')).status, 200);
		minutes(20);
		r = await p.battle('win', 0, 1200);
		assert.deepEqual([r.gained, r.user.battles], [0, 7]);
	});

	test('a bad battle report is refused and leaves the battle open', async () => {
		const p = await player();
		await p.call('POST', '/me/battle');
		minutes(10);
		const bad = [
			{ result: 'draw', seconds: 600 },
			{ seconds: 600 },
			{ result: 'win' },
			{ result: 'win', seconds: '600' },
			{ result: 'win', seconds: -1 },
			{ result: 'constructor', seconds: 600 },
		];
		for (const body of bad) assert.equal((await p.call('POST', '/me/battle/end', body)).status, 400, JSON.stringify(body));
		const r = await p.call('POST', '/me/battle/end', { result: 'loss', seconds: 600 });
		assert.equal(r.data.gained, 100);
	});

	test('battle routes need a sign-in, and are rate limited', async () => {
		assert.equal((await s.call('POST', '/me/battle')).status, 401);
		assert.equal((await s.call('POST', '/me/battle/end', { result: 'win', seconds: 600 })).status, 401);
		assert.equal((await open.call('POST', '/me/battle')).status, 401);
		assert.equal((await open.call('POST', '/me/battle', {}, { Authorization: 'Bearer abc' })).status, 503);
		const p = await player();
		for (let i = 0; i < 20; i++) assert.equal((await p.call('POST', '/me/battle')).status, 200);
		assert.equal((await p.call('POST', '/me/battle')).status, 429);
	});

	test('insignia: starters for all, rank patches once reached, the rest locked', async () => {
		const p = await player();
		const wear = (icon) => p.call('PATCH', '/me', { icon });
		let r = await wear('s05');
		assert.equal(r.status, 200);
		assert.equal(r.data.user.icon, 's05');
		r = await wear('r05');
		assert.equal(r.status, 403);
		assert.match(r.data.error, /locked.*rank 5/);
		for (const id of ['m01', 'u01', 'm50']) assert.equal((await wear(id)).status, 403, id);
		for (const id of ['junk', 's11', 'r51', 'r00', '', null, 7]) assert.equal((await wear(id)).status, 400, String(id));
		assert.equal((await p.call('PATCH', '/me', {})).status, 400);
		assert.equal((await p.call('GET', '/me')).data.user.icon, 's05');

		// rank 5 is 950 XP: a 45-minute win and a 20-minute one
		await p.battle('win', 45);
		const b = await p.battle('win', 20);
		assert.deepEqual([b.rank_before, b.user.rank], [3, 5]);
		r = await wear('r05');
		assert.equal(r.status, 200);
		assert.equal(r.data.user.icon, 'r05');
		assert.equal((await wear('r06')).status, 403);
		assert.equal((await wear('r01')).status, 200);
		assert.equal((await p.call('GET', '/me')).data.user.icon, 'r01');

		// both at once; a locked insignia changes neither
		r = await p.call('PATCH', '/me', { callsign: 'Patched', icon: 'm01' });
		assert.equal(r.status, 403);
		assert.equal((await p.call('GET', '/me')).data.user.callsign, `Ranker ${n}`);
		r = await p.call('PATCH', '/me', { callsign: 'Patched', icon: 's02' });
		assert.deepEqual([r.status, r.data.user.callsign, r.data.user.icon, r.data.user.rank], [200, 'Patched', 's02', 5]);
	});

	test("a listing shows the host's insignia and rank, and nothing for a guest", async () => {
		const p = await player();
		await p.battle('loss', 45); // 450 XP: rank 2
		await p.call('PATCH', '/me', { icon: 'r02' });
		const host = await s.call('POST', '/lobbies', { port: 7800, version: 'ranked' }, p.h);
		assert.equal(host.status, 200);
		assert.deepEqual([host.data.lobby.verified, host.data.lobby.icon, host.data.lobby.rank], [true, 'r02', 2]);
		const guest = await s.call('POST', '/lobbies', { port: 7801, version: 'ranked', host: 'Guest', players: 2 }, { 'X-Forwarded-For': '10.9.1.1' });
		assert.deepEqual([guest.data.lobby.verified, guest.data.lobby.icon, guest.data.lobby.rank], [false, null, null]);

		const list = (await s.call('GET', '/lobbies?version=ranked')).data.lobbies;
		const byId = Object.fromEntries(list.map((l) => [l.id, l]));
		assert.deepEqual([byId[host.data.id].icon, byId[host.data.id].rank], ['r02', 2]);
		assert.deepEqual([byId[guest.data.id].icon, byId[guest.data.id].rank], [null, null]);
		// quick match hands out the same view (the guest's battle is fuller, so first)
		const m = (await s.call('POST', '/match', { version: 'ranked' }, { 'X-Forwarded-For': '10.9.1.2' })).data.lobby;
		assert.deepEqual([m.id, m.icon, m.rank], [guest.data.id, null, null]);
		const m2 = (await s.call('POST', '/match', { version: 'ranked', exclude: [guest.data.id] }, { 'X-Forwarded-For': '10.9.1.2' })).data.lobby;
		assert.deepEqual([m2.id, m2.icon, m2.rank], [host.data.id, 'r02', 2]);
	});

	// The website's insignia table (web/, which may not have it yet) has to
	// agree with the rules here.
	const table = new URL('../../web/src/lib/insignia.json', import.meta.url);
	test("the website's insignia table agrees with ranks.js", { skip: !existsSync(table) && 'web/src/lib/insignia.json is not there' }, () => {
		const t = JSON.parse(readFileSync(table, 'utf8'));
		assert.deepEqual(
			t.ranks.map((r) => r.rank).toSorted((a, b) => a - b),
			Array.from({ length: MAX_RANK + 1 }, (_, i) => i),
		);
		for (const r of t.ranks) assert.equal(r.xp, xpFor(r.rank), `rank ${r.rank}`);
		const ids = new Set();
		for (const i of t.insignia) {
			const ours = insignia(i.id);
			assert.ok(ours, `${i.id} is an id the matchmaker knows`);
			assert.ok(!ids.has(i.id), `${i.id} is listed once`);
			ids.add(i.id);
			assert.equal(i.group, ours.group, `${i.id} is in the ${ours.group} group`);
			// the same unlock rank (0 for the starters), and no rank claimed
			// for what nobody can unlock yet (the table marks those -1)
			const isRank = Number.isInteger(i.unlock) && i.unlock >= 0 && i.unlock <= MAX_RANK;
			if (ours.unlock === null) assert.ok(!isRank, `${i.id} is locked for everyone`);
			else assert.equal(i.unlock, ours.unlock, `${i.id} unlocks at rank ${ours.unlock}`);
		}
		for (const [g, count] of [
			['s', 10],
			['r', MAX_RANK],
			['m', 50],
			['u', 50],
		]) {
			for (let k = 1; k <= count; k++) assert.ok(ids.has(g + String(k).padStart(2, '0')), `${g}${String(k).padStart(2, '0')} is in the table`);
		}
	});
}

// --- service records (memory backend)
// a battle as the game reports it, with whatever a test changes
const battle = (over = {}) => ({
	game_version: '0.4.0',
	mode: 'skirmish',
	title: 'Skirmish vs AI',
	side: 0,
	result: 'victory',
	duration: 412.6,
	me: { name: 'Hawk', kills: 12, lost: 3, captured: 1, veh_kills: 2, veh_lost: 0, shots: 900, hits: 120, rating: 71.26, score: 640, bogus: 5 },
	report: { t: 412.6, over: true, winner: 0, players: [{ id: 1, name: 'Hawk', team: 0 }], sides: [{}, {}], tl: [[0, 8, 9]] },
	...over,
});

{
	const s = withAccounts;

	test('battles go on your service record, and only yours', async () => {
		const up = await s.call('POST', '/auth/signup', { email: 'rec@b.cd', password: 'longenough', callsign: 'Hawk' });
		const auth = { Authorization: `Bearer ${up.data.session.access_token}` };
		const other = await s.call('POST', '/auth/signup', { email: 'rec2@b.cd', password: 'longenough', callsign: 'Kite' });
		const auth2 = { Authorization: `Bearer ${other.data.session.access_token}` };

		// signed in only, and a battle that makes sense
		assert.equal((await s.call('POST', '/me/battles', battle())).status, 401);
		assert.equal((await s.call('POST', '/me/battles', battle({ result: 'draw' }), auth)).status, 400);
		assert.equal((await s.call('POST', '/me/battles', battle({ mode: 'x' }), auth)).status, 400);
		assert.equal((await s.call('POST', '/me/battles', battle({ side: 2 }), auth)).status, 400);
		assert.equal((await s.call('POST', '/me/battles', battle({ me: null }), auth)).status, 400);
		// a report too big to keep
		assert.equal((await s.call('POST', '/me/battles', battle({ report: { pad: 'x'.repeat(100_000) } }), auth)).status, 400);

		const saved = await s.call('POST', '/me/battles', battle(), auth);
		assert.equal(saved.status, 200);
		assert.ok(saved.data.id);
		await s.call(
			'POST',
			'/me/battles',
			battle({ result: 'defeat', side: 1, mode: 'mission', mission: 'bridgehead', title: 'Bridgehead', me: { kills: 4, lost: 6, rating: 31, score: 90 } }),
			auth,
		);
		await s.call('POST', '/me/battles', battle({ mode: 'coop', me: { kills: 20, lost: 2, rating: 88, score: 1200 } }), auth);
		await s.call('POST', '/me/battles', battle(), auth2);

		const list = await s.call('GET', '/me/battles?limit=2', undefined, auth);
		assert.equal(list.status, 200);
		assert.equal(list.data.battles.length, 2);
		assert.equal(list.data.more, true);
		// newest first, headline numbers only
		assert.equal(list.data.battles[0].mode, 'coop');
		assert.equal(list.data.battles[0].report, undefined);
		const rest = await s.call('GET', `/me/battles?before=${encodeURIComponent(list.data.battles[1].played_at)}`, undefined, auth);
		assert.equal(rest.data.battles.length, 1);
		assert.equal(rest.data.more, false);
		assert.equal(rest.data.battles[0].id, saved.data.id);
		assert.equal(rest.data.battles[0].lost, 4); // killed and captured
		assert.equal(rest.data.battles[0].rating, 71.3);
		assert.equal(rest.data.battles[0].duration_s, 413);

		// the whole battle, report and all; nobody else's
		const one = await s.call('GET', `/me/battles/${saved.data.id}`, undefined, auth);
		assert.equal(one.status, 200);
		assert.equal(one.data.battle.report.winner, 0);
		assert.equal(one.data.battle.me.kills, 12);
		assert.equal(one.data.battle.me.bogus, undefined);
		assert.equal((await s.call('GET', `/me/battles/${saved.data.id}`, undefined, auth2)).status, 404);
		assert.equal((await s.call('GET', '/me/battles/not-an-id', undefined, auth)).status, 404);

		const career = await s.call('GET', '/me/career', undefined, auth);
		assert.equal(career.status, 200);
		const c = career.data.career;
		assert.equal(c.battles, 3);
		assert.equal(c.victories, 2);
		assert.equal(c.defeats, 1);
		assert.equal(c.kills, 36);
		assert.deepEqual(c.sides, [2, 1]);
		assert.equal(c.modes.mission, 1);
		assert.equal(c.best.rating, 88);
		assert.equal((await s.call('GET', '/me/career', undefined, auth2)).data.career.battles, 1);
	});

	test('no accounts, no records', async () => {
		assert.equal((await open.call('GET', '/me/battles', undefined, { Authorization: 'Bearer abc' })).status, 503);
		assert.equal((await open.call('GET', '/me/career')).status, 401);
	});
}

// --- lobby registry
{
	test('quick match prefers open lobbies, then the fullest, then the oldest', () => {
		let t = 1000;
		const reg = new Lobbies({ now: () => t });
		const mk = (port, extra) => reg.create(`10.0.0.${port - 7000}`, { port, version: 'v', ...extra }).lobby;
		const running = mk(7001, { players: 5, in_game: true });
		t += 1;
		const old = mk(7002, { players: 2 });
		t += 1;
		const full = mk(7003, { players: 3 });
		t += 1;
		const newer = mk(7004, { players: 2 });
		t += 1;
		const strict = mk(7005, { players: 3, nat: 'strict' });
		assert.equal(reg.match('v').id, full.id);
		assert.equal(reg.match('v', [full.id]).id, old.id);
		assert.equal(reg.match('v', [full.id, old.id]).id, newer.id);
		assert.equal(reg.match('v', [full.id, old.id, newer.id]).id, strict.id);
		assert.equal(reg.match('v', [full.id, old.id, newer.id, strict.id]).id, running.id);
		assert.equal(reg.match('other'), null);
	});

	test('a battle says what it is, and one with a password is never matched', () => {
		const reg = new Lobbies();
		const coop = reg.create('10.0.0.1', { port: 7001, version: 'v', players: 2, mode: 'coop', side: 1, teams: [0, 2], locked: true }).lobby;
		const mission = reg.create('10.0.0.2', {
			port: 7002,
			version: 'v',
			mode: 'mission',
			mission: 'Bridgehead\u0007',
			side: 0,
			teams: [1, 0],
			spectators: 1,
		}).lobby;
		const v = reg.list('v');
		const c = v.find((l) => l.id === coop.id);
		assert.equal(c.mode, 'coop');
		assert.equal(c.side, 1);
		assert.deepEqual(c.teams, [0, 2]);
		assert.equal(c.locked, true);
		const m = v.find((l) => l.id === mission.id);
		assert.equal(m.mission, 'Bridgehead');
		assert.equal(m.spectators, 1);
		// nonsense is cleaned up rather than passed on
		reg.update(mission, { mode: 'deathmatch', side: 7, teams: ['x', 99], locked: 0 });
		assert.equal(mission.mode, '');
		assert.equal(mission.side, 1);
		assert.deepEqual(mission.teams, [0, 64]);
		assert.equal(mission.locked, false);
		// the fuller battle wants a password: Find Match only offers the other
		assert.equal(reg.match('v').id, mission.id);
		assert.equal(reg.match('v', [mission.id]), null);
	});

	test('a STUN endpoint must come from the address that reports it', async () => {
		const { stunEndpoint } = await import('../src/lobbies.js');
		assert.deepEqual(stunEndpoint({ ip: '5.6.7.8', port: 4000 }, '5.6.7.8'), { ip: '5.6.7.8', port: 4000 });
		assert.equal(stunEndpoint({ ip: '9.9.9.9', port: 4000 }, '5.6.7.8'), null);
		// over IPv6, or from a LAN (local testing), the public IPv4 can't be checked
		assert.deepEqual(stunEndpoint({ ip: '9.9.9.9', port: 4000 }, '2001:db8::1'), { ip: '9.9.9.9', port: 4000 });
		assert.deepEqual(stunEndpoint({ ip: '9.9.9.9', port: 4000 }, '127.0.0.1'), { ip: '9.9.9.9', port: 4000 });
		assert.equal(stunEndpoint({ ip: 'example.com', port: 4000 }, '127.0.0.1'), null);
		assert.equal(stunEndpoint({ ip: '9.9.9.9', port: 0 }, '9.9.9.9'), null);
	});

	test('hosts that stop checking in are dropped', () => {
		let t = 0;
		const reg = new Lobbies({ ttlMs: 45_000, now: () => t });
		const { lobby } = reg.create('10.0.0.1', { port: 7777 });
		t = 30_000;
		assert.ok(reg.heartbeat(lobby.id, lobby.token, {}));
		t = 70_000;
		assert.equal(reg.list('').length, 1);
		t = 80_000;
		assert.equal(reg.list('').length, 0);
		assert.equal(reg.heartbeat(lobby.id, lobby.token, {}), null);
	});

	test('a few listings per address, and only private LAN addresses kept', () => {
		const reg = new Lobbies({ maxPerIp: 2 });
		assert.ok(reg.create('5.5.5.5', { port: 7001, lan: '8.8.8.8' }).lobby.lan === '');
		assert.ok(reg.create('5.5.5.5', { port: 7002, lan: '10.1.2.3' }).lobby.lan === '10.1.2.3');
		assert.ok(reg.create('5.5.5.5', { port: 7003 }).error);
	});
}

// --- error reports
const nodeMissing = (n) => ({
	kind: 'error',
	message: `Node not found: "Squad${n}" (relative to "/root/Main").`,
	condition: 'Method/function failed. Returning: nullptr',
	where: 'get_node (scene/main/node.cpp:1976)',
	context: 'battle',
	backtrace: ['_on_order (res://scripts/game/squad.gd:120)', '_tick (res://scripts/game/world.gd:500)'],
	count: 3,
});

{
	const s = reporting;
	const meta = { game_version: '0.4.0', os: 'Windows 11', gpu: 'Radeon RX 7800', driver: 'vulkan', session: 'a1b2c3d4' };

	test('error reports are tallied, the same error together', async () => {
		const r = await s.call('POST', '/errors', { ...meta, reports: [nodeMissing(4), { kind: 'shader', message: 'Unknown identifier', where: 'water' }] });
		assert.equal(r.status, 200);
		assert.equal(r.data.accepted, 2);
		// the same error with other numbers in it, from another launch on another version
		await s.call('POST', '/errors', { ...meta, game_version: '0.4.1', session: 'e5f6', reports: [nodeMissing(12)] });
		const t = await s.call('GET', '/errors', undefined, { Authorization: 'Bearer tally-token' });
		assert.equal(t.status, 200);
		assert.equal(t.data.received, 2);
		const [top, shader] = t.data.errors;
		assert.equal(top.count, 6);
		assert.equal(top.sessions, 2);
		assert.deepEqual(top.versions, { '0.4.0': 1, '0.4.1': 1 });
		assert.equal(top.gpus['Radeon RX 7800'], 2);
		assert.equal(top.backtrace[0], '_on_order (res://scripts/game/squad.gd:120)');
		assert.equal(top.context, 'battle');
		assert.equal(shader.kind, 'shader');
		assert.equal(shader.count, 1);
	});

	test('only whoever holds the token reads the tally', async () => {
		assert.equal((await s.call('GET', '/errors')).status, 401);
		assert.equal((await s.call('GET', '/errors', undefined, { Authorization: 'Bearer nope' })).status, 401);
		// and without a token configured there is nothing to read
		assert.equal((await open.call('GET', '/errors', undefined, { Authorization: 'Bearer tally-token' })).status, 404);
	});

	test('error reports that are not reports are refused', async () => {
		assert.equal((await s.call('POST', '/errors', { ...meta })).status, 400);
		assert.equal((await s.call('POST', '/errors', { ...meta, reports: [{ kind: 'gossip', message: 'x' }] })).status, 400);
		assert.equal((await s.call('POST', '/errors', { ...meta, reports: [{ kind: 'error' }] })).status, 400);
		const big = { ...meta, reports: [{ kind: 'error', message: 'x'.repeat(60 * 1024) }] };
		assert.equal((await s.call('POST', '/errors', big)).status, 413);
	});

	test('a new error is logged in full once, then as it grows', () => {
		const lines = [];
		const log = new ErrorLog({ log: (l) => lines.push(l) });
		const crash = { kind: 'crash', message: 'Program crashed with signal 11', backtrace: ['_draw (res://scripts/ui/hud.gd:88)'], log: ['ERROR: Invalid mesh'] };
		log.add({ ...meta, reports: [crash] });
		assert.equal(lines.length, 1);
		assert.match(lines[0], /^crash [0-9a-f]{12} \(0\.4\.0, Windows 11, Radeon RX 7800\): Program crashed with signal 11/);
		assert.match(lines[0], /_draw \(res:\/\/scripts\/ui\/hud\.gd:88\)/);
		assert.match(lines[0], /\| ERROR: Invalid mesh/);
		log.add({ ...meta, reports: [{ ...crash, count: 8 }] });
		assert.equal(lines.length, 1);
		log.add({ ...meta, reports: [{ ...crash, count: 150 }] });
		assert.equal(lines.length, 2);
		assert.match(lines[1], /seen 159 times in 1 sessions/);
	});

	test('the tally keeps the errors seen most recently', () => {
		const log = new ErrorLog({ log: () => {} });
		for (let i = 0; i < MAX_ENTRIES + 5; i++) log.add({ reports: [{ kind: 'error', message: 'boom', where: `site ${i}` }] });
		const { errors } = log.summary();
		assert.equal(errors.length, MAX_ENTRIES);
		assert.ok(!errors.some((e) => e.where === 'site 0'));
		assert.ok(errors.some((e) => e.where === `site ${MAX_ENTRIES + 4}`));
	});
}
