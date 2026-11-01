import { ArrowSquareOutIcon, CaretDownIcon } from "@phosphor-icons/react"
import { useEffect } from "react"
import { Link } from "react-router"
import { SectionLabel } from "@/components/battles"
import { Button } from "@/components/ui/button"
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from "@/components/ui/dropdown-menu"
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
      <div className="mx-auto max-w-6xl px-4 pt-16 pb-24 sm:px-6">
        <SectionLabel>Changelog</SectionLabel>
        <h1 className="mt-4 font-display text-6xl leading-none font-extrabold uppercase sm:text-8xl">What's changed</h1>
        <p className="mt-5 max-w-xl text-base leading-relaxed text-muted-foreground">
          Every release of Frontline, newest first. The game updates itself when a new one comes out; you can also{" "}
          <Link to="/play#download" className="text-foreground underline underline-offset-4">
            download the latest
          </Link>
          .
        </p>

        <div className="mt-8 lg:hidden">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" className="w-full justify-between">
                Jump to a release <CaretDownIcon />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent className="max-h-80">
              {releases.map((r) => (
                <DropdownMenuItem key={r.tag} asChild>
                  <a href={`#${r.tag}`} className="gap-3">
                    <span className="font-mono text-primary">{r.tag}</span>
                    <span className="truncate">{r.name}</span>
                  </a>
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
        <div className="mt-14 grid gap-12 lg:grid-cols-[168px_minmax(0,1fr)]">
          <nav className="hidden lg:block" aria-label="Releases">
            <ol className="sticky top-24 max-h-[calc(100svh-8rem)] space-y-3 overflow-y-auto border-l pr-3">
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
          <div className="min-w-0 space-y-16">
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
