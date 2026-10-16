// The lobby registry. Games are still hosted by players (the host runs the
// whole simulation) and played peer to peer; the matchmaker keeps the list of
// who is hosting, finds a game for anyone pressing "Find Match", and introduces
// host and joiner so they can connect through their home routers.
//
// That introduction is UDP hole punching. Each side has asked a public STUN
// server which address and port its router shows the internet for its game
// socket, and tells us. When a player asks to join, we give them the host's
// endpoint and pass theirs to the host (who is waiting on a long poll); both
// then send packets at each other, each router sees an outgoing packet and lets
// the other side's packets in, and ENet connects directly. No game traffic ever
// passes through here.
//
// Hosts check in while they're listed, and a lobby that stops checking in is
// dropped, so a crashed host vanishes quickly.

import { randomBytes } from 'node:crypto';
import { isIP } from 'node:net';

export const HEARTBEAT_S = 15;
export const POLL_S = 20;

const clampInt = (v, lo, hi, dflt) => {
	const n = Number.parseInt(v, 10);
	return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : dflt;
};
// a port in range, or 0
const portIn = (v, lo = 1) => {
	const n = Number(v);
	return Number.isInteger(n) && n >= lo && n <= 65535 ? n : 0;
};

// Printable text only, trimmed: names end up on other players' screens.
export const cleanText = (v, max) =>
	String(v ?? '')
		// oxlint-disable-next-line no-control-regex -- removing control characters is the point
		.replace(/[\u0000-\u001f\u007f]/g, '')
		.trim()
		.slice(0, max);

const isPrivateV4 = (ip) => isIP(ip) === 4 && /^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(ip);
const isLocal = (ip) => ip === '127.0.0.1' || ip === '::1' || isPrivateV4(ip);

// The endpoint a peer's STUN query reported. Its address has to be the one the
// request came from (so nobody can aim a host's packets at a stranger), except
// that a peer reaching us over IPv6 or from a LAN may report its public IPv4.
export function stunEndpoint(body, seenIp) {
	const port = portIn(body?.port);
	const ip = String(body?.ip ?? '');
	if (!port || isIP(ip) !== 4) return null;
	if (ip !== seenIp && isIP(seenIp) !== 6 && !isLocal(seenIp)) return null;
	return { ip, port };
}

const NAT_KINDS = new Set(['open', 'cone', 'strict', 'unknown']);

// Quick match order: games still in the lobby, then hosts whose router can be
// reached, then the fullest, then the oldest.
// prettier-ignore
const better = (a, b) =>
	a.inGame !== b.inGame ? !a.inGame :
	(a.nat === 'strict') !== (b.nat === 'strict') ? b.nat === 'strict' :
	a.players !== b.players ? a.players > b.players :
	a.created < b.created;

export class Lobbies {
	constructor({ ttlMs = HEARTBEAT_S * 3 * 1000, maxPerIp = 4, reserveMs = 20_000, now = Date.now } = {}) {
		this.ttlMs = ttlMs;
		this.maxPerIp = maxPerIp;
		this.reserveMs = reserveMs;
		this.now = now;
		this.byId = new Map();
	}

	// Drop lobbies whose host has gone quiet, and expired seat reservations.
	sweep() {
		const t = this.now();
		for (const l of this.byId.values()) {
			if (t - l.seen > this.ttlMs && !l.waiter) this.drop(l);
			else l.reserved = l.reserved.filter((until) => until > t);
		}
	}

	drop(l) {
		this.byId.delete(l.id);
		this.wake(l);
	}

	create(ip, body, account = null) {
		this.sweep();
		// one listing per account (hosting again replaces it), a few per address
		// (several people can share a router)
		for (const l of [...this.byId.values()]) {
			if (account && l.userId === account.id) this.drop(l);
		}
		let fromIp = 0;
		for (const l of this.byId.values()) if (l.ip === ip) fromIp++;
		if (fromIp >= this.maxPerIp) return { error: 'Too many games hosted from this address.' };
		const port = portIn(body.port, 1024);
		if (!port) return { error: 'A valid port (1024-65535) is required.' };
		const host = account ? account.callsign : cleanText(body.host, 20) || 'Commander';
		const lobby = {
			id: randomBytes(6).toString('hex'),
			token: randomBytes(18).toString('base64url'),
			ip,
			// a private LAN address, for players behind the same router (most
			// home routers can't loop a connection back in through their own
			// public address)
			lan: isPrivateV4(String(body.lan ?? '')) ? String(body.lan) : '',
			port,
			punch: stunEndpoint(body.punch, ip),
			nat: NAT_KINDS.has(body.nat) ? body.nat : 'unknown',
			host,
			verified: !!account,
			userId: account ? account.id : null,
			name: cleanText(body.name, 40) || `${host}'s battle`,
			version: cleanText(body.version, 16),
			created: this.now(),
			seen: this.now(),
			reserved: [],
			joins: [],
			waiter: null,
		};
		this.update(lobby, body);
		this.byId.set(lobby.id, lobby);
		return { lobby };
	}

