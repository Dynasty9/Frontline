import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { fetchBuilds, formatSize, guessPlatform } from "@/lib/releases"
import { ghReleases, nightlyBuild, stableBuild } from "@/test/fixtures"

const answer = (body: unknown, status = 200) => vi.fn<typeof fetch>(async () => Response.json(body, { status }))

// sessionStorage as a browser has it
function stubStorage() {
  const m = new Map<string, string>()
  vi.stubGlobal("sessionStorage", {
    getItem: (k: string) => m.get(k) ?? null,
    setItem: (k: string, v: string) => void m.set(k, v),
    removeItem: (k: string) => void m.delete(k),
  })
}

afterEach(() => {
  vi.unstubAllGlobals()
  vi.useRealTimers()
})

describe("fetchBuilds", () => {
  beforeEach(stubStorage)

  it("finds the newest release with its zips uploaded, and the nightly", async () => {
    vi.stubGlobal("fetch", answer(ghReleases))
    await expect(fetchBuilds()).resolves.toEqual({ stable: stableBuild, nightly: nightlyBuild })
  })

  it("answers null for builds that don't exist yet", async () => {
    vi.stubGlobal("fetch", answer([]))
    await expect(fetchBuilds()).resolves.toEqual({ stable: null, nightly: null })
  })

  it("only counts zips, and reads the platform from the file name", async () => {
    const [, , , release] = ghReleases
    const assets = [
      { name: "frontline-WINDOWS.zip", browser_download_url: "https://x/w.zip", size: 1 },
      { name: "Frontline-linux.tar.gz", browser_download_url: "https://x/l.tgz", size: 2 },
    ]
    vi.stubGlobal("fetch", answer([{ ...release, assets }]))
    const { stable } = await fetchBuilds()
    expect(stable?.assets).toEqual({ windows: { url: "https://x/w.zip", size: 1 } })
  })

  it("falls back to the tag when a release has no name", async () => {
    const [, , , release] = ghReleases
    vi.stubGlobal("fetch", answer([{ ...release, name: null }]))
    expect((await fetchBuilds()).stable?.name).toBe(release.tag_name)
  })

  it("asks GitHub once per few minutes", async () => {
    vi.useFakeTimers({ toFake: ["Date"] })
    const fetch = answer(ghReleases)
    vi.stubGlobal("fetch", fetch)
    await fetchBuilds()
    await fetchBuilds()
    expect(fetch).toHaveBeenCalledOnce()
    vi.advanceTimersByTime(6 * 60_000)
    await fetchBuilds()
    expect(fetch).toHaveBeenCalledTimes(2)
  })

  it("still works with no storage (a private window)", async () => {
    vi.stubGlobal("sessionStorage", undefined)
    vi.stubGlobal("fetch", answer(ghReleases))
    await expect(fetchBuilds()).resolves.toEqual({ stable: stableBuild, nightly: nightlyBuild })
  })

  it("throws when GitHub refuses", async () => {
    vi.stubGlobal("fetch", answer({ message: "API rate limit exceeded" }, 403))
    await expect(fetchBuilds()).rejects.toThrow("GitHub answered 403")
  })
})

const platformFor = (userAgent: string) => {
  vi.stubGlobal("navigator", { userAgent })
  return guessPlatform()
}

describe("guessPlatform", () => {
  it("spots Linux", () => {
    expect(platformFor("Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0")).toBe("linux")
  })

  it("takes Android for a phone, not a Linux desktop", () => {
    expect(platformFor("Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 Chrome/140.0 Mobile")).toBe(
      "windows"
    )
  })

  it("defaults to Windows", () => {
    expect(platformFor("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140.0")).toBe("windows")
    expect(platformFor("Mozilla/5.0 (Macintosh; Intel Mac OS X 15_6) AppleWebKit/605.1.15 Safari/605.1.15")).toBe(
      "windows"
    )
  })
})

describe("formatSize", () => {
  it("rounds to whole megabytes, or tenths of a gigabyte", () => {
    expect(formatSize(91_400_000)).toBe("91 MB")
    expect(formatSize(999_000_000)).toBe("999 MB")
    expect(formatSize(1_250_000_000)).toBe("1.3 GB")
  })
})
