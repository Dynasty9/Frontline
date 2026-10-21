import assert from 'node:assert/strict';
import http from 'node:http';
import { test } from 'node:test';
import { createAuth } from '../src/auth.js';
import { createServer } from '../src/server.js';

test('website authorizes a separate game session, with no caller-selected identity', async (t) => {
	const auth = createAuth({ AUTH_BACKEND: 'memory' });
	const { session: site } = await auth.signup('site@example.test', 'password1', 'Commander');
	const server = createServer({ auth, env: {}, log: () => {} });
	await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
	t.after(() => {
		server.closeAllConnections();
		server.close();
	});
	const base = `http://127.0.0.1:${server.address().port}`;
	const request = (token) =>
		fetch(base + '/auth/game', {
			method: 'POST',
			headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
			body: JSON.stringify({ email: 'someone-else@example.test', id: 'someone-else' }),
		});
	assert.equal((await request('invalid')).status, 401);
	assert.equal((await request('')).status, 401);
	const response = await request(site.access_token);
	assert.equal(response.headers.get('cache-control'), 'no-store');
	const { token } = await response.json();
	assert.notEqual(token, site.refresh_token);
	const game = await auth.refresh(token);
	const browser = await auth.refresh(site.refresh_token);
	assert.equal(game.user.id, site.user.id);
	assert.equal(browser.user.id, site.user.id);
	assert.notEqual(game.refresh_token, browser.refresh_token);
	await auth.logout(game.access_token);
	assert.equal((await auth.user(browser.access_token)).id, site.user.id);
});

test('Supabase handoff verifies the bearer and consumes a server-only link for that exact account', async (t) => {
	const seen = [];
	let valid = true;
	let mismatch = false;
	const server = http.createServer(async (req, res) => {
		let text = '';
		for await (const chunk of req) text += chunk;
		const body = text ? JSON.parse(text) : null;
		seen.push({ path: req.url, headers: req.headers, body });
		res.setHeader('Content-Type', 'application/json');
		const send = (data) => res.end(JSON.stringify(data));
		if (req.url === '/auth/v1/user') {
			assert.equal(req.headers.authorization, 'Bearer browser-access');
			if (!valid) {
				res.statusCode = 401;
				return send({});
			}
			return send({ id: 'u1', email: 'verified@example.test', email_confirmed_at: '2026-01-01' });
		}
		if (req.url === '/auth/v1/admin/generate_link') {
			assert.equal(req.headers.apikey, 'server-secret');
			assert.equal(req.headers.authorization, 'Bearer server-secret');
			assert.deepEqual(body, { type: 'magiclink', email: 'verified@example.test' });
			return send({ id: mismatch ? 'other-user' : 'u1', hashed_token: 'one-time-hash' });
		}
		assert.equal(req.headers.apikey, 'public-key');
		if (req.url === '/auth/v1/verify') {
			assert.deepEqual(body, { type: 'magiclink', token_hash: 'one-time-hash' });
			return send({ access_token: 'game-access', refresh_token: 'game-refresh', expires_in: 3600, user: { id: 'u1', email: 'verified@example.test' } });
		}
		assert.equal(req.headers.authorization, 'Bearer game-access');
		assert.match(req.url, /^\/rest\/v1\/profiles/);
		return send([{ callsign: 'Commander' }]);
	});
	await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
	t.after(() => {
		server.closeAllConnections();
		server.close();
	});
	const env = { SUPABASE_URL: `http://127.0.0.1:${server.address().port}`, SUPABASE_KEY: 'public-key', SUPABASE_SECRET_KEY: 'server-secret' };
	const auth = createAuth(env);
	assert.equal((await auth.gameSession('browser-access')).refresh_token, 'game-refresh');
	assert.equal(seen.length, 4);
	valid = false;
	await assert.rejects(auth.gameSession('browser-access'), { status: 401 });
	assert.equal(seen.length, 5, 'a rejected bearer must not reach the admin API');
	valid = true;
	mismatch = true;
	await assert.rejects(auth.gameSession('browser-access'), { status: 503 });
	assert.equal(seen.length, 7, 'a different identity must not be verified');
	const unconfigured = createAuth({ ...env, SUPABASE_SECRET_KEY: undefined });
	await assert.rejects(unconfigured.gameSession('browser-access'), { status: 503 });
	assert.equal(seen.length, 8);
});
