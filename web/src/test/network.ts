// Stands in for the matchmaker, so the whole page can be shown (and tested)
// without it. Anything left out of `answers` fails the way a down server does.
// (The release and the changelog are baked into the site, so need no stand-in.)

import type { Health, Lobby } from "@/lib/matchmaker"

export type Answers = {
  lobbies?: Lobby[]
  health?: Health
}

/** A Storybook `beforeEach`: swaps `fetch` for the answers, and returns the cleanup that puts it back. */
export function mockMatchmaker(answers: Answers) {
  return () => {
    const realFetch = globalThis.fetch
    globalThis.fetch = async (input) => {
      const url = new URL(input instanceof Request ? input.url : String(input))
      const body =
        url.pathname === "/lobbies"
          ? answers.lobbies && { lobbies: answers.lobbies }
          : url.pathname === "/health"
            ? answers.health
            : undefined
      return body === undefined ? Response.json({ error: "down" }, { status: 503 }) : Response.json(body)
    }
    return () => {
      globalThis.fetch = realFetch
    }
  }
}
