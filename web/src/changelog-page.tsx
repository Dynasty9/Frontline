import { useEffect } from "react"
import { SectionLabel } from "@/components/battles"
import { ReleaseCard } from "@/components/changelog"
import { Emblem } from "@/components/emblem"
import { SiteHeader } from "@/components/site-header"
import { TooltipProvider } from "@/components/ui/tooltip"
import { formatDate, releases } from "@/lib/changelog"
import { GITHUB_URL } from "@/lib/config"

/** /changelog/: every release, newest first, each with its changes and screenshots. */
export default function ChangelogPage() {
  // the page is built before the browser scrolls to #v0.1.4: do it once it's there
  useEffect(() => {
    const id = decodeURIComponent(location.hash.slice(1))
    if (id) document.getElementById(id)?.scrollIntoView({ behavior: "instant" })
  }, [])

  return (
    <TooltipProvider>
      <SiteHeader />
      <main className="topo">
        <div className="mx-auto max-w-6xl px-4 pt-14 pb-24 sm:px-6">
          <SectionLabel>Changelog</SectionLabel>
          <h1 className="mt-2 text-4xl font-semibold">What's changed</h1>
          <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            Every release of Frontline, newest first. The game updates itself when a new one comes out; you can also{" "}
            <a href="/#download" className="text-foreground underline underline-offset-4">
              download the latest
            </a>
            .
          </p>

          <div className="mt-10 grid gap-10 lg:grid-cols-[200px_1fr]">
            <nav className="hidden lg:block" aria-label="Releases">
              <ol className="sticky top-24 space-y-1 border-l">
                {releases.map((r) => (
                  <li key={r.tag}>
                    <a
                      href={`#${r.tag}`}
                      className="-ml-px block border-l border-transparent py-1 pl-4 text-sm text-muted-foreground hover:border-primary hover:text-foreground"
                    >
                      <span className="font-mono text-xs text-primary">{r.tag}</span>
                      <span className="block truncate">{r.name}</span>
                      <span className="block text-xs opacity-70">{formatDate(r.date)}</span>
                    </a>
                  </li>
                ))}
              </ol>
            </nav>
            <div className="min-w-0 space-y-8">
              {releases.map((r, i) => (
                <ReleaseCard key={r.tag} release={r} latest={i === 0} />
              ))}
            </div>
          </div>
        </div>
      </main>
      <footer className="border-t">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-6 gap-y-3 px-4 py-8 text-xs text-muted-foreground sm:px-6">
          <span className="flex items-center gap-2">
            <Emblem className="size-5" />
            Frontline is free and open source under the MIT License.
          </span>
          <a href={`${GITHUB_URL}/blob/main/CHANGELOG.md`} className="hover:text-foreground sm:ml-auto">
            CHANGELOG.md
          </a>
          <a href={`${GITHUB_URL}/releases`} className="hover:text-foreground">
            All releases on GitHub
          </a>
        </div>
      </footer>
    </TooltipProvider>
  )
}
