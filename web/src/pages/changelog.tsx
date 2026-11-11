import { ArrowSquareOutIcon, CaretDownIcon } from "@phosphor-icons/react"
import { useEffect } from "react"
import { Link, useLocation } from "react-router"
import { SectionLabel } from "@/components/battles"
import { Button } from "@/components/ui/button"
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from "@/components/ui/dropdown-menu"
import { ReleaseCard } from "@/components/changelog"
import { usePageTitle } from "@/hooks/use-page-title"
import { formatDate, releases, releaseForHash } from "@/lib/changelog"
import { GITHUB_URL } from "@/lib/config"
import { cn } from "@/lib/utils"

/** Read one release at a time; the game's existing release and entry links still work. */
export default function ChangelogPage() {
  usePageTitle("Changelog")
  const { hash } = useLocation()
  const selected = releaseForHash(hash)
  useEffect(() => {
    if (!hash) return
    let id: string
    try {
      id = decodeURIComponent(hash.slice(1))
    } catch {
      return
    }
    const target = document.getElementById(id)
    if (target instanceof HTMLDetailsElement) target.open = true
    target?.scrollIntoView({ behavior: "instant", block: "start" })
  }, [hash])

  return (
    <div>
      <div className="mx-auto max-w-6xl px-4 pt-12 pb-24 sm:px-6">
        <SectionLabel>Field notes / Updates</SectionLabel>
        <div className="mt-4 flex flex-wrap items-end justify-between gap-6">
          <div>
            <h1 className="font-display text-6xl leading-none font-extrabold uppercase sm:text-8xl">What's changed</h1>
            <p className="mt-5 max-w-xl text-base leading-relaxed text-muted-foreground">
              The latest improvements, at a glance. Open any change for the full story, screenshots and footage.
            </p>
          </div>
          <Button asChild variant="outline">
            <Link to="/play#download">Get the latest version</Link>
          </Button>
        </div>
        <div className="mt-8 lg:hidden">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                variant="outline"
                className="w-full justify-between"
                aria-label={`Choose a release: ${selected?.tag ?? ""}`}
              >
                {selected?.tag ?? "Choose a release"} <CaretDownIcon />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent className="max-h-80">
              {releases.map((r) => (
                <DropdownMenuItem key={r.tag} asChild>
                  <Link to={`#${r.tag}`} className="gap-3" aria-current={r === selected ? "page" : undefined}>
                    <span className="font-mono text-primary">{r.tag}</span>
                    <span className="truncate">{r.name}</span>
                  </Link>
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
        <div className="mt-12 grid gap-10 lg:grid-cols-[200px_minmax(0,1fr)]">
          <nav className="hidden lg:block" aria-label="Releases">
            <div className="sticky top-24">
              <p className="mb-4 font-mono text-xs tracking-widest text-muted-foreground uppercase">Release archive</p>
              <ol className="max-h-[calc(100svh-10rem)] space-y-1 overflow-y-auto border-l pr-3">
                {releases.map((r) => (
                  <li key={r.tag}>
                    <Link
                      to={`#${r.tag}`}
                      aria-current={r === selected ? "page" : undefined}
                      className={cn(
                        "-ml-px block border-l py-3 pl-4 text-sm transition-colors hover:border-primary hover:text-foreground",
                        r === selected
                          ? "border-primary bg-primary/5 text-foreground"
                          : "border-transparent text-muted-foreground"
                      )}
                    >
                      <span className="font-mono text-xs text-primary">
                        {r.tag}
                        {r === releases[0] && " / Latest"}
                      </span>
                      <span className="mt-1 block leading-snug">{r.name}</span>
                      <span className="mt-1 block text-xs text-muted-foreground">{formatDate(r.date)}</span>
                    </Link>
                  </li>
                ))}
              </ol>
            </div>
          </nav>
          <div className="min-w-0">
            {selected && <ReleaseCard key={selected.tag} release={selected} latest={selected === releases[0]} />}
            <p className="mt-12 flex flex-wrap gap-x-6 gap-y-2 border-t pt-6 text-sm text-muted-foreground">
              <a
                href={`${GITHUB_URL}/blob/main/CHANGELOG.md`}
                className="inline-flex items-center gap-1 hover:text-foreground"
              >
                Text archive <ArrowSquareOutIcon className="size-3.5" />
              </a>
              <a href={`${GITHUB_URL}/releases`} className="inline-flex items-center gap-1 hover:text-foreground">
                Releases on GitHub <ArrowSquareOutIcon className="size-3.5" />
              </a>
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
