import { GITHUB_REPO } from "@/lib/config"

// The game's builds live on GitHub Releases (.github/workflows/release.yml):
// every merge that changes the game publishes the next version (v0.1.4, ...),
// each with Frontline-windows.zip and Frontline-linux.zip. (A "nightly"
// pre-release came before numbered releases; it's still read if it's all
// there is.)

export type Platform = "windows" | "linux"

export type Build = {
  tag: string
  name: string
  url: string // the release page
  published: string
  prerelease: boolean
  assets: Partial<Record<Platform, { url: string; size: number }>>
}

type GhAsset = { name: string; browser_download_url: string; size: number }
type GhRelease = {
  tag_name: string
  name: string | null
  html_url: string
  published_at: string
  prerelease: boolean
  draft: boolean
  assets: GhAsset[]
}

function toBuild(r: GhRelease): Build {
  const assets: Build["assets"] = {}
  for (const a of r.assets) {
    const n = a.name.toLowerCase()
    const p: Platform | null = n.includes("windows") ? "windows" : n.includes("linux") ? "linux" : null
    if (p && n.endsWith(".zip")) assets[p] = { url: a.browser_download_url, size: a.size }
  }
  return { tag: r.tag_name, name: r.name || r.tag_name, url: r.html_url, published: r.published_at, prerelease: r.prerelease, assets }
}

const CACHE_KEY = "frontline.releases"
const CACHE_MS = 5 * 60_000

/** The newest stable release and the nightly build, either of which may not exist yet. */
export async function fetchBuilds(): Promise<{ stable: Build | null; nightly: Build | null }> {
  // GitHub allows 60 unauthenticated API calls an hour per address: remember
  // the answer for a few minutes so reloading the page doesn't use them up
  try {
    const hit = JSON.parse(sessionStorage.getItem(CACHE_KEY) ?? "null")
    if (hit && Date.now() - hit.at < CACHE_MS) return hit.data
  } catch {
    // no storage (private window): just ask GitHub
  }
  const res = await fetch(`https://api.github.com/repos/${GITHUB_REPO}/releases?per_page=20`, {
    headers: { Accept: "application/vnd.github+json" },
  })
  if (!res.ok) throw new Error(`GitHub answered ${res.status}`)
  const all = ((await res.json()) as GhRelease[]).filter((r) => !r.draft).map(toBuild)
  const data = {
    stable: all.find((b) => !b.prerelease && Object.keys(b.assets).length > 0) ?? null,
    nightly: all.find((b) => b.prerelease && b.tag === "nightly") ?? null,
  }
  try {
    sessionStorage.setItem(CACHE_KEY, JSON.stringify({ at: Date.now(), data }))
  } catch {
    // storage full or blocked: fine
  }
  return data
}

/** Best guess at the visitor's platform, for the main download button. */
export function guessPlatform(): Platform {
  return /linux|x11/i.test(navigator.userAgent) && !/android/i.test(navigator.userAgent) ? "linux" : "windows"
}

export const PLATFORM_NAMES: Record<Platform, string> = { windows: "Windows", linux: "Linux" }

export function formatSize(bytes: number) {
  return bytes >= 1e9 ? `${(bytes / 1e9).toFixed(1)} GB` : `${Math.round(bytes / 1e6)} MB`
}
