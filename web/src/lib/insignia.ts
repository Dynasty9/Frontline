import catalog from "@/lib/insignia.json"

// The insignia a player can wear as their icon, and the ranks that unlock
// them. Both insignia.json and the art in public/insignia/ are written by the
// game (--insignia-dump=web), so the site and the game agree on every patch.

export type Rank = { rank: number; name: string; xp: number }
export type Group = { key: string; title: string; blurb: string }
export type Insignia = {
  id: string
  name: string
  group: string
  /** the rank that unlocks it: 0 every account has it, -1 nobody can earn it yet */
  unlock: number
  blurb: string
}

export const RANKS: Rank[] = catalog.ranks.toSorted((a, b) => a.rank - b.rank)
export const GROUPS: Group[] = catalog.groups
export const INSIGNIA: Insignia[] = catalog.insignia

export const MAX_RANK = RANKS[RANKS.length - 1]?.rank ?? 0

const BY_ID = new Map(INSIGNIA.map((i) => [i.id, i]))
const BY_RANK = new Map(RANKS.map((r) => [r.rank, r]))

export const findInsignia = (id: string | null | undefined) => (id ? BY_ID.get(id) : undefined)

export const rankName = (rank: number) => BY_RANK.get(rank)?.name ?? `Rank ${rank}`

/** What an account wears until it picks something: the first starter patch. */
export const DEFAULT_ICON = INSIGNIA.find((i) => i.unlock === 0)?.id ?? "s01"

/** What a player wears: their pick, or the first starter patch until they make one. */
export const wornInsignia = (icon: string | null | undefined) => findInsignia(icon) ?? findInsignia(DEFAULT_ICON)

export const insigniaUrl = (id: string) => `/insignia/${encodeURIComponent(id)}.svg`

export const isUnlocked = (i: Insignia, rank: number) => i.unlock >= 0 && i.unlock <= rank

export function unlockText(i: Insignia) {
  if (i.unlock < 0) return "Can't be earned yet"
  if (i.unlock === 0) return "Every account starts with it"
  return `Unlocks at rank ${i.unlock}, ${rankName(i.unlock)}`
}

/** The insignia unlocked by the rank after this one, if any. */
export const nextUnlock = (rank: number) =>
  INSIGNIA.filter((i) => i.unlock > rank).toSorted((a, b) => a.unlock - b.unlock)[0]
