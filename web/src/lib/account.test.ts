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

  it("goes back to the page the player signed in from, if it's on this site", () => {
    store.set("frontline.github", JSON.stringify({ verifier: VERIFIER, game: null, to: "/account" }))
    expect(takeGitHubReturn("https://site.test/?code=c1")).toEqual({
      back: { game: null, code: "c1", verifier: VERIFIER },
      clean: "/",
      to: "/account",
    })
    // the front page is where GitHub comes back to anyway
    store.set("frontline.github", JSON.stringify({ verifier: VERIFIER, game: null, to: "/" }))
    expect(takeGitHubReturn("https://site.test/?code=c2")?.to).toBeUndefined()
    // never off the site
    store.set("frontline.github", JSON.stringify({ verifier: VERIFIER, game: null, to: "//evil.test/" }))
    expect(takeGitHubReturn("https://site.test/?code=c3")?.to).toBeUndefined()
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
