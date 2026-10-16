import { afterEach, describe, expect, it, vi } from "vitest"
import { FIND_MATCH_LINK, joinLink, MATCHMAKER_URL } from "@/lib/config"
import { fetchHealth, fetchLobbies, joinable } from "@/lib/matchmaker"
import { health, lobbies, lobbyClosed, lobbyDropIn, lobbyFull, lobbyOpen, lobbyStrict } from "@/test/fixtures"

afterEach(() => {
  vi.unstubAllGlobals()
})

describe("joinable", () => {
  it("lets you into a lobby with room, or a battle open to drop-in", () => {
    expect(joinable(lobbyOpen)).toBe(true)
    expect(joinable(lobbyDropIn)).toBe(true)
    // a strict router makes it harder, not impossible
    expect(joinable(lobbyStrict)).toBe(true)
  })

  it("keeps you out of a full lobby or a closed battle", () => {
    expect(joinable(lobbyFull)).toBe(false)
    expect(joinable(lobbyClosed)).toBe(false)
    expect(joinable({ ...lobbyDropIn, players: lobbyDropIn.max_players })).toBe(false)
  })
})

describe("fetchLobbies / fetchHealth", () => {
  it("read the matchmaker's JSON", async () => {
    const fetch = vi.fn<typeof globalThis.fetch>(async (url) =>
      Response.json(String(url).endsWith("/lobbies") ? { lobbies } : health)
    )
    vi.stubGlobal("fetch", fetch)
    await expect(fetchLobbies()).resolves.toEqual(lobbies)
    await expect(fetchHealth()).resolves.toEqual(health)
    expect(fetch.mock.calls.map(([url]) => url)).toEqual([`${MATCHMAKER_URL}/lobbies`, `${MATCHMAKER_URL}/health`])
  })

  it("pass the abort signal on, so a newer poll can cancel an older one", async () => {
    const fetch = vi.fn<typeof globalThis.fetch>(async () => Response.json({ lobbies: [] }))
    vi.stubGlobal("fetch", fetch)
    const ctl = new AbortController()
    await fetchLobbies(ctl.signal)
    expect(fetch.mock.calls[0][1]?.signal).toBe(ctl.signal)
  })

  it("throw on an error status", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn<typeof fetch>(async () => Response.json({ error: "Too many requests" }, { status: 429 }))
    )
    await expect(fetchLobbies()).rejects.toThrow("The matchmaker answered 429")
  })
})

describe("links", () => {
  it("point the game at a battle", () => {
    expect(joinLink("a1f0c2d3e4b5")).toBe("frontline://join/a1f0c2d3e4b5")
    // ids come from the matchmaker, but a link mustn't break on an odd one
    expect(joinLink("a/b?c")).toBe("frontline://join/a%2Fb%3Fc")
    expect(FIND_MATCH_LINK).toBe("frontline://find-match")
  })

  it("never ends the matchmaker's address with a slash", () => {
    expect(MATCHMAKER_URL).not.toMatch(/\/$/)
  })
})
