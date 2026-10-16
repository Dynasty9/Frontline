// Where the site gets its data. Both can be overridden at build time
// (VITE_MATCHMAKER_URL, VITE_GITHUB_REPO), e.g. to point at a local matchmaker.

export const MATCHMAKER_URL = (
  import.meta.env.VITE_MATCHMAKER_URL ?? "https://matchmaker-production-a53e.up.railway.app"
).replace(/\/+$/, "")

export const GITHUB_REPO: string = import.meta.env.VITE_GITHUB_REPO ?? "Dynasty9/Frontline"
export const GITHUB_URL = `https://github.com/${GITHUB_REPO}`

// The game registers this scheme on first launch (scripts/autoload/online.gd).
export const joinLink = (lobbyId: string) => `frontline://join/${encodeURIComponent(lobbyId)}`
export const FIND_MATCH_LINK = "frontline://find-match"
