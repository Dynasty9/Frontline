// The database's migrations (supabase/migrations/), run on PGlite: Postgres
// itself, compiled to WebAssembly, so no database server is needed. What
// Supabase provides around them (the auth schema, auth.uid() from the player's
// token, the anon and authenticated roles, its default grants) is faked just
// far enough. CI also applies them on Supabase's own Postgres (matchmaker.yml).
//
// They're applied the way the live database got them: the ones before ranks,
// then players signing up, then ranks on top of their rows.
//
// PGlite is a dev dependency, and the service has none at runtime: CI runs the
// other tests without installing anything, so here these skip until it's
// installed (npm ci).

import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { before, test } from 'node:test';
import { MAX_BATTLE_S, rankOf, xpFor } from '../src/ranks.js';
import { careerOf } from '../src/records.js';

const PGlite = await import('@electric-sql/pglite').then(
	(m) => m.PGlite,
	() => null,
);
const NEEDS = PGlite ? {} : { skip: 'PGlite is not installed (npm ci)' };

const DIR = new URL('../supabase/migrations/', import.meta.url);
const files = readdirSync(DIR)
	.filter((f) => f.endsWith('.sql'))
	.toSorted();
const sql = (f) => readFileSync(new URL(f, DIR), 'utf8');

const A = '11111111-1111-1111-1111-111111111111';
const B = '22222222-2222-2222-2222-222222222222';
const C = '33333333-3333-3333-3333-333333333333';

const SUPABASE = `
	create role anon nologin;
	create role authenticated nologin;
	create role service_role nologin bypassrls;
	create schema auth;
	create table auth.users (id uuid primary key, email text, raw_user_meta_data jsonb, created_at timestamptz default now());
	create function auth.uid() returns uuid language sql stable as $$
		select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
	$$;
	grant usage on schema auth to anon, authenticated, service_role;
	grant usage on schema public to anon, authenticated, service_role;
	alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
	alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
	alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
`;

let db;

const signUp = (id, callsign) =>
	db.query(`insert into auth.users (id, email, raw_user_meta_data) values ($1, $2, $3)`, [id, `${callsign}@example.test`, { callsign }]);

// what PostgREST does with a player's token: their id in the claims, their role
const as = (uid, query, params = [], role = 'authenticated') =>
	db.transaction(async (tx) => {
		if (uid) await tx.query(`select set_config('request.jwt.claim.sub', $1, true)`, [uid]);
		await tx.exec(`set local role ${role}`);
		return (await tx.query(query, params)).rows;
	});

async function refused(code, fn) {
	await assert.rejects(fn, (e) => {
		assert.equal(e.code, code, e.message);
		return true;
	});
}

const begin = (uid) => as(uid, 'select public.begin_battle()');
const end = async (uid, result, seconds) => (await as(uid, 'select public.end_battle($1, $2) j', [result, seconds]))[0].j;
// the battle clock, wound back as if the battle had been open that long
const openFor = (uid, ago) => db.query(`update public.profiles set battle_started_at = now() - $2::interval where id = $1`, [uid, ago]);
const wear = (uid, icon) => as(uid, 'select public.set_icon($1)', [icon]);
const profile = async (uid) => (await db.query('select * from public.profiles where id = $1', [uid])).rows[0];

before(async () => {
	if (!PGlite) return;
	db = new PGlite();
	await db.exec(SUPABASE);
	const ranks = files.findIndex((f) => f.endsWith('_ranks.sql'));
	for (const [i, f] of files.entries()) {
		if (i === ranks) {
			// the players already there when ranks went live
			await signUp(A, 'Viper');
			await signUp(B, 'Hawk');
		}
		await db.exec(sql(f));
	}
});

test('migrations are named <timestamp>_<name>.sql, one per timestamp, in order', () => {
	assert.ok(files.length >= 4);
	for (const f of files) assert.match(f, /^\d{14}_[a-z0-9_]+\.sql$/);
	const versions = files.map((f) => f.slice(0, 14));
	assert.equal(new Set(versions).size, versions.length);
});

test('players there before ranks get the defaults, and so does a new one', NEEDS, async () => {
	await signUp(C, 'Raven');
	const rows = (await db.query('select callsign, icon, xp, battles, wins, battle_started_at from public.profiles order by callsign')).rows;
	assert.deepEqual(
		rows.map((r) => [r.callsign, r.icon, r.xp, r.battles, r.wins, r.battle_started_at]),
		[
			['Hawk', 's01', 0, 0, 0, null],
			['Raven', 's01', 0, 0, 0, null],
			['Viper', 's01', 0, 0, 0, null],
		],
	);
});

