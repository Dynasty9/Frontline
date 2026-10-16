import { existsSync } from "node:fs"
import { describe, expect, it } from "vitest"
import {
  DEFAULT_ICON,
  findInsignia,
  GROUPS,
  INSIGNIA,
  insigniaUrl,
  isUnlocked,
  MAX_RANK,
  nextUnlock,
  RANKS,
  rankName,
  unlockText,
  wornInsignia,
} from "@/lib/insignia"

// insignia.json and public/insignia/ are written by the game (--insignia-dump=web);
// the matchmaker's tests hold it to the same rules (matchmaker/src/ranks.js)

const count = (group: string) => INSIGNIA.filter((i) => i.group === group).length

// the rule by id: starters for all, rNN at rank NN, the rest locked for now
const ruleFor = (id: string) => (id.startsWith("s") ? 0 : id.startsWith("r") ? Number(id.slice(1)) : -1)

describe("the catalog the game wrote", () => {
  it("has ranks 0 to 50, each 20 XP dearer than the last", () => {
    expect(RANKS.map((r) => r.rank)).toEqual(Array.from({ length: 51 }, (_, i) => i))
    for (const r of RANKS) expect(r.xp).toBe(150 * r.rank + 10 * r.rank * (r.rank - 1))
    expect(MAX_RANK).toBe(50)
    expect(rankName(0)).toBe("Recruit")
    expect(rankName(50)).toBe("General of the Army")
  })

  it("has ten starters, a patch per rank, and a hundred still locked", () => {
    expect(GROUPS.map((g) => g.key)).toEqual(["starter", "rank", "award", "unit"])
    expect([count("starter"), count("rank"), count("award"), count("unit")]).toEqual([10, 50, 50, 50])
    expect(INSIGNIA.map((i) => [i.id, i.unlock])).toEqual(INSIGNIA.map((i) => [i.id, ruleFor(i.id)]))
    expect(new Set(INSIGNIA.map((i) => i.id)).size).toBe(INSIGNIA.length)
    expect(new Set(INSIGNIA.map((i) => i.name)).size).toBe(INSIGNIA.length)
  })

  it("has a picture for every insignia", () => {
    expect(INSIGNIA.filter((i) => !existsSync(`public${insigniaUrl(i.id)}`)).map((i) => i.id)).toEqual([])
  })
})

describe("unlocking", () => {
  const starter = findInsignia("s05")!
  const r12 = findInsignia("r12")!
  const award = findInsignia("m01")!

  it("gives every account the starters, and a rank patch once the rank is reached", () => {
    expect(isUnlocked(starter, 0)).toBe(true)
    expect(isUnlocked(r12, 11)).toBe(false)
    expect(isUnlocked(r12, 12)).toBe(true)
    expect(isUnlocked(award, 50)).toBe(false)
  })

  it("says what unlocks each", () => {
    expect(unlockText(starter)).toBe("Every account starts with it")
    expect(unlockText(r12)).toBe("Unlocks at rank 12, Sergeant II")
    expect(unlockText(award)).toBe("Can't be earned yet")
  })

  it("knows the next patch to come, and that there's none past the top", () => {
    expect(nextUnlock(0)?.id).toBe("r01")
    expect(nextUnlock(25)?.id).toBe("r26")
    expect(nextUnlock(50)).toBeUndefined()
  })

  it("dresses an account that hasn't picked one (or wears something unknown) in the first starter", () => {
    expect(DEFAULT_ICON).toBe("s01")
    expect(wornInsignia(null)?.id).toBe("s01")
    expect(wornInsignia("x99")?.id).toBe("s01")
    expect(wornInsignia("r21")?.name).toBe("Dawn Eagles")
  })
})
