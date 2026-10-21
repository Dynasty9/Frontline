import { MATCHMAKER_URL } from "@/lib/config"

export type Replay = {
  id: string
  lobby: string
  name: string
  host: string
  version: string
  protocol: number
  status: "live" | "complete" | "interrupted"
  duration: number
  delay: number
  created: number
  verified: false
  chunks: { sequence: number; start: number; end: number }[]
}

export async function fetchReplays(signal: AbortSignal): Promise<{ enabled: boolean; replays: Replay[] }> {
  const response = await fetch(`${MATCHMAKER_URL}/replays`, { signal })
  if (!response.ok) throw new Error("Recordings are unavailable right now.")
  return response.json()
}

export async function fetchReplay(id: string, signal: AbortSignal): Promise<Replay> {
  if (!/^[a-f0-9]{24}$/.test(id)) throw new Error("That recording address is invalid.")
  const response = await fetch(`${MATCHMAKER_URL}/replays/${id}`, { signal })
  if (!response.ok) throw new Error("This recording is unavailable or has expired.")
  return response.json()
}

export const replaySource = (id: string) => `${MATCHMAKER_URL}/replays/${encodeURIComponent(id)}`
export const replayClock = (seconds: number) =>
  `${Math.floor(seconds / 60)}:${String(Math.floor(seconds % 60)).padStart(2, "0")}`
