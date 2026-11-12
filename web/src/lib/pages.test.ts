import { matchRoutes } from "react-router"
import { describe, expect, it } from "vitest"
import { SECTIONS } from "./manual"
import { headFor, sitePages } from "./pages"
import { routes } from "@/router"

const pages = sitePages()

describe("the pages the build writes out", () => {
  it("has each address once, every one a page the site routes", () => {
    expect(new Set(pages.map((p) => p.path)).size).toBe(pages.length)
    const unrouted = pages.filter((p) => !matchRoutes(routes, p.path)?.some((m) => m.route.path !== "*"))
    expect(unrouted.map((p) => p.path)).toEqual([])
  })
  it("gives every Field Manual entry its own card", () => {
    for (const s of SECTIONS)
      for (const e of s.entries) {
        const page = pages.find((p) => p.path === `/manual/${s.key}/${encodeURIComponent(e.id)}`)
        expect(page?.title).toBe(`${e.name} · ${s.title} · Frontline`)
      }
    for (const p of pages) expect(p.description.length).toBeGreaterThan(20)
  })
  it("keeps sign-in pages and old addresses out of the sitemap", () => {
    const unlisted = pages.filter((p) => !p.listed).map((p) => p.path)
    expect(unlisted).toEqual(["/profile", "/account", "/vehicles"])
  })
  it("writes an absolute, escaped head", () => {
    const head = headFor(
      {
        path: "/manual",
        title: 'A "quoted" & <odd> title',
        description: "x".repeat(30),
        image: "/media/a.jpg",
        listed: false,
      },
      "https://example.test"
    )
    expect(head).toContain('<link rel="canonical" href="https://example.test/manual" />')
    expect(head).toContain('<meta property="og:image" content="https://example.test/media/a.jpg" />')
    expect(head).toContain("<title>A &quot;quoted&quot; &amp; &lt;odd> title</title>")
    expect(head).toContain('<meta name="robots" content="noindex" />')
  })
})