test('the rank for any XP agrees with ranks.js', NEEDS, async () => {
	const probes = new Set([-5, 0, 32_000, 10_000_000]);
	for (let r = 0; r <= 50; r++) for (const d of [-1, 0, 1]) probes.add(xpFor(r) + d);
	for (const xp of probes) assert.equal((await db.query('select public.frontline_rank($1) r', [xp])).rows[0].r, rankOf(xp), `xp ${xp}`);
});

test('a player reads only their own profile, and can write only the callsign', NEEDS, async () => {
	assert.deepEqual(
		(await as(A, 'select callsign from public.profiles')).map((r) => r.callsign),
		['Viper'],
	);
	await refused('42501', () => as(A, `update public.profiles set xp = 99999 where id = $1`, [A]));
	await refused('42501', () => as(A, `update public.profiles set icon = 'r50' where id = $1`, [A]));
	await refused('42501', () => as(A, `update public.profiles set battle_started_at = now() - interval '9 hours' where id = $1`, [A]));
	await refused('42501', () => as(A, `delete from public.profiles where id = $1`, [A]));
	await as(A, `update public.profiles set callsign = 'Viper2' where id = $1`, [A]);
	assert.equal((await profile(A)).callsign, 'Viper2');
});

test('the rank functions are for signed-in players only', NEEDS, async () => {
	for (const fn of ['frontline_rank(integer)', 'begin_battle()', 'end_battle(text, double precision)', 'set_icon(text)']) {
		const can = async (role) => (await db.query(`select has_function_privilege($1, 'public.${fn}', 'EXECUTE') v`, [role])).rows[0].v;
		assert.equal(await can('authenticated'), true, fn);
		assert.equal(await can('anon'), false, fn);
	}
	// and the sign-up form still asks whether a callsign is taken
	assert.equal((await as(null, `select public.callsign_taken('hawk') t`, [], 'anon'))[0].t, true);
});

test('battles: timed on the database clock, worth their time and result', NEEDS, async () => {
	let j = await end(B, 'win', 1200);
	assert.deepEqual([j.gained, j.battles], [0, 0], 'no battle open: nothing');

	await begin(B);
	await openFor(B, '20 minutes');
	j = await end(B, 'win', 1200);
	assert.deepEqual([j.gained, j.rank_before, j.xp, j.rank, j.battles, j.wins], [300, 0, 300, 1, 1, 1]);
	assert.equal((await profile(B)).battle_started_at, null, 'closed');
	assert.equal((await end(B, 'win', 1200)).gained, 0, 'a retry earns nothing');

	await begin(B);
	await openFor(B, '1 minute');
	j = await end(B, 'win', 600);
	assert.deepEqual([j.gained, j.battles, j.wins], [0, 1, 1], 'under two minutes on our clock: nothing, and not a battle won');

	await begin(B);
	await openFor(B, '30 minutes');
	assert.equal((await end(B, 'loss', 300)).gained, 50, 'the game says 5 minutes: 5 minutes it is');

	await begin(B);
	await openFor(B, '20 minutes');
	j = await end(B, 'left', 1200);
	assert.deepEqual([j.gained, j.battles], [100, 2], 'left: half, and not on the record');

	await begin(B);
	await openFor(B, '3 hours');
	assert.equal((await end(B, 'win', 99_999)).gained, Math.floor((MAX_BATTLE_S / 6) * 1.5), 'capped');

	await begin(B);
	await openFor(B, '20 minutes');
	await begin(B);
	assert.equal((await end(B, 'win', 1200)).gained, 0, 'beginning again restarts the clock');

	await refused('PT400', () => end(B, 'draw', 600));
	await refused('PT400', () => end(B, 'win', -1));
	await refused('PT401', () => as('44444444-4444-4444-4444-444444444444', 'select public.begin_battle()'));
});

test('insignia: starters for all, a rank patch once reached, the rest locked', NEEDS, async () => {
	await wear(C, 's07');
	assert.equal((await profile(C)).icon, 's07');
	await refused('PT403', () => wear(C, 'r01'));
	await db.query('update public.profiles set xp = $2 where id = $1', [C, xpFor(5)]);
	await wear(C, 'r05');
	assert.equal((await profile(C)).icon, 'r05');
	for (const id of ['r06', 'm01', 'u50']) await refused('PT403', () => wear(C, id));
	for (const id of ['', 's11', 'r00', 'r51', 'x01', 'S01']) await refused('PT400', () => wear(C, id));
});

