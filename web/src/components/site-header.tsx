import { GithubLogoIcon, ListIcon, PlayIcon } from "@phosphor-icons/react"
import { useEffect, useState } from "react"
import { Link, NavLink } from "react-router"
import { AccountMenu } from "@/components/account-menu"
import { Emblem, Wordmark } from "@/components/emblem"
import { Button } from "@/components/ui/button"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { GITHUB_URL } from "@/lib/config"
import { cn } from "@/lib/utils"

// The front page's sections (/#intel) and the site's other pages. `wide`: on a
// tablet there isn't room for every link beside the account.
const NAV = [
  { label: "The game", to: "/#intel", wide: true },
  { label: "Battles", to: "/battles" },
  { label: "Ranks", to: "/#insignia" },
  { label: "What's new", to: "/changelog" },
] as const

/**
 * The site's header. With `overlay` (the front page) it floats clear over the
 * hero's footage and takes on a backing once the page scrolls under it;
 * otherwise it's a solid bar that sits above the page. `accounts` is the
 * matchmaker's /health answer ("off" hides signing in); `live` is how many
 * battles are being hosted.
 */
export function SiteHeader({
  overlay = false,
  accounts,
  live,
}: {
  overlay?: boolean
  accounts?: string
  live?: number
}) {
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
        clear ? "border-transparent bg-transparent" : "border-white/10 bg-background/80 backdrop-blur-md"
      )}
    >
      <div className="mx-auto flex h-14 max-w-6xl items-center gap-3 px-4 sm:px-6 lg:gap-6">
        <MobileNav live={live} />
        <Link to="/" className="flex items-center gap-2.5" aria-label="Frontline home">
          <Emblem className="size-7" />
          <Wordmark className="text-base" />
        </Link>
        <nav aria-label="Site" className="ml-auto hidden items-center gap-1 md:flex">
          {NAV.map((n) => {
            // a page's link says when you're on it (aria-current); a front-page section's never does
            const To = n.to.includes("#") ? Link : NavLink
            return (
              <Button
                key={n.to}
                variant="ghost"
                size="sm"
                asChild
                className={cn(
                  "text-sm text-muted-foreground hover:text-foreground aria-[current=page]:text-foreground",
                  "wide" in n && "hidden lg:inline-flex"
                )}
              >
                <To to={n.to}>
                  {n.label}
                  {n.to === "/battles" && !!live && <LiveCount n={live} />}
                </To>
              </Button>
            )
          })}
        </nav>
        <div className="ml-auto flex items-center gap-2 md:ml-0">
          {/* on a phone it makes way for the account (the footer links the source too) */}
          <Button variant="outline" size="sm" asChild className="hidden text-sm sm:inline-flex">
            <a href={GITHUB_URL} target="_blank" rel="noreferrer" aria-label="Frontline on GitHub">
              <GithubLogoIcon weight="fill" />
              <span className="hidden lg:inline">GitHub</span>
            </a>
          </Button>
          <Button size="sm" asChild className="text-sm font-bold">
            <Link to="/play">
              <PlayIcon weight="fill" />
              Play
            </Link>
          </Button>
          {accounts !== "off" && <AccountMenu />}
        </div>
      </div>
    </header>
  )
}

function LiveCount({ n }: { n: number }) {
  return (
    <span className="ml-0.5 inline-flex items-center gap-1 text-xs text-good tabular-nums">
      <span className="size-1.5 rounded-full bg-good" />
      {n}
      <span className="sr-only">{n === 1 ? "battle" : "battles"} live</span>
    </span>
  )
}

/** On a phone the links fold into a menu. */
function MobileNav({ live }: { live?: number }) {
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon-sm" className="-ml-2 md:hidden" aria-label="Menu">
          <ListIcon className="size-5" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="w-48">
        {[{ label: "Play", to: "/play" }, ...NAV].map((n) => (
          <DropdownMenuItem key={n.to} asChild>
            <Link to={n.to}>
              {n.label}
              {n.to === "/battles" && !!live && <LiveCount n={live} />}
            </Link>
          </DropdownMenuItem>
        ))}
        <DropdownMenuItem asChild>
          <a href={GITHUB_URL} target="_blank" rel="noreferrer">
            Source on GitHub
          </a>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
