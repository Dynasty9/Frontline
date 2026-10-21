import { MATCHMAKER_URL } from "@/lib/config"

// What anyone may see of the players, from the matchmaker
// (matchmaker/src/players.js): a page per callsign, their battles (unless they
// keep them to themselves) and the leaderboards. Never anyone's email. The
// matchmaker keeps each answer for half a minute, and so does the browser.

/** A player's public card: who they are and how far they've come. */
export type PublicPlayer = {
  callsign: string
  icon: string
  /** their GitHub picture, if they've chosen it; null for their insignia */
  avatar: string | null
  xp: number
  rank: number
  rank_xp: number
  next_xp: number | null
  /** battles fought to the end (and won) that earned XP */
  battles: number
  wins: number
  joined: string | null
  /** false: they keep their battles to themselves */
  history: boolean
  /** their place on the all-time board (null: no XP yet) */
  position: number | null
  /** when they last earned XP */
  last_seen: string | null
}

/** all time, or what was earned this month, or this week (calendar ones, UTC) */
export type Period = "all" | "month" | "week"
export const PERIODS: Period[] = ["all", "month", "week"]

export type BoardRow = {
  position: number
  callsign: string
  icon: string
  avatar: string | null
  rank: number
  xp: number
  /** what the board ranks by: all their XP, or what they earned in the period */
  score: number
  battles: number
  wins: number
}

export type Board = {
  board: "xp"
  period: Period
  page: number
  pages: number
  per_page: number
  total: number
  rows: BoardRow[]
  /** the row of the player asked about (?me=), wherever they are */
  me: BoardRow | null
}

export type Mode = "skirmish" | "coop" | "pvp" | "mission"

/** A battle on a player's record, its headline numbers (the game's own word). */
export type BattleHead = {
  id: string
  played_at: string
  game_version: string
  mode: Mode
  mission: string
  title: string
  side: 0 | 1
  result: "victory" | "defeat"
  duration_s: number
  rating: number
  score: number
  kills: number
  lost: number
  veh_kills: number
  veh_lost: number
  shots: number
  hits: number
}

/** A commander's (or a side's) figures in an after-action report (BattleStats.FIELDS in the game). */
export type Figures = Partial<Record<(typeof FIELDS)[number], number>>

export const FIELDS = [
  "kills",
  "downs",
  "veh_kills",
  "bld_kills",
  "lost",
  "wounded",
  "captured",
  "veh_lost",
  "bld_lost",
  "shots",
  "hits",
  "dmg",
  "val_killed",
  "val_lost",
  "spent",
  "squads",
  "vehicles",
  "built",
  "research",
  "support",
  "captures",
  "towns",
  "prisoners",
  "revived",
  "delivered",
] as const

export type Commander = Figures & { id?: number; name?: string; team?: number; ai?: boolean; left?: boolean }

/** The after-action report as the game keeps it (BattleStats.trim_report), the parts the site reads. */
export type Report = {
  replay?: string
  t?: number
  winner?: number
  players?: Commander[]
  sides?: Figures[]
  me?: number
  me_team?: number
}

export type Battle = BattleHead & { me: Commander & { rating?: number; score?: number }; report: Report }

/** A career, totalled from a player's battles (matchmaker/src/records.js careerOf). */
export type Career = {
  battles: number
  victories: number
  defeats: number
  kills: number
  lost: number
  veh_kills: number
  veh_lost: number
  shots: number
  hits: number
  seconds: number
  score: number
  rating: number
  best: { id: string; rating: number; title: string; played_at: string } | null
  sides: [number, number]
  modes: Partial<Record<Mode, number>>
  first: string | null
  last: string | null
}

export type FoundPlayer = { callsign: string; icon: string; avatar: string | null; rank: number }

/** The page of a player, and of one of their battles. */
export const playerPath = (callsign: string) => `/player/${encodeURIComponent(callsign)}`
export const battlePath = (callsign: string, id: string) => `${playerPath(callsign)}/battle/${encodeURIComponent(id)}`

const name = (callsign: string) => encodeURIComponent(callsign.trim())

