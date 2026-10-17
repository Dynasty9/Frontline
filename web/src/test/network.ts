// Stands in for the matchmaker, so the whole page can be shown (and tested)
// without it. Anything left out of `answers` fails the way a down server does.
// (The release and the changelog are baked into the site, so need no stand-in.)

import { signInForStory, type User } from "@/lib/account"
import type { Health, Lobby } from "@/lib/matchmaker"

export type Answers = {
  lobbies?: Lobby[]
  health?: Health
  /** the signed-in player, for /me (signedIn puts their session in the page) */
  me?: User
  /** callsigns PATCH /me turns down as taken */
  taken?: string[]
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
