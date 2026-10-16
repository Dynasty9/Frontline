// End-to-end tests against a real server on a random port. Run: npm test

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createAuth } from '../src/auth.js';
import { Lobbies } from '../src/lobbies.js';
import { createServer } from '../src/server.js';

async function start(env) {
	const server = createServer({ env, auth: createAuth(env), log: () => {} });
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
		const mission = reg.create('10.0.0.2', { port: 7002, version: 'v', mode: 'mission', mission: 'Bridgehead\u0007', side: 0, teams: [1, 0], spectators: 1 }).lobby;
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
