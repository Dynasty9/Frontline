// After `vite build`: every page at a fixed address written out with its own
// title, description and link card (src/lib/pages.ts), so a search engine or
// a chat app, which don't run the site's code, see that page's and not the
// front page's; then sitemap.xml, robots.txt, and 404.html for the addresses
// the site has no page for (nginx.conf answers those with a 404). Each file is
// the same page otherwise: the site's code takes over as soon as it loads.
//
//   node scripts/prerender.mjs        (SITE_URL: the site's address, for the cards and the sitemap)

import { mkdirSync, readFileSync, writeFileSync } from "node:fs"
import path from "node:path"
import { createServer } from "vite"

const root = path.resolve(import.meta.dirname, "..")
const dist = path.join(root, "dist")
const origin = (process.env.SITE_URL || "https://web-production-5a4c1.up.railway.app").replace(/\/+$/, "")

// the page list reads the game's tables the way the site does (?raw imports), so Vite loads it
const vite = await createServer({
  root,
  configFile: path.join(root, "vite.config.ts"),
  server: { middlewareMode: true },
  appType: "custom",
  logLevel: "error",
})
try {
  const { sitePages, headFor } = await vite.ssrLoadModule("/src/lib/pages.ts")
  const shell = readFileSync(path.join(dist, "index.html"), "utf8")
  const region = /<!-- page:[\s\S]*?<!-- \/page -->/
  if (!region.test(shell)) throw new Error("index.html has lost its <!-- page: --> ... <!-- /page --> markers")
  const write = (file, head) => {
    mkdirSync(path.dirname(file), { recursive: true })
    writeFileSync(file, shell.replace(region, head))
  }

  const pages = sitePages()
  for (const page of pages) {
    const file = page.path === "/" ? "index.html" : path.join(decodeURIComponent(page.path), "index.html")
    write(path.join(dist, file), headFor(page, origin))
  }
  write(
    path.join(dist, "404.html"),
    headFor(
      {
        path: "/404",
        title: "Not found · Frontline",
        description: "There's no page at this address.",
        image: "/media/hero.jpg",
        listed: false,
      },
      origin
    )
  )

  const listed = pages.filter((p) => p.listed)
  const loc = (p) => `${origin}${p.path === "/" ? "/" : p.path}`.replaceAll("&", "&amp;")
  writeFileSync(
    path.join(dist, "sitemap.xml"),
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${listed
      .map((p) => `  <url><loc>${loc(p)}</loc></url>`)
      .join("\n")}\n</urlset>\n`
  )
  writeFileSync(path.join(dist, "robots.txt"), `User-agent: *\nAllow: /\n\nSitemap: ${origin}/sitemap.xml\n`)
  console.log(`prerender: ${pages.length} pages (${listed.length} in the sitemap) and 404.html for ${origin}`)
} finally {
  await vite.close()
}
