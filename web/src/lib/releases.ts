// The latest release of the game, baked in at build time. Every release
// (.github/workflows/release.yml) rewrites src/release.json in its pull
// request, and Railway redeploys the site when that merges, so the page always
// offers the current version without asking GitHub (or waiting on it) when it
// loads.
import release from "@/release.json"

export type Platform = "windows" | "macos" | "linux"

export type Asset = { name: string; url: string; size: number; sha256: string }

export type Build = {
  version: string
  tag: string
  name: string
  url: string // the release page
  published: string
  // every release has Windows and Linux; macOS from the first release with a Mac build
  assets: Record<"windows" | "linux", Asset> & Partial<Record<"macos", Asset>>
}

export const latest: Build = release

/** The platforms a release has a download for, in the order the page lists them. */
export function platformsOf(build: Build): Platform[] {
  return (["windows", "macos", "linux"] as const).filter((p) => build.assets[p] !== undefined)
}

/** Best guess at the visitor's platform, for the main download button: Windows when the release has none for theirs. */
export function guessPlatform(build: Build = latest): Platform {
  const ua = navigator.userAgent
  // an iPad asks for desktop pages as a Mac, but it has a touch screen
  const mac = /Macintosh/i.test(ua) && !(navigator.maxTouchPoints > 1)
  const p: Platform = mac ? "macos" : /linux|x11/i.test(ua) && !/android/i.test(ua) ? "linux" : "windows"
  return build.assets[p] ? p : "windows"
}

/** A release's download for a platform (Windows' if it has none for it, which guessPlatform never picks). */
export function assetFor(platform: Platform, build: Build = latest): Asset {
  return build.assets[platform] ?? build.assets.windows
}

export const PLATFORM_NAMES: Record<Platform, string> = { windows: "Windows", macos: "macOS", linux: "Linux" }

/** The platforms a release is for, as a sentence says them: "Windows, macOS and Linux". */
export function platformList(build: Build = latest): string {
  const names = platformsOf(build).map((p) => PLATFORM_NAMES[p])
  return names.length > 1 ? `${names.slice(0, -1).join(", ")} and ${names.at(-1)}` : names.join("")
}

export function formatSize(bytes: number) {
  return bytes >= 1e9 ? `${(bytes / 1e9).toFixed(1)} GB` : `${Math.round(bytes / 1e6)} MB`
}
