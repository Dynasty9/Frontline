import { Link } from "react-router"
import { Emblem } from "@/components/emblem"
import { GITHUB_URL } from "@/lib/config"

const LINKS = [
  { label: "Play", to: "/play" },
  { label: "Live battles", to: "/battles" },
  { label: "Ranks", to: "/ranks" },
  { label: "What's new", to: "/changelog" },
  { label: "Your profile", to: "/profile" },
] as const

export function SiteFooter() {
  return (
    <footer className="border-t">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-6 gap-y-3 px-4 py-8 text-xs text-muted-foreground sm:px-6">
        <span className="flex items-center gap-2">
          <Emblem className="size-5" />
          Frontline is free and open source under the MIT License.
        </span>
        <nav aria-label="Footer" className="flex flex-wrap gap-x-6 gap-y-3 sm:ml-auto">
          {LINKS.map((l) => (
            <Link key={l.to} to={l.to} className="hover:text-foreground">
              {l.label}
            </Link>
          ))}
          <a href={GITHUB_URL} className="hover:text-foreground">
            Source on GitHub
          </a>
          <a href={`${GITHUB_URL}/issues`} className="hover:text-foreground">
            Report a bug
          </a>
        </nav>
      </div>
    </footer>
  )
}
