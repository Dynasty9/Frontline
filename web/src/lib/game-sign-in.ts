// Signing in the game. A player's game doesn't ask for a password: it opens
// this site with ?sign-in=<state> (and &create=1 and a &callsign= to suggest,
// for a new account), the player signs in here, and the site hands the game a
// session of its own in a frontline:// link carrying the same state
// (signInLink). The game takes no sign-in it didn't ask for, so no other page
// can sign it in to someone else's account. (scripts/autoload/online.gd)

export type SignInRequest = {
  /** the game's one-time state, to send back with the session */
  state: string
  /** the player pressed Create account in the game */
  create: boolean
  /** the name they're playing under, for a new account's callsign */
  callsign: string
}

const PARAMS = ["sign-in", "create", "callsign"]

/** The game's request in the page's query string, or null if there isn't one. */
export function readSignInRequest(search: string): SignInRequest | null {
  const q = new URLSearchParams(search)
  const state = q.get("sign-in") ?? ""
  if (!/^[0-9a-f]{16,64}$/.test(state)) return null
  return { state, create: q.get("create") === "1", callsign: (q.get("callsign") ?? "").trim().slice(0, 20) }
}

/** The page's address with the request taken out (once it's done, so a reload doesn't ask again). */
export function withoutSignInRequest(url: string): string {
  const u = new URL(url)
  for (const p of PARAMS) u.searchParams.delete(p)
  return u.pathname + u.search + u.hash
}
