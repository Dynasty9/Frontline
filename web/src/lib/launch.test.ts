import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { HANDOFF_MS, knownInstalled, rememberInstalled, watchHandoff } from "@/lib/launch"

// a page's window and document, as far as the watch needs them
const page = () => {
  const win = new EventTarget()
  const doc = Object.assign(new EventTarget(), { hidden: false })
  return { win, doc }
}

describe("watchHandoff", () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })
  afterEach(() => {
    vi.useRealTimers()
  })

  it("is a handoff when the page loses focus (the browser's prompt, or the game's window)", async () => {
    const { win, doc } = page()
    const handed = watchHandoff(win, doc)
    vi.advanceTimersByTime(400)
    win.dispatchEvent(new Event("blur"))
    await expect(handed).resolves.toBe(true)
  })

  it("is a handoff when the page is hidden", async () => {
    const { win, doc } = page()
    const handed = watchHandoff(win, doc)
    doc.hidden = true
    doc.dispatchEvent(new Event("visibilitychange"))
    await expect(handed).resolves.toBe(true)
  })

  it("isn't one when nothing happens in time: nothing took the link", async () => {
    const { win, doc } = page()
    const handed = watchHandoff(win, doc)
    vi.advanceTimersByTime(HANDOFF_MS)
    await expect(handed).resolves.toBe(false)
  })

  it("stops listening once it has its answer", async () => {
    const { win, doc } = page()
    const off = vi.spyOn(win, "removeEventListener")
    const handed = watchHandoff(win, doc)
    vi.advanceTimersByTime(HANDOFF_MS)
    await handed
    expect(off).toHaveBeenCalledWith("blur", expect.any(Function))
  })
})

describe("knownInstalled", () => {
  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it("remembers a handoff, and says no when there's no storage", () => {
    const store = new Map<string, string>()
    vi.stubGlobal("localStorage", {
      getItem: (k: string) => store.get(k) ?? null,
      setItem: (k: string, v: string) => store.set(k, v),
    })
    expect(knownInstalled()).toBe(false)
    rememberInstalled()
    expect(knownInstalled()).toBe(true)
    vi.stubGlobal("localStorage", undefined)
    expect(knownInstalled()).toBe(false)
    expect(() => rememberInstalled()).not.toThrow()
  })
})
