import { useSyncExternalStore } from "react"
import { MATCHMAKER_URL } from "@/lib/config"
import { findInsignia, isUnlocked, RANKS } from "@/lib/insignia"

// A player's account, the same one they sign in with in the game. The
// matchmaker fronts it (matchmaker/src/auth.js): the site never talks to the
// account service directly. The session lives in localStorage so a reload
// keeps you signed in, and the access token is refreshed a minute before it
// runs out, or once when the matchmaker turns it down.

export type User = {
  id: string
  email: string
  callsign: string
  icon: string | null
  xp: number
  rank: number
  /** XP the current rank starts at, and the next one does (null at the top) */
  rank_xp: number
  next_xp: number | null
  battles: number
  wins: number
}

export type AccountState = {
  user: User | null
  /** a sign-in, sign-up or sign-out on its way */
  busy: boolean
  error: string | null
  /** something to tell the player that isn't an error ("check your email") */
  notice: string | null
}

type Session = { access_token: string; refresh_token: string; expires_at: number; user: User | null }
type WireSession = { access_token: string; refresh_token: string; expires_in: number; user?: Partial<User> }

class ApiError extends Error {
  status: number
  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

async function call<T>(method: string, path: string, body?: unknown, token?: string): Promise<T> {
  const headers: Record<string, string> = { Accept: "application/json" }
  if (body !== undefined) headers["Content-Type"] = "application/json"
  if (token) headers.Authorization = `Bearer ${token}`
  let res: Response
  try {
    res = await fetch(MATCHMAKER_URL + path, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    })
  } catch {
    throw new ApiError(0, "Can't reach the matchmaker. Try again in a moment.")
  }
  const data = await res.json().catch(() => null)
  if (!res.ok)
    throw new ApiError(
      res.status,
      typeof data?.error === "string" ? data.error : `The matchmaker answered ${res.status}`
    )
  return data as T
}

const KEY = "frontline.account"
// refresh this long before the token runs out, so a request never carries a dead one
const EARLY_MS = 60_000

function load(): Session | null {
  try {
    const s = JSON.parse(localStorage.getItem(KEY) ?? "null")
    return s && typeof s.access_token === "string" && typeof s.refresh_token === "string" ? s : null
  } catch {
    return null
  }
}

function save(s: Session | null) {
  try {
    if (s) localStorage.setItem(KEY, JSON.stringify(s))
    else localStorage.removeItem(KEY)
  } catch {
    // no storage (private window): the session lasts as long as the tab
  }
}

// A brand-new account, for whatever the matchmaker leaves out (the session it
// hands back at sign-in may carry only the basics; /me has the rest).
const BLANK: User = {
  id: "",
  email: "",
  callsign: "",
  icon: null,
  xp: 0,
  rank: 0,
  rank_xp: 0,
  next_xp: RANKS[1]?.xp ?? null,
  battles: 0,
  wins: 0,
}

const toUser = (u: Partial<User> | undefined, prev: User | null): User => ({ ...BLANK, ...prev, ...u })

const toSession = (w: WireSession, prev: User | null): Session => ({
  access_token: w.access_token,
  refresh_token: w.refresh_token,
  expires_at: Date.now() + (Number(w.expires_in) || 3600) * 1000,
  user: w.user ? toUser(w.user, prev) : prev,
})

const message = (e: unknown) => (e instanceof Error ? e.message : "Something went wrong.")

// --- the store: one per page, shared by every component through useAccount()

let session: Session | null = load()
let state: AccountState = { user: session?.user ?? null, busy: false, error: null, notice: null }
const listeners = new Set<() => void>()

function set(patch: Partial<AccountState>) {
  state = { ...state, ...patch }
  for (const l of listeners) l()
}

function adopt(s: Session | null, persist = true) {
  session = s
  if (persist) save(s)
  schedule()
  set({ user: s?.user ?? null })
}

function setUser(u: User) {
  if (!session) return
  session = { ...session, user: u }
  save(session)
  set({ user: u })
}

let timer: number | undefined
function schedule(waitMs?: number) {
  window.clearTimeout(timer)
  if (!session || !started) return
  const wait = waitMs ?? Math.max(5_000, session.expires_at - Date.now() - EARLY_MS)
  // offline: keep the session and try again in a while
  timer = window.setTimeout(() => refresh().catch(() => schedule(30_000)), wait)
}

let refreshing: Promise<Session | null> | null = null

/** A new access token. Null means the account is signed out (and the store says so). */
function refresh(): Promise<Session | null> {
  refreshing ??= (async () => {
    const mine = session
    if (!mine) return null
    // A refresh token works once, and another tab may have just spent it:
    // take the session it saved rather than spend a dead one.
    const theirs = () => {
      const s = load()
      return s && s.refresh_token !== mine.refresh_token ? s : null
    }
    const saved = theirs()
    if (saved) {
      adopt(saved, false)
      return saved
    }
    try {
      const r = await call<{ session: WireSession }>("POST", "/auth/refresh", { refresh_token: mine.refresh_token })
      // only the tokens: the player as this page has them may be newer (an
      // insignia picked a moment ago), and /me keeps the rest up to date
      const fresh = toSession(r.session, null)
      const s = { ...fresh, user: session?.user ?? fresh.user }
      if (session !== mine) return session // signed out (or in again) meanwhile
      adopt(s)
      return s
    } catch (e) {
      if (!(e instanceof ApiError) || e.status !== 401) throw e
      const late = theirs()
      if (late) {
        adopt(late, false)
        return late
      }
      if (session === mine) {
        adopt(null)
        set({ notice: "You've been signed out. Sign in again to pick your insignia." })
      }
      return null
    }
  })().finally(() => {
    refreshing = null
  })
  return refreshing
}

