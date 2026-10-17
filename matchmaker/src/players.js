// What anyone may see of the players: a profile per callsign, their battles
// (unless they keep them to themselves) and the leaderboards. Both account
// backends answer the same questions (auth.js); this is what they share, and
// the shape the website gets.
//
// Never an email address, and never a hidden player (`hidden`, for
// moderation, set by hand in the database). XP is the figure the boards rank
// by: only the database writes it, timed on its own clock. A player's battles
// are their own game's word, so they're shown as theirs and never ranked.

import { progress, rankOf } from './ranks.js';

// all time; or what was earned this month, or this week (calendar ones, in UTC)
export const PERIODS = ['all', 'month', 'week'];
export const PER_PAGE = 50;
// deep enough for any board we'll have for a while, and no deeper
export const MAX_PAGE = 200;

export class PlayerError extends Error {
	constructor(status, message) {
		super(message);
		this.status = status;
	}
}

// A callsign from an address (/players/Raven): one that could be someone's,
// else there's no such player.
export function callsignParam(s) {
	const c = String(s ?? '').trim();
	if (!/^[A-Za-z0-9 _.-]{3,20}$/.test(c)) throw new PlayerError(404, 'No such player.');
	return c;
}

// When this month or week began (UTC), as the database's date_trunc() sees it.
export function periodStart(period, now = Date.now()) {
	const d = new Date(now);
	if (period === 'month') return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1);
	if (period === 'week') return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() - ((d.getUTCDay() + 6) % 7));
	return null;
}

// A player's public card, with what their XP makes them (their rank, and the
// XP it begins and ends at), the way the user object has it.
export function toPlayer(c) {
	return {
		callsign: c.callsign,
		icon: c.icon,
		avatar: c.avatar ?? null,
		...progress(Number(c.xp) || 0),
		battles: c.battles ?? 0,
		wins: c.wins ?? 0,
		joined: c.joined ?? null,
		history: c.history !== false,
		position: c.position ?? null,
		last_seen: c.last_seen ?? null,
	};
}

export const toRow = (r) => ({
	position: Number(r.position),
	callsign: r.callsign,
	icon: r.icon,
	avatar: r.avatar ?? null,
	rank: rankOf(Number(r.xp) || 0),
	xp: Number(r.xp) || 0,
	score: Number(r.score) || 0,
	battles: r.battles ?? 0,
	wins: r.wins ?? 0,
});

// A board as the website gets it, from a backend's {total, rows, me}.
export function toBoard(period, page, b) {
	const total = Number(b.total) || 0;
	return {
		board: 'xp',
		period,
		page,
		pages: Math.max(1, Math.min(MAX_PAGE, Math.ceil(total / PER_PAGE))),
		per_page: PER_PAGE,
		total,
		rows: (b.rows ?? []).map(toRow),
		me: b.me ? toRow(b.me) : null,
	};
}

// The memory backend's board, the way leaderboard_xp() ranks one: by score,
// players level on it sharing a position, the one who joined first listed
// first. `entries` are {callsign, icon, avatar, xp, battles, wins, created_at,
// score}.
export function rankBoard(entries, { limit, offset, me }) {
	const board = entries.filter((e) => e.score > 0).toSorted((a, b) => b.score - a.score || a.created_at - b.created_at || a.callsign.localeCompare(b.callsign));
	let position = 0;
	board.forEach((e, i) => {
		if (i === 0 || e.score !== board[i - 1].score) position = i + 1;
		e.position = position;
	});
	const mine = me ? board.find((e) => e.callsign.toLowerCase() === String(me).trim().toLowerCase()) : null;
	return { total: board.length, rows: board.slice(offset, offset + limit), me: mine ?? null };
}
