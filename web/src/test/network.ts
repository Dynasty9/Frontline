// Stands in for the matchmaker, so the whole page can be shown (and tested)
// without it. Anything left out of `answers` fails the way a down server does.
// (The release and the changelog are baked into the site, so need no stand-in.)

import { closeSignIn } from "@/hooks/use-sign-in-dialog"
import { signInForStory, type User } from "@/lib/account"
import type { Health, Lobby } from "@/lib/matchmaker"

export type Answers = {
  lobbies?: Lobby[]
  health?: Health
  /** the signed-in player, for /me (signedIn puts their session in the page) */
  me?: User
  /** callsigns PATCH /me turns down as taken */
  taken?: string[]
  /** who a sign-in with GitHub comes back as (POST /auth/exchange); /me answers for them after */
  exchange?: User
}

/** A Storybook `beforeEach`: swaps `fetch` for the answers, and returns the cleanup that puts it back. */
export function mockMatchmaker(answers: Answers) {
  return () => {
    const realFetch = globalThis.fetch
    let me = answers.me
    globalThis.fetch = async (input, init) => {
      const url = new URL(input instanceof Request ? input.url : String(input))
      const method = init?.method ?? "GET"
      const route = `${method} ${url.pathname}`
      if (route === "POST /auth/exchange" && answers.exchange) {
        me = answers.exchange
        const session = { access_token: "story-access", refresh_token: "story-refresh", expires_in: 3600, user: me }
        return Response.json({ session })
      }
      if (route === "PATCH /me" && me) {
        const change = JSON.parse(String(init?.body ?? "{}")) as Partial<User>
        if (change.callsign && answers.taken?.some((t) => t.toLowerCase() === change.callsign?.toLowerCase()))
          return Response.json({ error: "That callsign is taken." }, { status: 409 })
        me = { ...me, ...change }
        return Response.json({ user: me })
      }
      const body =
        route === "GET /lobbies"
          ? answers.lobbies && { lobbies: answers.lobbies }
          : route === "GET /health"
            ? answers.health
            : route === "GET /me"
              ? me && { user: me }
              : route === "POST /auth/logout"
                ? { ok: true }
                : undefined
      return body === undefined ? Response.json({ error: "down" }, { status: 503 }) : Response.json(body)
    }
    return () => {
      globalThis.fetch = realFetch
    }
  }
}

/**
 * A Storybook `beforeEach`: the page signed in as `user`, and signed out
 * again after. Pair it with mockMatchmaker({ me: user }), which answers the
 * page's /me.
 */
export function signedIn(user: User) {
  return () => {
    signInForStory(user)
    return () => signInForStory(null)
  }
}

/**
 * A Storybook `beforeEach`: this tab went to GitHub to sign the site in (the
 * verifier it keeps while it's away), so the page can come back with ?code=.
 * The session the code is swapped for isn't saved, and afterwards the page is
 * signed out and its sign-in dialog shut, ready for the next story.
 */
export function awayAtGitHub() {
  return () => {
    sessionStorage.setItem("frontline.github", JSON.stringify({ verifier: "v".repeat(43), game: null }))
    const setItem = Storage.prototype.setItem
    Storage.prototype.setItem = function (key: string, value: string) {
      if (key !== "frontline.account") setItem.call(this, key, value)
    }
    return () => {
      Storage.prototype.setItem = setItem
      sessionStorage.removeItem("frontline.github")
      signInForStory(null)
      closeSignIn()
    }
  }
}
