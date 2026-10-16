// Ranks, XP and insignia: the rules every account follows, in one place. The
// memory backend applies them itself; with Supabase the same rules run in SQL
// (supabase/schema.sql), and this only turns the XP the database returns into
// the rank a player sees. Keep the two in step.
//
// A signed-in player earns XP from the battles they play and climbs from
// Recruit (rank 0) to rank 50. Each rank asks a little more than the last: the
// first comes in a battle, each of the last few takes several. Every rank
// unlocks an insignia (a patch) the player can wear as their icon.

export const MAX_RANK = 50;

// Every account starts wearing this one.
export const STARTER_ICON = 's01';

// XP needed to reach rank r: 150 for the first, and each one after that 20 more
// than the one before (rank 50 at 32,000).
export const xpFor = (r) => 150 * r + 10 * r * (r - 1);

export function rankOf(xp) {
	let r = 0;
	while (r < MAX_RANK && xpFor(r + 1) <= xp) r++;
	return r;
}

// Where a total of XP puts a player: their rank, where it began and where the
// next one begins (null once there isn't one).
export function progress(xp) {
	const rank = rankOf(xp);
	return { xp, rank, rank_xp: xpFor(rank), next_xp: rank < MAX_RANK ? xpFor(rank + 1) : null };
}

// The insignia: ten starters every account has, a patch for each rank, and
// award and unit patches that are shown but can't be earned yet.
// An id is a letter for the group and a two-digit number.
const GROUPS = {
	s: { group: 'starter', count: 10 },
	r: { group: 'rank', count: MAX_RANK },
	m: { group: 'award', count: 50 },
	u: { group: 'unit', count: 50 },
};

// {id, group, unlock} for a known insignia, else null. unlock is the rank that
// unlocks it (0 for the starters), or null when nothing unlocks it yet.
export function insignia(id) {
	const m = /^([a-z])(\d\d)$/.exec(String(id ?? ''));
	const g = m && GROUPS[m[1]];
	const n = m ? Number(m[2]) : 0;
	if (!g || n < 1 || n > g.count) return null;
	const unlock = m[1] === 's' ? 0 : m[1] === 'r' ? n : null;
	return { id: m[0], group: g.group, unlock };
}

export const unlocked = (ins, rank) => ins.unlock !== null && rank >= ins.unlock;

export const lockedMessage = (ins) => (ins.unlock === null ? 'That insignia is locked.' : `That insignia is locked. Reach rank ${ins.unlock} to unlock it.`);

// How a battle can end: won, lost, or left before the end (worth half, so
// sticking it out pays, but a player who has to go still gets something).
export const RESULTS = { win: 1.5, loss: 1, left: 0.5 };

export const isResult = (r) => typeof r === 'string' && Object.hasOwn(RESULTS, r);

// A battle shorter than this earns nothing (quitting at once isn't a battle),
// and time past the longest earns nothing more (nor does a game left running).
export const MIN_BATTLE_S = 2 * 60;
export const MAX_BATTLE_S = 45 * 60;

// The XP for a battle: a point per tenth of a minute, times the result. The
// time counted is the shorter of how long our clock says the battle was open
// and how long the game says it ran (game time, so a paused game doesn't count).
export function battleXp(result, openSeconds, reportedSeconds) {
	const seconds = Math.min(openSeconds, reportedSeconds, MAX_BATTLE_S);
	if (!(seconds >= MIN_BATTLE_S)) return 0;
	return Math.floor(Math.floor(seconds / 6) * RESULTS[result]);
}
