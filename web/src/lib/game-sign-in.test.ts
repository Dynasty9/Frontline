import { describe, expect, it } from "vitest"
import { signInLink } from "@/lib/config"
import { readSignInRequest, withoutSignInRequest } from "@/lib/game-sign-in"

const STATE = "014d51f106f3e7f8399fdc9d92c2b20c"

describe("readSignInRequest", () => {
  it("reads what the game asks for", () => {
    expect(readSignInRequest(`?sign-in=${STATE}`)).toEqual({ state: STATE, create: false, callsign: "" })
    expect(readSignInRequest(`?sign-in=${STATE}&create=1&callsign=Some%20Name`)).toEqual({
      state: STATE,
      create: true,
      callsign: "Some Name",
    })
  })

  it("ignores a page without one, or a state the game never makes", () => {
    expect(readSignInRequest("")).toBeNull()
    expect(readSignInRequest("?join=a1f0c2d3e4b5")).toBeNull()
    expect(readSignInRequest("?sign-in=")).toBeNull()
    expect(readSignInRequest("?sign-in=not-hex-at-all-0000")).toBeNull()
    expect(readSignInRequest("?sign-in=abc")).toBeNull()
  })

  it("keeps a suggested callsign to a callsign's length", () => {
    expect(readSignInRequest(`?sign-in=${STATE}&create=1&callsign=${"x".repeat(40)}`)?.callsign).toHaveLength(20)
  })
})

describe("withoutSignInRequest", () => {
  it("takes the request out and leaves the rest", () => {
    expect(withoutSignInRequest(`https://site.test/?sign-in=${STATE}&create=1&callsign=Me`)).toBe("/")
    expect(withoutSignInRequest(`https://site.test/?join=abc&sign-in=${STATE}#insignia`)).toBe("/?join=abc#insignia")
  })
})

describe("signInLink", () => {
  it("hands the game its state and its own refresh token", () => {
    expect(signInLink(STATE, "U126GPj3WC9_lcHsqCKrnd")).toBe(`frontline://sign-in/${STATE}/U126GPj3WC9_lcHsqCKrnd`)
    // whatever the account service's tokens look like, the link stays one path
    expect(signInLink(STATE, "a/b+c=")).toBe(`frontline://sign-in/${STATE}/a%2Fb%2Bc%3D`)
  })
})