	// The state a host reports with each check-in.
	update(lobby, body) {
		lobby.maxPlayers = clampInt(body.max_players, 1, 64, lobby.maxPlayers ?? 8);
		lobby.players = clampInt(body.players, 0, 64, lobby.players ?? 1);
		lobby.inGame = body.in_game !== undefined ? !!body.in_game : !!lobby.inGame;
		lobby.dropIn = body.drop_in !== undefined ? !!body.drop_in : (lobby.dropIn ?? true);
		if (body.name !== undefined) lobby.name = cleanText(body.name, 40) || lobby.name;
	}

	owned(id, token) {
		this.sweep();
		const l = this.byId.get(id);
		return l && l.token === token ? l : null;
	}

	heartbeat(id, token, body) {
		const l = this.owned(id, token);
		if (!l) return null;
		l.seen = this.now();
		this.update(l, body);
		return l;
	}

	remove(id, token) {
		const l = this.owned(id, token);
		if (l) this.drop(l);
		return !!l;
	}

	// A player wants in. Queue their endpoint for the host to punch towards,
	// and tell them where to connect.
	join(id, seenIp, body) {
		this.sweep();
		const l = this.byId.get(id);
		if (!l) return null;
		const ep = stunEndpoint(body, seenIp);
		if (ep && l.joins.length < 16) {
			l.joins.push(ep);
			this.wake(l);
		}
		return { connect: this.connectTo(l, seenIp), lobby: this.view(l) };
	}

	// Where a player should point ENet: the host's LAN address from behind the
	// same router, else the endpoint the host's router showed STUN, else the
	// address it reached us from and its game port (which works if the host
	// forwarded the port).
	connectTo(l, seenIp) {
		if (seenIp === l.ip && l.lan) return { address: l.lan, port: l.port, via: 'lan' };
		if (l.punch) return { address: l.punch.ip, port: l.punch.port, via: 'punch' };
		return { address: l.ip, port: l.port, via: 'direct' };
	}

	// The host's long poll: resolves with the players waiting to be punched
	// towards, at once if there are any, else when one arrives or after `ms`.
	// Resolves null if the lobby is gone.
	poll(id, token, ms) {
		const l = this.owned(id, token);
		if (!l) return Promise.resolve(null);
		l.seen = this.now();
		if (l.joins.length) return Promise.resolve(l.joins.splice(0));
		this.wake(l); // a newer poll replaces an older one
		return new Promise((resolve) => {
			const timer = setTimeout(() => this.wake(l), ms);
			l.waiter = (joins) => {
				clearTimeout(timer);
				l.waiter = null;
				resolve(this.byId.has(l.id) ? joins : null);
			};
		});
	}

	wake(l) {
		if (l.waiter) l.waiter(l.joins.splice(0));
	}

	// Whether a player could join now: room left (counting players we've just
	// sent its way) and either still in the lobby or open to drop-in.
	joinable(l) {
		return l.players + l.reserved.length < l.maxPlayers && (!l.inGame || l.dropIn);
	}

	list(version) {
		this.sweep();
		const out = [];
		for (const l of this.byId.values()) {
			if (version && l.version !== version) continue;
			out.push(this.view(l));
		}
		out.sort((a, b) => b.players - a.players || a.age - b.age);
		return out;
	}

	// Quick match: the best open game, or null (then the player hosts one and
	// waits to be found). Filling the fullest lobby first means people end up
	// playing together rather than each waiting alone in an empty one.
	match(version, exclude = []) {
		this.sweep();
		const skip = new Set(exclude.map(String));
		let best = null;
		for (const l of this.byId.values()) {
			if (skip.has(l.id) || (version && l.version !== version) || !this.joinable(l)) continue;
			if (!best || better(l, best)) best = l;
		}
		if (!best) return null;
		best.reserved.push(this.now() + this.reserveMs);
		return this.view(best);
	}

	// What other players see. Addresses are only handed out by join().
	view(l) {
		return {
			id: l.id,
			name: l.name,
			host: l.host,
			verified: l.verified,
			players: l.players,
			max_players: l.maxPlayers,
			in_game: l.inGame,
			drop_in: l.dropIn,
			nat: l.nat,
			version: l.version,
			age: Math.round((this.now() - l.created) / 1000),
		};
	}

	stats() {
		this.sweep();
		let players = 0;
		for (const l of this.byId.values()) players += l.players;
		return { lobbies: this.byId.size, players };
	}
}
