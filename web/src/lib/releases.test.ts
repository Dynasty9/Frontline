import { afterEach, describe, expect, it, vi } from "vitest"
import { formatSize, guessDevice, guessPlatform, latest, PLATFORM_NAMES } from "@/lib/releases"

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

  it("has a zip for every platform, with its size and checksum", () => {
    for (const p of Object.keys(PLATFORM_NAMES) as (keyof typeof PLATFORM_NAMES)[]) {
      const a = latest.assets[p]
      expect(a.url).toMatch(/^https:\/\/.+\.zip$/)
      expect(a.size).toBeGreaterThan(0)
      expect(a.sha256).toMatch(/^[0-9a-f]{64}$/)
    }
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

const deviceFor = (userAgent: string, maxTouchPoints = 0) => {
  vi.stubGlobal("navigator", { userAgent, maxTouchPoints })
  return guessDevice()
}

describe("guessDevice", () => {
  it("is the platform on a Windows or Linux computer", () => {
    expect(deviceFor("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140.0")).toBe("windows")
    expect(deviceFor("Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0")).toBe("linux")
  })

  it("knows a Mac", () => {
    expect(deviceFor("Mozilla/5.0 (Macintosh; Intel Mac OS X 15_6) AppleWebKit/605.1.15 Safari/605.1.15")).toBe("mac")
  })

  it("takes phones and tablets for what they are, an iPad asking for the desktop site too", () => {
    expect(deviceFor("Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 Chrome/140.0 Mobile")).toBe("mobile")
    expect(deviceFor("Mozilla/5.0 (iPhone; CPU iPhone OS 19_0 like Mac OS X) AppleWebKit/605.1.15 Mobile")).toBe(
      "mobile"
    )
    expect(deviceFor("Mozilla/5.0 (Macintosh; Intel Mac OS X 15_6) AppleWebKit/605.1.15 Safari/605.1.15", 5)).toBe(
      "mobile"
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
