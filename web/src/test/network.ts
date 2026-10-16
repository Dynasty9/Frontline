// Stands in for the matchmaker and GitHub, so the whole page can be shown (and
// tested) without either. Anything left out of `answers` fails the way a down
// server does.

import type { Health, Lobby } from "@/lib/matchmaker"
import type { GhRelease } from "@/lib/releases"

export type Answers = {
  lobbies?: Lobby[]
  health?: Health
  releases?: GhRelease[]
}

const RELEASES_CACHE = "frontline.releases"

/** A Storybook `beforeEach`: swaps `fetch` for the answers, and returns the cleanup that puts it back. */
export function mockNetwork(answers: Answers) {
  return () => {
    const realFetch = globalThis.fetch
    // the site remembers GitHub's answer for a few minutes; every story asks afresh
    sessionStorage.removeItem(RELEASES_CACHE)
    globalThis.fetch = async (input) => {
      const url = new URL(input instanceof Request ? input.url : String(input))
      const body =
        url.hostname === "api.github.com"
          ? answers.releases
          : url.pathname === "/lobbies"
            ? answers.lobbies && { lobbies: answers.lobbies }
            : url.pathname === "/health"
              ? answers.health
              : undefined
      return body === undefined ? Response.json({ error: "down" }, { status: 503 }) : Response.json(body)
    }
    return () => {
      globalThis.fetch = realFetch
      sessionStorage.removeItem(RELEASES_CACHE)
    }
  }
}
