import { Link } from "react-router"
import { Emblem } from "@/components/emblem"
import { useAccount } from "@/lib/account"
import { GITHUB_URL } from "@/lib/config"

export function SiteFooter({ accounts }: { accounts?: string }) {
  const { user } = useAccount()
  return (
    <footer className="border-t">
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-12 sm:grid-cols-[1fr_2fr] sm:px-6">
        <div>
          <Link to="/" className="flex items-center gap-3 text-sm font-bold tracking-widest uppercase">
            <Emblem className="size-6" />
            Frontline
          </Link>
          <p className="mt-4 max-w-xs text-sm leading-relaxed text-muted-foreground">
            Squad tactics. Combined arms.
            <br />
            Free to play, with or without an account.
          </p>
        </div>
        <nav aria-label="Footer" className="grid grid-cols-2 gap-8 text-sm sm:grid-cols-3">
          <div className="space-y-3">
            <p className="font-mono text-xs text-muted-foreground uppercase">Discover</p>
            <Link className="block hover:text-primary" to="/#intel">
              The game
            </Link>
            <Link className="block hover:text-primary" to="/changelog">
              Updates
            </Link>
            <Link className="block hover:text-primary" to="/vehicles">
              Vehicles
            </Link>
          </div>
          <div className="space-y-3">
            <p className="font-mono text-xs text-muted-foreground uppercase">Take part</p>
            <Link className="block hover:text-primary" to="/play">
              Play & download
            </Link>
            <Link className="block hover:text-primary" to="/battles">
              Live battles
            </Link>
            <Link className="block hover:text-primary" to="/leaderboards">
              Commanders
            </Link>
            {user && accounts !== "off" && (
              <Link className="block hover:text-primary" to="/profile">
                Your profile
              </Link>
            )}
          </div>
          <div className="space-y-3">
            <p className="font-mono text-xs text-muted-foreground uppercase">Project</p>
            <a className="block hover:text-primary" href={GITHUB_URL}>
              Source on GitHub
            </a>
            <a className="block hover:text-primary" href={`${GITHUB_URL}/issues`}>
              Report a bug
            </a>
            <p className="text-xs text-muted-foreground">Open source · MIT License</p>
          </div>
        </nav>
      </div>
    </footer>
  )
}
