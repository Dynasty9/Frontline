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
	assert.equal((await end(B, 'win', 600)).gained, 0, 'under two minutes on our clock');

	await begin(B);
	await openFor(B, '30 minutes');
	assert.equal((await end(B, 'loss', 300)).gained, 50, 'the game says 5 minutes: 5 minutes it is');

	await begin(B);
	await openFor(B, '20 minutes');
	j = await end(B, 'left', 1200);
	assert.deepEqual([j.gained, j.battles], [100, 3], 'left: half, and not on the record');

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
