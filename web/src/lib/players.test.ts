import { afterEach, describe, expect, it, vi } from "vitest"
import { battlePath, fetchPlayer, formatDuration, playerPath, timeAgo, winRate } from "@/lib/players"

afterEach(() => {
  vi.unstubAllGlobals()
})

describe("a player's addresses", () => {
  it("carry the callsign, spaces and all", () => {
    expect(playerPath("Raven Six")).toBe("/player/Raven%20Six")
    expect(battlePath("Raven Six", "abc")).toBe("/player/Raven%20Six/battle/abc")
  })
})

describe("fetchPlayer", () => {
  it("is null for no such player, and says why anything else went wrong", async () => {
    vi.stubGlobal("fetch", async () => Response.json({ error: "No such player." }, { status: 404 }))
    await expect(fetchPlayer("Nobody")).resolves.toBeNull()
    vi.stubGlobal("fetch", async () => Response.json({ error: "Too many requests." }, { status: 429 }))
    await expect(fetchPlayer("Raven")).rejects.toThrow("Too many requests.")
  })
})

describe("winRate", () => {
  it("is the share of battles won, or a dash before the first", () => {
    expect(winRate(14, 23)).toBe("61%")
    expect(winRate(0, 0)).toBe("-")
  })
})

describe("formatDuration", () => {
  it("is minutes, and hours past the hour", () => {
    expect(formatDuration(1460)).toBe("24 min")
    expect(formatDuration(3900)).toBe("1 h 05 min")
  })
})

describe("timeAgo", () => {
  const now = Date.parse("2026-10-16T12:00:00Z")
  it("says roughly how long ago", () => {
    expect(timeAgo("2026-10-16T11:59:50Z", now)).toBe("just now")
    expect(timeAgo("2026-10-16T09:00:00Z", now)).toBe("3 hours ago")
    expect(timeAgo("2026-10-13T12:00:00Z", now)).toBe("3 days ago")
    expect(timeAgo("2026-08-16T12:00:00Z", now)).toBe("2 months ago")
  })
})
