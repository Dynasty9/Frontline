// Where the site gets its data. Both can be overridden at build time
// (VITE_MATCHMAKER_URL, VITE_GITHUB_REPO), e.g. to point at a local matchmaker.

const LIVE_MATCHMAKER = "https://matchmaker-production-a53e.up.railway.app"
export const MATCHMAKER_URL = (import.meta.env.VITE_MATCHMAKER_URL ?? LIVE_MATCHMAKER).replace(/\/+$/, "")

// Players sign in with GitHub. Email and password are for testing: on the dev
// server, or a site built against a matchmaker of its own (or with
// VITE_EMAIL_SIGN_IN=1), never on the live site.
export const EMAIL_SIGN_IN: boolean =
  import.meta.env.DEV || MATCHMAKER_URL !== LIVE_MATCHMAKER || import.meta.env.VITE_EMAIL_SIGN_IN === "1"

export const GITHUB_REPO: string = import.meta.env.VITE_GITHUB_REPO ?? "Dynasty9/Frontline"
export const GITHUB_URL = `https://github.com/${GITHUB_REPO}`

// The game registers this scheme on first launch (scripts/autoload/links.gd).
export const joinLink = (lobbyId: string) => `frontline://join/${encodeURIComponent(lobbyId)}`
export const FIND_MATCH_LINK = "frontline://find-match"
/** Just the game, to its menu. A link the game doesn't know still starts it, so older versions open too. */
export const OPEN_LINK = "frontline://open"
/** A sign-in for the game that asked for it (`state`): a session of its own (src/lib/game-sign-in.ts). */
export const signInLink = (state: string, refreshToken: string) =>
  `frontline://sign-in/${encodeURIComponent(state)}/${encodeURIComponent(refreshToken)}`
