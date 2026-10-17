// The latest release of the game, baked in at build time. Every release
// (.github/workflows/release.yml) rewrites src/release.json in its pull
// request, and Railway redeploys the site when that merges, so the page always
// offers the current version without asking GitHub (or waiting on it) when it
// loads.
import release from "@/release.json"

export type Platform = "windows" | "linux"

export type Build = {
  version: string
  tag: string
  name: string
  url: string // the release page
  published: string
  assets: Record<Platform, { name: string; url: string; size: number; sha256: string }>
}

export const latest: Build = release

/** Best guess at the visitor's platform, for the main download button. */
export function guessPlatform(): Platform {
  return /linux|x11/i.test(navigator.userAgent) && !/android/i.test(navigator.userAgent) ? "linux" : "windows"
}

/** A computer the game has a build for, a Mac (no build yet), or a phone or tablet (no keyboard and mouse). */
export type Device = Platform | "mac" | "mobile"

/** What the visitor is on, for what the play page offers them. */
export function guessDevice(): Device {
  const ua = navigator.userAgent
  if (/android|iphone|ipad|ipod|mobile/i.test(ua)) return "mobile"
  // an iPad asks for the desktop site as a Mac, but a Mac has no touch screen
  if (/macintosh|mac os x/i.test(ua)) return (navigator.maxTouchPoints ?? 0) > 1 ? "mobile" : "mac"
  return guessPlatform()
}

export const PLATFORM_NAMES: Record<Platform, string> = { windows: "Windows", linux: "Linux" }

export function formatSize(bytes: number) {
  return bytes >= 1e9 ? `${(bytes / 1e9).toFixed(1)} GB` : `${Math.round(bytes / 1e6)} MB`
}