/** A public answer, or null for "no such player" (or battle). */
async function get<T>(path: string, signal?: AbortSignal): Promise<T | null> {
  const res = await fetch(MATCHMAKER_URL + path, { signal, headers: { Accept: "application/json" } })
  if (res.status === 404) return null
  if (!res.ok) {
    const data = await res.json().catch(() => null)
    throw new Error(typeof data?.error === "string" ? data.error : `The matchmaker answered ${res.status}`)
  }
  return (await res.json()) as T
}

export async function fetchBoard(period: Period, page: number, me: string | null, signal?: AbortSignal) {
  const q = new URLSearchParams({ period, page: String(page) })
  if (me) q.set("me", me)
  const b = await get<Board>(`/leaderboards/xp?${q}`, signal)
  if (!b) throw new Error("There's no such leaderboard.")
  return b
}

export const fetchPlayer = async (callsign: string, signal?: AbortSignal) =>
  (await get<{ player: PublicPlayer }>(`/players/${name(callsign)}`, signal))?.player ?? null

export const fetchCareer = async (callsign: string, signal?: AbortSignal) =>
  (await get<{ career: Career | null }>(`/players/${name(callsign)}/career`, signal))?.career ?? null

/** Newest first; `before`: the played_at of the last one you have, for more. */
export async function fetchBattles(callsign: string, before: string | null, signal?: AbortSignal) {
  const q = new URLSearchParams({ limit: "20" })
  if (before) q.set("before", before)
  return (
    (await get<{ battles: BattleHead[]; more: boolean; hidden?: boolean }>(
      `/players/${name(callsign)}/battles?${q}`,
      signal
    )) ?? { battles: [], more: false }
  )
}

export const fetchBattle = async (callsign: string, id: string, signal?: AbortSignal) =>
  (await get<{ battle: Battle }>(`/players/${name(callsign)}/battles/${encodeURIComponent(id)}`, signal))?.battle ??
  null

/** Players whose callsigns start with `q` (two letters or more), the highest ranked first. */
export async function findPlayers(q: string, signal?: AbortSignal) {
  const t = q.trim()
  if (t.length < 2) return []
  return (await get<{ players: FoundPlayer[] }>(`/players?q=${encodeURIComponent(t)}`, signal))?.players ?? []
}

export const MODE_NAMES: Record<Mode, string> = {
  skirmish: "Skirmish vs the AI",
  coop: "Co-op vs the AI",
  pvp: "Player vs player",
  mission: "Mission",
}

/** The two sides (Defs.TEAM_NAMES in the game). */
export const SIDE_NAMES = ["Coalition", "Rebels"] as const

/** "62%", or "-" before a first battle */
export const winRate = (wins: number, battles: number) => (battles > 0 ? `${Math.round((100 * wins) / battles)}%` : "-")

export const PERIOD_NAMES: Record<Period, string> = { all: "All time", month: "This month", week: "This week" }

/** "12 min", "1 h 05 min" */
export function formatDuration(seconds: number) {
  const m = Math.round(seconds / 60)
  return m < 60 ? `${m} min` : `${Math.floor(m / 60)} h ${String(m % 60).padStart(2, "0")} min`
}

/** "3 days ago", "just now": how long ago, roughly */
export function timeAgo(iso: string, now = Date.now()) {
  const s = Math.round((Date.parse(iso) - now) / 1000)
  const fmt = new Intl.RelativeTimeFormat("en", { numeric: "auto" })
  const steps: [number, Intl.RelativeTimeFormatUnit][] = [
    [60, "second"],
    [60, "minute"],
    [24, "hour"],
    [7, "day"],
    [4.35, "week"],
    [12, "month"],
    [Infinity, "year"],
  ]
  let v = s
  for (const [size, unit] of steps) {
    if (Math.abs(v) < size) return unit === "second" && Math.abs(v) < 45 ? "just now" : fmt.format(Math.round(v), unit)
    v /= size
  }
  return fmt.format(Math.round(v), "year")
}

/** "16 Oct 2026" */
export const formatDay = (iso: string) =>
  new Date(iso).toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" })
