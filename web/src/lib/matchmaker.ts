import { MATCHMAKER_URL } from "@/lib/config"

// What the matchmaker says about a hosted battle (matchmaker/src/lobbies.js view()).
export type Lobby = {
  id: string
  name: string
  host: string
  verified: boolean
  players: number
  max_players: number
  in_game: boolean
  drop_in: boolean
  nat: "open" | "cone" | "strict" | "unknown"
  version: string
  age: number
}

export type Health = {
  ok: boolean
  accounts: string
  lobbies: number
  players: number
}

async function get<T>(path: string, signal?: AbortSignal): Promise<T> {
  const res = await fetch(MATCHMAKER_URL + path, { signal, headers: { Accept: "application/json" } })
  if (!res.ok) throw new Error(`The matchmaker answered ${res.status}`)
  return (await res.json()) as T
}

export const fetchLobbies = (signal?: AbortSignal) =>
  get<{ lobbies: Lobby[] }>("/lobbies", signal).then((r) => r.lobbies)

export const fetchHealth = (signal?: AbortSignal) => get<Health>("/health", signal)

/** Whether a player could join this battle right now. */
export const joinable = (l: Lobby) => l.players < l.max_players && (!l.in_game || l.drop_in)
