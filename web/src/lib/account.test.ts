import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { pkceChallenge, takeGitHubReturn } from "@/lib/account"

const STATE = "014d51f106f3e7f8399fdc9d92c2b20c"
const VERIFIER = "v".repeat(43)

describe("pkceChallenge", () => {
  it("is the verifier's SHA-256 in base64url (RFC 7636's own example)", async () => {
    expect(await pkceChallenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")).toBe(
      "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
    )
  })
})

describe("takeGitHubReturn", () => {
  let store: Map<string, string>
  beforeEach(() => {
    store = new Map()
    vi.stubGlobal("sessionStorage", {
      getItem: (k: string) => store.get(k) ?? null,
      setItem: (k: string, v: string) => store.set(k, v),
      removeItem: (k: string) => store.delete(k),
    })
  })
  afterEach(() => {
    vi.unstubAllGlobals()
  })
  const away = (game: unknown = null) => store.set("frontline.github", JSON.stringify({ verifier: VERIFIER, game }))

  it("is nothing on an ordinary page, or a ?code= this tab didn't go to GitHub for", () => {
    away()
    expect(takeGitHubReturn("https://site.test/?join=abc")).toBeNull()
    store.clear()
    expect(takeGitHubReturn("https://site.test/?code=someone-elses")).toBeNull()
  })

  it("is the code, the verifier and the game's request, once, with the address cleaned", () => {
    const game = { state: STATE, create: false, callsign: "" }
    away(game)
    const href = "https://site.test/?join=abc&code=the-code#insignia"
    const r = takeGitHubReturn(href)
    expect(r).toEqual({ back: { game, code: "the-code", verifier: VERIFIER }, clean: "/?join=abc#insignia" })
    // taken: nothing kept for a reload to try again, and the same answer for the same page
    expect(store.size).toBe(0)
    expect(takeGitHubReturn(href)).toEqual(r)
  })

  it("says why when GitHub, or the player, said no", () => {
    away()
    expect(takeGitHubReturn("https://site.test/?error=access_denied&error_description=The+user+denied+access")).toEqual(
      { back: { game: null, error: "The user denied access" }, clean: "/" }
    )
    away()
    expect(takeGitHubReturn("https://site.test/#error=server_error&error_description=Unable+to+exchange")).toEqual({
      back: { game: null, error: "Unable to exchange" },
      clean: "/",
    })
  })
})

describe("existing website login to game", () => {
  let store: Map<string, string>
  const site = {
    access_token: "site-access",
    refresh_token: "site-refresh",
    expires_at: Date.now() + 3600_000,
    user: { id: "u1", callsign: "Commander" },
  }
  beforeEach(() => {
    vi.resetModules()
    store = new Map([["frontline.account", JSON.stringify(site)]])
    vi.stubGlobal("localStorage", {
      getItem: (key: string) => store.get(key) ?? null,
      setItem: (key: string, value: string) => store.set(key, value),
      removeItem: (key: string) => store.delete(key),
    })
    vi.stubGlobal("window", { clearTimeout: vi.fn<() => void>() })
  })
  afterEach(() => vi.unstubAllGlobals())

  it("authorizes the handoff with the website access token and leaves its refresh token alone", async () => {
    const fetch = vi.fn<typeof globalThis.fetch>().mockResolvedValue(Response.json({ token: "game-refresh" }))
    vi.stubGlobal("fetch", fetch)
    const { signInGameFromWebsite } = await import("@/lib/account")
    expect(await signInGameFromWebsite()).toEqual({ token: "game-refresh" })
    expect(fetch).toHaveBeenCalledExactlyOnceWith(
      expect.stringContaining("/auth/game"),
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({ Authorization: "Bearer site-access" }),
      })
    )
    expect(JSON.parse(store.get("frontline.account")!)).toEqual(site)
  })

  it("refreshes an expired website login before authorizing the game", async () => {
    store.set("frontline.account", JSON.stringify({ ...site, expires_at: 0 }))
    const fetch = vi
      .fn<typeof globalThis.fetch>()
      .mockResolvedValueOnce(
        Response.json({ session: { access_token: "renewed", refresh_token: "renewed-refresh", expires_in: 3600 } })
      )
      .mockResolvedValueOnce(Response.json({ token: "game-refresh" }))
    vi.stubGlobal("fetch", fetch)
    const { signInGameFromWebsite } = await import("@/lib/account")
    expect(await signInGameFromWebsite()).toEqual({ token: "game-refresh" })
    expect(fetch).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining("/auth/game"),
      expect.objectContaining({ headers: expect.objectContaining({ Authorization: "Bearer renewed" }) })
    )
    expect(JSON.parse(store.get("frontline.account")!).refresh_token).toBe("renewed-refresh")
  })

  it("falls back to signing in when the stored session is no longer valid", async () => {
    store.set("frontline.account", JSON.stringify({ ...site, expires_at: 0 }))
    const fetch = vi
      .fn<typeof globalThis.fetch>()
      .mockResolvedValue(Response.json({ error: "expired" }, { status: 401 }))
    vi.stubGlobal("fetch", fetch)
    const { signInGameFromWebsite } = await import("@/lib/account")
    expect(await signInGameFromWebsite()).toBeNull()
    expect(store.has("frontline.account")).toBe(false)
    expect(fetch).toHaveBeenCalledTimes(1)
  })

  it("does not call the handoff endpoint when signed out", async () => {
    store.clear()
    const fetch = vi.fn<typeof globalThis.fetch>()
    vi.stubGlobal("fetch", fetch)
    const { signInGameFromWebsite } = await import("@/lib/account")
    expect(await signInGameFromWebsite()).toBeNull()
    expect(fetch).not.toHaveBeenCalled()
  })

  it("keeps the website login during an outage", async () => {
    vi.stubGlobal("fetch", vi.fn<typeof globalThis.fetch>().mockRejectedValue(new Error("offline")))
    const { signInGameFromWebsite } = await import("@/lib/account")
    expect(await signInGameFromWebsite()).toBeNull()
    expect(JSON.parse(store.get("frontline.account")!)).toEqual(site)
  })
})