// a player signing in with GitHub for the first time: Supabase's metadata for them, and the callsign they got
const github = async (id, meta) => {
	await db.query(`insert into auth.users (id, email, raw_user_meta_data) values ($1, $2, $3)`, [id, `${id}@github.test`, meta]);
	return (await profile(id)).callsign;
};
const id = (n) => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;

test('signing in with GitHub: the username for a callsign, made to fit and never taken', NEEDS, async () => {
	assert.equal(await github(id(1), { user_name: 'octocat' }), 'octocat');
	// taken, whatever the case: numbered
	assert.equal(await github(id(2), { user_name: 'OctoCat' }), 'OctoCat-2');
	assert.equal(await github(id(3), { user_name: 'octocat' }), 'octocat-3');
	// too long for a callsign: cut, and still room for the number
	assert.equal(await github(id(4), { user_name: 'a-very-long-github-username' }), 'a-very-long-github-u');
	assert.equal(await github(id(5), { user_name: 'a-very-long-github-username' }), 'a-very-long-github-2');
	// what a callsign can't have goes, and too little left is Commander-<id>
	assert.equal(await github(id(6), { preferred_username: 'tab\tby!' }), 'tabby');
	assert.equal(await github(id(7), { user_name: 'xy' }), 'Commander-000000');
	assert.equal(await github(id(8), {}), 'Commander-000000-2');
	// a callsign typed at sign-up is still taken as it is, or refused
	await refused('23505', () => signUp(id(9), 'octocat'));
});

// --- public profiles and leaderboards

const D = id(101);
const E = id(102);
const F = id(103);
const anon = async (query, params = []) => (await as(null, query, params, 'anon'))[0];
const card = async (name) => (await anon('select public.player_card($1) j', [name])).j;
const board = async (period, lim = 50, off = 0, me = null) => (await anon('select public.leaderboard_xp($1, $2, $3, $4) j', [period, lim, off, me])).j;
const battles = async (name, older = null) => (await anon('select public.player_battles($1, 20, $2) j', [name, older])).j;
const pic = (n) => `https://avatars.githubusercontent.com/u/${n}?v=4`;
const found = async (q) => (await anon('select public.find_players($1) j', [q])).j.map((p) => p.callsign);
const canRun = async (role, fn) => (await db.query(`select has_function_privilege($1, 'public.${fn}', 'EXECUTE') v`, [role])).rows[0].v;
const battle = async (name, bid) => (await anon('select public.player_battle($1, $2) j', [name, bid])).j;
const record = async (uid, f = {}) =>
	(
		await as(
			uid,
			`insert into public.battle_records (user_id, mode, side, result, title, rating, kills, lost, duration_s, me, report)
			values ($1, $2, $3, $4, $5, $6, $7, $8, 600, '{"kills": 1}', '{"winner": 0}') returning id`,
			[uid, f.mode ?? 'skirmish', f.side ?? 0, f.result ?? 'victory', f.title ?? 'Battle vs the AI', f.rating ?? 50, f.kills ?? 10, f.lost ?? 5],
		)
	)[0];

test('every battle that earns XP is logged, and only those', NEEDS, async () => {
	const logged = (await db.query('select coalesce(sum(gained), 0)::integer s from public.xp_log where user_id = $1', [B])).rows[0].s;
	assert.equal(logged, (await profile(B)).xp);
	assert.equal((await db.query('select count(*)::integer n from public.xp_log where gained <= 0')).rows[0].n, 0);
});

test("anyone may read a player's card: never their email, never a hidden player", NEEDS, async () => {
	await signUp(D, 'Delta');
	await signUp(E, 'Echo');
	await signUp(F, 'Foxtrot');
	for (const [uid, xp] of [
		[D, 900_000],
		[E, 900_000],
		[F, 500_000],
	])
		await db.query('update public.profiles set xp = $2 where id = $1', [uid, xp]);

	const c = await card('delta ');
	assert.deepEqual(Object.keys(c).toSorted(), ['avatar', 'battles', 'callsign', 'history', 'icon', 'joined', 'last_seen', 'position', 'wins', 'xp']);
	assert.deepEqual([c.callsign, c.icon, c.avatar, c.xp, c.history, c.position], ['Delta', 's01', null, 900_000, true, 1]);
	// level on XP: the same place
	assert.equal((await card('Echo')).position, 1);
	assert.equal((await card('Foxtrot')).position, 3);
	assert.equal(await card('Nobody'), null);
	// no XP yet: on no board
	await signUp(id(105), 'Newcomer');
	assert.equal((await card('Newcomer')).position, null);

	await db.query('update public.profiles set hidden = true where id = $1', [F]);
	assert.equal(await card('Foxtrot'), null);
	await db.query('update public.profiles set hidden = false where id = $1', [F]);
});

