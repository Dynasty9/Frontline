import { ListIcon, PlayIcon } from "@phosphor-icons/react"
import { useEffect, useState } from "react"
import { Link, useLocation } from "react-router"
import { AccountMenu } from "@/components/account-menu"
import { Emblem, Wordmark } from "@/components/emblem"
import { Button } from "@/components/ui/button"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { useAccount } from "@/lib/account"
import { cn } from "@/lib/utils"

// Keep the same destinations in both states. Personal actions belong to the account menu.
const NAV = [
  { label: "The game", to: "/#intel", paths: ["/"] },
  { label: "Vehicles", to: "/vehicles", paths: ["/vehicles"] },
  { label: "Battles", to: "/battles", paths: ["/battles"] },
  { label: "Commanders", to: "/leaderboards", paths: ["/leaderboards", "/ranks", "/player/"] },
  { label: "Updates", to: "/changelog", paths: ["/changelog"] },
]

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
  const { pathname, hash } = useLocation()
  const { user } = useAccount()
  const signedIn = !!user && accounts !== "off"
  useEffect(() => {
    if (!overlay) return
    const on = () => setScrolled(window.scrollY > 24)
    on()
    window.addEventListener("scroll", on, { passive: true })
    return () => window.removeEventListener("scroll", on)
  }, [overlay])
  const active = (paths: string[]) =>
    paths.some((p) =>
      p === "/" ? pathname === "/" && (!signedIn || !!hash) : p.endsWith("/") ? pathname.startsWith(p) : pathname === p
    )
  const clear = overlay && !scrolled
  return (
    <header
      className={cn(
        "top-0 z-40 border-b",
        overlay ? "fixed inset-x-0" : "sticky",
        clear ? "border-transparent bg-transparent" : "border-white/10 bg-background/95 backdrop-blur-md"
      )}
    >
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:z-50 focus:bg-primary focus:px-4 focus:py-3 focus:text-primary-foreground"
      >
        Skip to content
      </a>
      <div className="mx-auto flex h-16 max-w-6xl items-center gap-3 px-4 sm:px-6 lg:gap-6">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon" className="-ml-2 size-11 lg:hidden" aria-label="Menu">
              <ListIcon className="size-5" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="start" className="w-56">
            {NAV.map((n) => (
              <DropdownMenuItem key={n.to} asChild className="min-h-11 text-sm">
                <Link to={n.to} aria-current={active(n.paths) ? "page" : undefined}>
                  {n.label}
                  {n.to === "/battles" && !!live && <LiveCount n={live} />}
                </Link>
              </DropdownMenuItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
        <Link to="/" className="flex shrink-0 items-center gap-2.5" aria-label="Frontline home">
          <Emblem className="size-7" />
          <Wordmark className="hidden text-xs tracking-[0.16em] min-[375px]:inline sm:text-base sm:tracking-[0.28em]" />
        </Link>
        <nav aria-label="Site" className="ml-auto hidden items-center gap-1 lg:flex">
          {NAV.map((n) => (
            <Link
              key={n.to}
              to={n.to}
              aria-current={active(n.paths) ? "page" : undefined}
              className="inline-flex min-h-11 items-center gap-1 border-b-2 border-transparent px-3 text-sm text-muted-foreground hover:text-foreground aria-[current=page]:border-primary aria-[current=page]:text-foreground"
            >
              {n.label}
              {n.to === "/battles" && !!live && <LiveCount n={live} />}
            </Link>
          ))}
        </nav>
        <div className="ml-auto flex items-center gap-1 sm:gap-2 lg:ml-0">
          <Button asChild className="min-h-11 px-3 text-sm font-bold">
            <Link to="/play" aria-current={pathname === "/play" ? "page" : undefined}>
              <PlayIcon weight="fill" />
              <span>{signedIn ? "Play" : "Play free"}</span>
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
    <span className="inline-flex items-center gap-1 font-mono text-xs text-good">
      <span aria-hidden="true" className="size-1.5 bg-good" />
      {n}
      <span className="sr-only">{n === 1 ? "battle" : "battles"} live</span>
    </span>
  )
}
