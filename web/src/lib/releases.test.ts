import { afterEach, describe, expect, it, vi } from "vitest"
import { formatSize, guessPlatform, latest, platformList, platformsOf } from "@/lib/releases"
import { buildWithMac } from "@/test/fixtures"

afterEach(() => {
  vi.unstubAllGlobals()
})

// src/release.json is rewritten by every release (.github/workflows/release.yml):
// whatever it holds, the download buttons have to be able to use it
describe("the baked-in release", () => {
  it("names a version and its release page", () => {
    expect(latest.tag).toBe(`v${latest.version}`)
    expect(latest.url).toMatch(/^https:\/\/github\.com\/.+\/releases\/tag\//)
    expect(Number.isNaN(Date.parse(latest.published))).toBe(false)
  })

  it("has a zip for every platform it's for, with its size and checksum", () => {
    expect(platformsOf(latest)).toEqual(expect.arrayContaining(["windows", "linux"]))
    for (const p of platformsOf(latest)) {
      const a = latest.assets[p]!
      expect(a.url).toMatch(/^https:\/\/.+\.zip$/)
      expect(a.size).toBeGreaterThan(0)
      expect(a.sha256).toMatch(/^[0-9a-f]{64}$/)
    }
  })
})

describe("the platforms a release is for", () => {
  it("lists a Mac build only once a release has one", () => {
    expect(platformsOf(buildWithMac)).toEqual(["windows", "macos", "linux"])
    expect(
      platformsOf({ ...buildWithMac, assets: { windows: latest.assets.windows, linux: latest.assets.linux } })
    ).toEqual(["windows", "linux"])
  })

  it("says them as a sentence does", () => {
    expect(platformList(buildWithMac)).toBe("Windows, macOS and Linux")
    expect(
      platformList({ ...buildWithMac, assets: { windows: latest.assets.windows, linux: latest.assets.linux } })
    ).toBe("Windows and Linux")
  })
})

const MAC = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_6) AppleWebKit/605.1.15 Safari/605.1.15"

const platformFor = (userAgent: string, build = buildWithMac, maxTouchPoints = 0) => {
  vi.stubGlobal("navigator", { userAgent, maxTouchPoints })
  return guessPlatform(build)
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

  it("spots a Mac", () => {
    expect(platformFor(MAC)).toBe("macos")
  })

  it("takes an iPad asking for the desktop page for a tablet, not a Mac", () => {
    expect(platformFor(MAC, buildWithMac, 5)).toBe("windows")
  })

  it("offers a Mac the Windows build while a release has none for it", () => {
    const old = { ...buildWithMac, assets: { windows: latest.assets.windows, linux: latest.assets.linux } }
    expect(platformFor(MAC, old)).toBe("windows")
  })

  it("defaults to Windows", () => {
    expect(platformFor("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140.0")).toBe("windows")
    expect(
      platformFor(
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1"
      )
    ).toBe("windows")
  })
})

describe("formatSize", () => {
  it("rounds to whole megabytes, or tenths of a gigabyte", () => {
    expect(formatSize(91_400_000)).toBe("91 MB")
    expect(formatSize(999_000_000)).toBe("999 MB")
    expect(formatSize(1_250_000_000)).toBe("1.3 GB")
  })
})
