import { describe, expect, it, vi } from "vitest"
import { withFreshBuild } from "./stale-build"

function env(path = "/profile") {
  const saved = new Map<string, string>()
  const storage = {
    getItem: (k: string) => saved.get(k) ?? null,
    setItem: (k: string, v: string) => void saved.set(k, v),
    removeItem: (k: string) => void saved.delete(k),
  }
  const reload = vi.fn<() => void>()
  return { saved, reload, env: () => ({ storage, path, reload }) }
}

const gone = () => Promise.reject(new TypeError("Failed to fetch dynamically imported module"))
const settled = (p: Promise<unknown>) =>
  Promise.race([
    p.then(
      () => true,
      () => true
    ),
    new Promise((r) => setTimeout(() => r(false), 20)),
  ])

describe("loading a page from an older build", () => {
  it("reloads the page once when its code is gone", async () => {
    const tab = env()
    const page = withFreshBuild(gone, tab.env)
    expect(await settled(page)).toBe(false)
    expect(tab.reload).toHaveBeenCalledOnce()
  })
  it("shows the error if the reload didn't help", async () => {
    const tab = env()
    void withFreshBuild(gone, tab.env)
    await new Promise((r) => setTimeout(r, 0))
    await expect(withFreshBuild(gone, tab.env)).rejects.toThrow("dynamically imported")
    expect(tab.reload).toHaveBeenCalledOnce()
  })
  it("forgets the reload once a page loads", async () => {
    const tab = env()
    void withFreshBuild(gone, tab.env)
    await new Promise((r) => setTimeout(r, 0))
    await expect(withFreshBuild(() => Promise.resolve("page"), tab.env)).resolves.toBe("page")
    expect(tab.saved.size).toBe(0)
  })
  it("never reloads without somewhere to remember it", async () => {
    const reload = vi.fn<() => void>()
    await expect(withFreshBuild(gone, () => ({ storage: null, path: "/", reload }))).rejects.toThrow(
      "dynamically imported"
    )
    expect(reload).not.toHaveBeenCalled()
  })
})