test('a player picks their picture and hides their battles; whether they are hidden is not theirs', NEEDS, async () => {
	await as(D, `update public.profiles set avatar = 'github', hide_history = true where id = $1`, [D]);
	assert.deepEqual([(await profile(D)).avatar, (await profile(D)).hide_history], ['github', true]);
	await as(D, `update public.profiles set hide_history = false where id = $1`, [D]);
	await refused('42501', () => as(D, `update public.profiles set hidden = false where id = $1`, [D]));
	await refused('42501', () => as(D, `update public.profiles set github_avatar = 'https://avatars.githubusercontent.com/u/1' where id = $1`, [D]));
	await refused('23514', () => as(D, `update public.profiles set avatar = 'upload' where id = $1`, [D]));
	// no GitHub picture to show: no picture, whatever they picked
	assert.equal((await card('Delta')).avatar, null);
	await as(D, `update public.profiles set avatar = 'insignia' where id = $1`, [D]);
});

test("a GitHub player's picture comes from GitHub, keeps up with it, and is only ever GitHub's", NEEDS, async () => {
	const G = id(104);
	await db.query(`insert into auth.users (id, email, raw_user_meta_data) values ($1, 'g@github.test', $2)`, [G, { user_name: 'pictured', avatar_url: pic(1) }]);
	assert.equal((await profile(G)).github_avatar, pic(1));
	// shown only once they pick it
	assert.equal((await card('pictured')).avatar, null);
	await as(G, `update public.profiles set avatar = 'github' where id = $1`, [G]);
	assert.equal((await card('pictured')).avatar, pic(1));
	// a new picture on GitHub, at their next sign-in
	await db.query(`update auth.users set raw_user_meta_data = $2 where id = $1`, [G, { user_name: 'pictured', avatar_url: pic(2) }]);
	assert.equal((await card('pictured')).avatar, pic(2));
	// a picture from anywhere else isn't taken
	await db.query(`update auth.users set raw_user_meta_data = $2 where id = $1`, [G, { user_name: 'pictured', avatar_url: 'https://evil.test/x.png' }]);
	assert.equal((await profile(G)).github_avatar, null);
	assert.equal((await card('pictured')).avatar, null);
});

test('leaderboards: all time by XP, this week and month by what was earned in them', NEEDS, async () => {
	let b = await board('all', 2);
	assert.deepEqual(
		b.rows.map((r) => [r.position, r.callsign, r.score]),
		[
			[1, 'Delta', 900_000],
			[1, 'Echo', 900_000],
		],
	);
	assert.deepEqual(Object.keys(b.rows[0]).toSorted(), ['avatar', 'battles', 'callsign', 'icon', 'position', 'score', 'wins', 'xp']);
	assert.equal(b.total, (await db.query('select count(*)::integer n from public.profiles where xp > 0 and not hidden')).rows[0].n);
	b = await board('all', 1, 2, 'foxtrot');
	assert.deepEqual([b.rows[0].callsign, b.rows[0].position, b.me.callsign, b.me.position, b.me.n], ['Foxtrot', 3, 'Foxtrot', 3, 3]);
	assert.equal((await board('all', 1, 0, 'Nobody')).me, null);

	// earned this week (and so this month), and long ago
	await db.query(`insert into public.xp_log (user_id, gained, at) values ($1, 50, now()), ($2, 70, now()), ($3, 999, now() - interval '60 days')`, [D, E, F]);
	for (const period of ['week', 'month']) {
		const d = (await board(period, 50, 0, 'Delta')).me;
		const e = (await board(period, 50, 0, 'Echo')).me;
		assert.deepEqual([d.score, e.score], [50, 70], period);
		assert.ok(e.position < d.position, period);
		assert.equal((await board(period, 50, 0, 'Foxtrot')).me, null, `${period}: nothing earned in it`);
	}

	// a hidden player is on no board
	await db.query('update public.profiles set hidden = true where id = $1', [E]);
	b = await board('all', 1, 0, 'Echo');
	assert.deepEqual([b.rows[0].callsign, b.me], ['Delta', null]);
	assert.equal((await board('all', 1, 0, 'Foxtrot')).me.position, 2);
	await db.query('update public.profiles set hidden = false where id = $1', [E]);

	await refused('PT400', () => board('year'));
	// asking for too much gets a page's worth
	assert.ok((await board('all', 10_000)).rows.length <= 100);
});

