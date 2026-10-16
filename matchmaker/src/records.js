// Service records: each signed-in player's battles, as their own game reports
// them at the end (its after-action report). The figures come from the
// player's game, so they are the player's own word: fine for a personal
// record, not for a leaderboard.
//
// A record is a few headline numbers (for the list and the career totals) and
// the report itself, trimmed by the game, so the battle's after-action report
// can be opened again later.

import { cleanText } from './lobbies.js';

export const MODES = ['skirmish', 'coop', 'pvp', 'mission'];
export const RESULTS = ['victory', 'defeat'];
// what a commander's record counts (BattleStats.FIELDS in the game)
export const FIELDS = ['kills', 'downs', 'veh_kills', 'bld_kills', 'lost', 'wounded', 'captured', 'veh_lost', 'bld_lost',
	'shots', 'hits', 'dmg', 'val_killed', 'val_lost', 'spent', 'squads', 'vehicles', 'built', 'research', 'support',
	'captures', 'prisoners', 'revived', 'delivered'];
// the report the game sends back can be opened again, so it's kept whole -
// but not without limit
export const MAX_REPORT = 96 * 1024;
export const MAX_BODY = MAX_REPORT + 8 * 1024;
// the columns a list of battles needs (the report stays behind)
export const HEAD = ['id', 'played_at', 'game_version', 'mode', 'mission', 'title', 'side', 'result', 'duration_s',
	'rating', 'score', 'kills', 'lost', 'veh_kills', 'veh_lost', 'shots', 'hits'];

export class RecordError extends Error {
	constructor(message) {
		super(message);
		this.status = 400;
	}
}

const num = (v, lo, hi) => {
	const n = Number(v);
	return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : lo;
};
const int = (v, lo, hi) => Math.round(num(v, lo, hi));

// A battle as the game sent it, checked and cut down to what we keep.
export function cleanRecord(b) {
	if (!b || typeof b !== 'object') throw new RecordError('No battle to record.');
	const mode = String(b.mode ?? '');
	if (!MODES.includes(mode)) throw new RecordError('Unknown kind of battle.');
	const result = String(b.result ?? '');
	if (!RESULTS.includes(result)) throw new RecordError('A battle is won or lost.');
	const side = Number(b.side);
	if (side !== 0 && side !== 1) throw new RecordError('Which side were you on?');
	const meIn = b.me && typeof b.me === 'object' && !Array.isArray(b.me) ? b.me : null;
	if (!meIn) throw new RecordError('Your part in the battle is missing.');
	const me = { name: cleanText(meIn.name, 20), ai: false };
	for (const f of FIELDS) me[f] = int(meIn[f], 0, 1e8);
	me.rating = num(meIn.rating, 0, 100);
	me.score = int(meIn.score, 0, 1e8);
	const report = b.report && typeof b.report === 'object' && !Array.isArray(b.report) ? b.report : {};
	if (JSON.stringify(report).length > MAX_REPORT) throw new RecordError('That report is too large.');
	return {
		game_version: cleanText(b.game_version, 20),
		mode,
		mission: cleanText(b.mission, 32),
		title: cleanText(b.title, 60),
		side,
		result,
		duration_s: int(b.duration, 0, 7 * 86400),
		rating: Math.round(me.rating * 10) / 10,
		score: me.score,
		kills: me.kills,
		lost: me.lost + me.captured,
		veh_kills: me.veh_kills,
		veh_lost: me.veh_lost,
		shots: me.shots,
		hits: me.hits,
		me,
		report,
	};
}

// A whole career from its battles' headline numbers.
export function careerOf(rows) {
	const c = {
		battles: rows.length, victories: 0, defeats: 0, kills: 0, lost: 0, veh_kills: 0, veh_lost: 0, shots: 0, hits: 0,
		seconds: 0, score: 0, rating: 0, best: null, sides: [0, 0], modes: {}, first: null, last: null,
	};
	let ratings = 0;
	for (const r of rows) {
		if (r.result === 'victory') c.victories++;
		else c.defeats++;
		for (const k of ['kills', 'lost', 'veh_kills', 'veh_lost', 'shots', 'hits', 'score']) c[k] += Number(r[k]) || 0;
		c.seconds += Number(r.duration_s) || 0;
		ratings += Number(r.rating) || 0;
		if (r.side === 0 || r.side === 1) c.sides[r.side]++;
		c.modes[r.mode] = (c.modes[r.mode] || 0) + 1;
		if (!c.best || Number(r.rating) > c.best.rating) c.best = { id: r.id, rating: Number(r.rating), title: r.title, played_at: r.played_at };
		const t = String(r.played_at);
		if (!c.first || t < c.first) c.first = t;
		if (!c.last || t > c.last) c.last = t;
	}
	c.rating = rows.length ? Math.round((ratings / rows.length) * 10) / 10 : 0;
	return c;
}

export const isUuid = (s) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(s));
