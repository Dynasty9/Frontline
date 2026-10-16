import { DownloadSimpleIcon, GithubLogoIcon, UserCircleIcon } from "@phosphor-icons/react"
import { useEffect, useState } from "react"
import { Emblem, Wordmark } from "@/components/emblem"
import { InsigniaImg } from "@/components/insignia-img"
import { Button } from "@/components/ui/button"
import { useAccount } from "@/lib/account"
import { GITHUB_URL } from "@/lib/config"
import { rankName, wornInsignia } from "@/lib/insignia"
import { cn } from "@/lib/utils"

// absolute, so they work from the changelog page too
const NAV = [
  ["The game", "/#intel"],
  ["Missions", "/#missions"],
  ["Battles", "/#battles"],
  ["Insignia", "/#insignia"],
  ["What's new", "/changelog/"],
] as const
// on a tablet there isn't room for every link beside the account chip
const WIDE_ONLY = new Set<string>(["/#insignia"])

/**
 * The site's header. With `overlay` (the front page) it floats clear over the
 * hero's footage and takes on a backing once the page scrolls under it;
 * otherwise it's a solid bar that sits above the page. `accounts` is the
 * matchmaker's /health answer: "off" hides signing in.
 */
export function SiteHeader({ overlay = false, accounts }: { overlay?: boolean; accounts?: string }) {
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
        <a href="/" className="flex items-center gap-2.5" aria-label="Frontline home">
          <Emblem className="size-7" />
          <Wordmark className="text-base" />
        </a>
        <nav className="ml-auto hidden items-center gap-1 md:flex">
          {NAV.map(([label, href]) => (
            <Button
              key={href}
              variant="ghost"
              size="sm"
              asChild
              className={cn(
                "text-sm text-muted-foreground hover:text-foreground",
                WIDE_ONLY.has(href) && "hidden lg:inline-flex"
              )}
            >
              <a href={href}>{label}</a>
            </Button>
          ))}
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
            <a href="/#download">
              <DownloadSimpleIcon weight="bold" />
              Download
            </a>
          </Button>
          {accounts !== "off" && <AccountChip />}
        </div>
      </div>
    </header>
  )
}

/** Signed in: your insignia, callsign and rank, which take you to your profile. */
function AccountChip() {
  const { user } = useAccount()
  if (!user) {
    return (
      <Button variant="ghost" size="sm" asChild className="text-sm text-muted-foreground hover:text-foreground">
        <a href="/#insignia" aria-label="Sign in">
          <UserCircleIcon />
          <span className="hidden lg:inline">Sign in</span>
        </a>
      </Button>
    )
  }
  const worn = wornInsignia(user.icon)
  return (
    <Button variant="outline" size="sm" asChild className="h-8 gap-2 pr-2 pl-1 text-sm">
      <a href="/#insignia" aria-label={`${user.callsign}, ${rankName(user.rank)}: your profile and insignia`}>
        {worn && <InsigniaImg id={worn.id} />}
        {/* the callsign only where there's room for it beside the nav (it's in the profile anyway) */}
        <span className="hidden max-w-36 truncate sm:block md:hidden lg:block">{user.callsign}</span>
        <span className="border border-primary/40 px-1 text-[10px] leading-4 font-bold text-primary tabular-nums">
          {user.rank}
        </span>
      </a>
    </Button>
  )
}