const expired = () => new ApiError(401, "Your sign-in has expired. Sign in again.")

/** A call as the signed-in player: a fresh token, and one more try after a 401. */
async function authed<T>(method: string, path: string, body?: unknown): Promise<T> {
  let s = session
  if (!s) throw expired()
  if (s.expires_at - Date.now() < EARLY_MS) s = await refresh()
  if (!s) throw expired()
  try {
    return await call<T>(method, path, body, s.access_token)
  } catch (e) {
    if (!(e instanceof ApiError) || e.status !== 401) throw e
    // turned down before it should have run out (revoked, or the server restarted)
    const again = await refresh()
    if (!again) throw expired()
    return await call<T>(method, path, body, again.access_token)
  }
}

// Trying on insignia: the pick shows at once, and goes to the matchmaker once
// the player stops clicking for a moment (it limits how often they can
// change), one request at a time. confirmedIcon is what it last agreed to,
// which a pick it turns down falls back to.
const ICON_SETTLE_MS = 350
let confirmedIcon: string | null = null
let iconTimer = 0
let iconSaving = false
const iconPending = () => iconTimer !== 0 || iconSaving

let syncedAt = 0
async function syncMe() {
  syncedAt = Date.now()
  const r = await authed<{ user: Partial<User> }>("GET", "/me")
  if (!session?.user) return
  const icon = iconPending() ? session.user.icon : (r.user.icon ?? null)
  setUser(toUser({ ...r.user, icon }, session.user))
}

let started = false
function start() {
  if (started) return
  started = true
  // signed in or out in another tab: follow it
  window.addEventListener("storage", (e) => {
    if (e.key !== null && e.key !== KEY) return
    adopt(load(), false)
  })
  // back from a battle in the game: the XP has moved
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden && session && Date.now() - syncedAt > 30_000) syncMe().catch(() => {})
  })
  if (session) {
    schedule()
    // offline or the matchmaker's down: keep showing what we last knew
    syncMe().catch(() => {})
  }
}

// --- what the page can do

async function begin(w: WireSession) {
  const s = toSession(w, null)
  // the rank and stats before anything is shown, so a veteran doesn't flash up as a recruit
  try {
    const r = await call<{ user: Partial<User> }>("GET", "/me", undefined, s.access_token)
    s.user = toUser(r.user, s.user)
  } catch {
    s.user ??= toUser(w.user, null)
  }
  syncedAt = Date.now()
  adopt(s)
}

async function signIn(email: string, password: string): Promise<boolean> {
  set({ busy: true, error: null, notice: null })
  try {
    const r = await call<{ session: WireSession }>("POST", "/auth/login", { email: email.trim(), password })
    await begin(r.session)
    return true
  } catch (e) {
    set({ error: message(e) })
    return false
  } finally {
    set({ busy: false })
  }
}

/** "in" when the account is ready, "confirm" when the email needs confirming first. */
async function signUp(email: string, password: string, callsign: string): Promise<"in" | "confirm" | null> {
  set({ busy: true, error: null, notice: null })
  try {
    const r = await call<{ session?: WireSession | null; confirm?: boolean }>("POST", "/auth/signup", {
      email: email.trim(),
      password,
      callsign: callsign.trim(),
    })
    if (r.session) {
      await begin(r.session)
      return "in"
    }
    set({ notice: "Check your email for the confirmation link, then sign in here." })
    return "confirm"
  } catch (e) {
    set({ error: message(e) })
    return null
  } finally {
    set({ busy: false })
  }
}

function signOut() {
  const s = session
  window.clearTimeout(iconTimer)
  iconTimer = 0
  adopt(null)
  set({ error: null, notice: null })
  // the matchmaker revokes the token; signed out here whatever it says
  if (s) call("POST", "/auth/logout", undefined, s.access_token).catch(() => {})
}

/** Wear an insignia: shown at once, put back if the matchmaker says no. */
function setIcon(id: string) {
  const u = state.user
  if (!u || !session) return
  const ins = findInsignia(id)
  if (!ins || !isUnlocked(ins, u.rank)) {
    set({ error: "That insignia is locked." })
    return
  }
  if (!iconPending()) {
    if (u.icon === id) return
    confirmedIcon = u.icon
  }
  set({ error: null })
  setUser({ ...u, icon: id })
  window.clearTimeout(iconTimer)
  iconTimer = window.setTimeout(saveIcon, ICON_SETTLE_MS)
}

async function saveIcon() {
  iconTimer = 0
  // one on its way already: it sends the newest pick when it's back
  if (iconSaving) return
  const want = session?.user?.icon
  if (!want || want === confirmedIcon) return
  iconSaving = true
  let failed = false
  try {
    const r = await authed<{ user: Partial<User> }>("PATCH", "/me", { icon: want })
    confirmedIcon = r.user.icon ?? want
    if (session?.user) setUser(toUser({ ...r.user, icon: session.user.icon }, session.user))
  } catch (e) {
    failed = true
    set({ error: message(e) })
    // locked after all: the rank shown here is out of date
    if (e instanceof ApiError && e.status === 403) syncMe().catch(() => {})
  } finally {
    iconSaving = false
    if (iconTimer === 0 && session?.user) {
      if (session.user.icon !== want) void saveIcon()
      else if (failed) setUser({ ...session.user, icon: confirmedIcon })
    }
  }
}

const clearError = () => set({ error: null, notice: null })

const subscribe = (l: () => void) => {
  start()
  listeners.add(l)
  return () => {
    listeners.delete(l)
  }
}
const snapshot = () => state

const actions = { signIn, signUp, signOut, setIcon, clearError }

/** The signed-in player (or null) and what can be done about it. */
export function useAccount() {
  return { ...useSyncExternalStore(subscribe, snapshot), ...actions }
}
