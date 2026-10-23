// Stands in for the matchmaker, so the whole page can be shown (and tested)
// without it. Anything left out of `answers` fails the way a down server does.
// (The release and the changelog are baked into the site, so need no stand-in.)

import { closeSignIn } from "@/hooks/use-sign-in-dialog"
import { signInForStory, type User } from "@/lib/account"
import type { Health, Lobby } from "@/lib/matchmaker"
import type { Battle, BattleHead, Board, Career, Period, PublicPlayer } from "@/lib/players"

export type Answers = {
  replays?: import("@/lib/replays").Replay[]
  viewer?: boolean
  lobbies?: Lobby[]
  health?: Health
  /** the signed-in player, for /me (signedIn puts their session in the page) */
  me?: User
  /** callsigns PATCH /me turns down as taken */
  taken?: string[]
  /** who a sign-in with GitHub comes back as (POST /auth/exchange); /me answers for them after */
  exchange?: User
  /** the leaderboards, by period */
  boards?: Partial<Record<Period, Board>>
  /** everyone's public pages: anyone not here is no such player */
  players?: PublicPlayer[]
  /** by callsign: their battles, career and full reports */
  battles?: Record<string, BattleHead[]>
  careers?: Record<string, Career>
  reports?: Record<string, Battle[]>
}

/** What the matchmaker's public routes (players.js) answer, from the stand-in's answers; undefined for any other route. */
function publicAnswer(answers: Answers, url: URL): Response | undefined {
  const m = url.pathname.match(/^\/(leaderboards|players)(?:\/([^/]+))?(?:\/(career|battles))?(?:\/([^/]+))?$/)
  if (!m) return undefined
  const [, what, key, part, id] = m
  if (what === "leaderboards") {
    const b = answers.boards?.[(url.searchParams.get("period") ?? "all") as Period]
    return b ? Response.json(b) : undefined
  }
  if (!answers.players) return undefined
  if (!key) {
    const q = (url.searchParams.get("q") ?? "").toLowerCase()
    const players = answers.players
      .filter((p) => p.callsign.toLowerCase().startsWith(q))
      .map((p) => ({ callsign: p.callsign, icon: p.icon, avatar: p.avatar, rank: p.rank }))
    return Response.json({ players })
  }
  const p = answers.players.find((x) => x.callsign.toLowerCase() === decodeURIComponent(key).toLowerCase())
  const none = Response.json({ error: "No such player." }, { status: 404 })
  if (!p) return none
  if (!part) return Response.json({ player: p })
  if (part === "career") return Response.json({ career: p.history ? (answers.careers?.[p.callsign] ?? null) : null })
  if (!p.history) return id ? none : Response.json({ battles: [], more: false, hidden: true })
  if (!id) return Response.json({ battles: answers.battles?.[p.callsign] ?? [], more: false })
  const b = answers.reports?.[p.callsign]?.find((r) => r.id === id)
  return b ? Response.json({ battle: b }) : Response.json({ error: "No such battle." }, { status: 404 })
}

/** A Storybook `beforeEach`: swaps `fetch` for the answers, and returns the cleanup that puts it back. */
export function mockMatchmaker(answers: Answers) {
  return () => {
    const realFetch = globalThis.fetch
    let me = answers.me
    globalThis.fetch = async (input, init) => {
      const url = new URL(input instanceof Request ? input.url : String(input), window.location.origin)
      const method = init?.method ?? "GET"
      const route = `${method} ${url.pathname}`
      if (route === "GET /replays") return Response.json({ enabled: true, replays: answers.replays ?? [] })
      if (url.pathname.startsWith("/replays/")) {
        const replay = answers.replays?.find((r) => r.id === url.pathname.split("/")[2])
        return Response.json(replay ?? { error: "Not found" }, { status: replay ? 200 : 404 })
      }
      if (url.pathname === "/game/viewer.json")
        return Response.json(answers.viewer ? { format: 1, protocol: 9 } : {}, { status: answers.viewer ? 200 : 404 })
      const pub = method === "GET" ? publicAnswer(answers, url) : undefined
      if (pub) return pub
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
export function awayAtGitHub(returnTo?: string) {
  return () => {
    sessionStorage.setItem("frontline.github", JSON.stringify({ verifier: "v".repeat(43), game: null, returnTo }))
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
