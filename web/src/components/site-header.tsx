import { GithubLogoIcon, UserCircleIcon } from "@phosphor-icons/react"
import { Emblem, Wordmark } from "@/components/emblem"
import { InsigniaImg } from "@/components/insignia-img"
import { Button } from "@/components/ui/button"
import { useAccount } from "@/lib/account"
import { GITHUB_URL } from "@/lib/config"
import { rankName, wornInsignia } from "@/lib/insignia"

// absolute, so they work from the changelog page too
const NAV = [
  ["Battles", "/#battles"],
  ["Insignia", "/#insignia"],
  ["What's new", "/changelog/"],
  ["Download", "/#download"],
  ["Screenshots", "/#screenshots"],
] as const

// `accounts` is the matchmaker's /health answer: "off" hides signing in.
export function SiteHeader({ accounts }: { accounts?: string }) {
  return (
    <header className="sticky top-0 z-40 border-b bg-background/80 backdrop-blur-md">
      <div className="mx-auto flex h-14 max-w-6xl items-center gap-3 px-4 sm:gap-6 sm:px-6">
        <a href="/" className="flex shrink-0 items-center gap-2.5" aria-label="Frontline home">
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
              className="text-sm text-muted-foreground hover:text-foreground"
            >
              <a href={href}>{label}</a>
            </Button>
          ))}
        </nav>
        <div className="ml-auto flex items-center gap-2 md:ml-0">
          <Button variant="outline" size="sm" asChild className="text-sm">
            <a href={GITHUB_URL} target="_blank" rel="noreferrer" aria-label="Frontline on GitHub">
              <GithubLogoIcon weight="fill" />
              <span className="hidden lg:inline">GitHub</span>
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
        <a href="/#insignia">
          <UserCircleIcon />
          Sign in
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