test('service records: stamped when they arrive, 200 a day, and anyone may read them unless kept back', NEEDS, async () => {
	await refused('42501', () =>
		as(D, `insert into public.battle_records (user_id, mode, side, result, played_at) values ($1, 'skirmish', 0, 'victory', '2020-01-01')`, [D]),
	);
	const first = await record(D, { title: 'First', rating: 40, kills: 12, lost: 4 });
	await record(D, { title: 'Second', result: 'defeat', side: 1, mode: 'mission', rating: 70, kills: 3, lost: 9 });

	const list = await battles('Delta');
	assert.deepEqual(
		list.map((r) => r.title),
		['Second', 'First'],
	);
	assert.equal(list[0].me, undefined, 'headline numbers only');
	assert.deepEqual(
		(await battles('Delta', list[0].played_at)).map((r) => r.title),
		['First'],
	);
	const one = await battle('Delta', first.id);
	assert.deepEqual([one.title, one.me.kills, one.report.winner, one.user_id], ['First', 1, 0, undefined]);
	assert.equal(await battle('Echo', first.id), null, "not Echo's");

	// the career, as the matchmaker totals a player's own
	const career = (await anon('select public.player_career($1) j', ['Delta'])).j;
	const rows = (await db.query('select * from public.battle_records where user_id = $1', [D])).rows;
	const js = careerOf(rows.map((r) => ({ ...r, played_at: r.played_at.toISOString() })));
	assert.deepEqual(Object.keys(career).toSorted(), Object.keys(js).toSorted());
	for (const k of ['battles', 'victories', 'defeats', 'kills', 'lost', 'seconds', 'rating', 'sides', 'modes']) assert.deepEqual(career[k], js[k], k);
	assert.equal(career.best.title, 'Second');

	// kept to themselves: nothing but the card, which says so
	await as(D, `update public.profiles set hide_history = true where id = $1`, [D]);
	assert.equal((await card('Delta')).history, false);
	assert.equal(await battles('Delta'), null);
	assert.equal(await battle('Delta', first.id), null);
	assert.equal((await anon('select public.player_career($1) j', ['Delta'])).j, null);
	await as(D, `update public.profiles set hide_history = false where id = $1`, [D]);

	// a day's worth, then no more
	await db.query(`insert into public.battle_records (user_id, mode, side, result) select $1, 'skirmish', 0, 'victory' from generate_series(1, 200)`, [F]);
	await refused('PT429', () => record(F));
});

test('finding a player as their callsign is typed', NEEDS, async () => {
	assert.deepEqual(await found('ech'), ['Echo']);
	assert.deepEqual((await found('OCTO')).toSorted(), ['OctoCat-2', 'octocat', 'octocat-3']);
	// _ and % are themselves, not wildcards
	assert.deepEqual(await found('%'), []);
	assert.deepEqual(await found('_'), []);
});

test('anyone may run the public functions, and nothing else this migration adds', NEEDS, async () => {
	for (const fn of [
		'player_card(text)',
		'find_players(text)',
		'leaderboard_xp(text, integer, integer, text)',
		'player_career(text)',
		'player_battles(text, integer, timestamp with time zone)',
		'player_battle(text, uuid)',
	])
		for (const role of ['anon', 'authenticated']) assert.equal(await canRun(role, fn), true, `${role} ${fn}`);
	for (const fn of ['handle_user_updated()', 'github_avatar_of(jsonb)', 'battle_records_daily_cap()'])
		for (const role of ['anon', 'authenticated']) assert.equal(await canRun(role, fn), false, `${role} ${fn}`);
	// the log itself is closed
	await refused('42501', () => as(D, 'select * from public.xp_log'));
	await refused('42501', () => as(D, `insert into public.xp_log (user_id, gained) values ($1, 1000)`, [D]));
});
