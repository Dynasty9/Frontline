import { DownloadSimpleIcon, GithubLogoIcon } from "@phosphor-icons/react"
import { useEffect, useState } from "react"
import { Emblem, Wordmark } from "@/components/emblem"
import { Button } from "@/components/ui/button"
import { GITHUB_URL } from "@/lib/config"
import { cn } from "@/lib/utils"

// absolute, so they work from the changelog page too
const NAV = [
  ["The game", "/#intel"],
  ["Missions", "/#missions"],
  ["Battles", "/#battles"],
  ["What's new", "/changelog/"],
] as const

/**
 * The site's header. With `overlay` (the front page) it floats clear over the
 * hero's footage and takes on a backing once the page scrolls under it;
 * otherwise it's a solid bar that sits above the page.
 */
export function SiteHeader({ overlay = false }: { overlay?: boolean }) {
  const [scrolled, setScrolled] = useState(false)
  useEffect(() => {
    if (!overlay) return
    const on = () => setScrolled(window.scrollY > 24)
    on()
    window.addEventListener("scroll", on, { passive: true })
    return () => window.removeEventListener("scroll", on)
  }, [overlay])

  const clear = overlay && !scrolled
  return (
    <header
      className={cn(
        "top-0 z-40 border-b transition-[background-color,border-color,backdrop-filter] duration-300",
        overlay ? "fixed inset-x-0" : "sticky",
        clear ? "border-transparent bg-transparent" : "border-white/10 bg-background/80 backdrop-blur-md",
      )}
    >
      <div className="mx-auto flex h-14 max-w-6xl items-center gap-6 px-4 sm:px-6">
        <a href="/" className="flex items-center gap-2.5" aria-label="Frontline home">
          <Emblem className="size-7" />
          <Wordmark className="text-base" />
        </a>
        <nav className="ml-auto hidden items-center gap-1 md:flex">
          {NAV.map(([label, href]) => (
            <Button key={href} variant="ghost" size="sm" asChild className="text-sm text-muted-foreground hover:text-foreground">
              <a href={href}>{label}</a>
            </Button>
          ))}
        </nav>
        <div className="ml-auto flex items-center gap-2 md:ml-0">
          <Button variant="outline" size="sm" asChild className="text-sm">
            <a href={GITHUB_URL} target="_blank" rel="noreferrer" aria-label="Frontline on GitHub">
              <GithubLogoIcon weight="fill" />
              <span className="hidden sm:inline">GitHub</span>
            </a>
          </Button>
          <Button size="sm" asChild className="text-sm font-bold">
            <a href="/#download">
              <DownloadSimpleIcon weight="bold" />
              Download
            </a>
          </Button>
        </div>
      </div>
    </header>
  )
}
