import { ArrowSquareOutIcon } from "@phosphor-icons/react"
import { useEffect } from "react"
import { Link } from "react-router"
import { SectionLabel } from "@/components/battles"
import { ReleaseCard } from "@/components/changelog"
import { usePageTitle } from "@/hooks/use-page-title"
import { formatDate, releases } from "@/lib/changelog"
import { GITHUB_URL } from "@/lib/config"

/** /changelog: every release, newest first, each with its changes and screenshots. */
export default function ChangelogPage() {
  usePageTitle("Changelog")
  // the game links straight to a release (/changelog/#v0.1.4), and the page
  // is built after the browser looks for it: go there once it's here
  useEffect(() => {
    const id = decodeURIComponent(location.hash.slice(1))
    if (id) document.getElementById(id)?.scrollIntoView({ behavior: "instant" })
  }, [])

  return (
    <div className="topo">
      <div className="mx-auto max-w-6xl px-4 pt-14 pb-24 sm:px-6">
        <SectionLabel>Changelog</SectionLabel>
        <h1 className="mt-2 text-4xl font-semibold">What's changed</h1>
        <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
          Every release of Frontline, newest first. The game updates itself when a new one comes out; you can also{" "}
          <Link to="/play#download" className="text-foreground underline underline-offset-4">
            download the latest
          </Link>
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
            <p className="flex flex-wrap gap-x-6 gap-y-2 text-sm text-muted-foreground">
              <a
                href={`${GITHUB_URL}/blob/main/CHANGELOG.md`}
                className="inline-flex items-center gap-1 hover:text-foreground"
              >
                CHANGELOG.md
                <ArrowSquareOutIcon className="size-3.5" />
              </a>
              <a href={`${GITHUB_URL}/releases`} className="inline-flex items-center gap-1 hover:text-foreground">
                All releases on GitHub
                <ArrowSquareOutIcon className="size-3.5" />
              </a>
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
