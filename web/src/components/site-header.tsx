import { GithubLogoIcon } from "@phosphor-icons/react"
import { Emblem, Wordmark } from "@/components/emblem"
import { Button } from "@/components/ui/button"
import { GITHUB_URL } from "@/lib/config"

const NAV = [
  ["Battles", "#battles"],
  ["Download", "#download"],
  ["Screenshots", "#screenshots"],
] as const

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-40 border-b bg-background/80 backdrop-blur-md">
      <div className="mx-auto flex h-14 max-w-6xl items-center gap-6 px-4 sm:px-6">
        <a href="#top" className="flex items-center gap-2.5" aria-label="Frontline, back to top">
          <Emblem className="size-7" />
          <Wordmark className="text-base" />
        </a>
        <nav className="ml-auto hidden items-center gap-1 sm:flex">
          {NAV.map(([label, href]) => (
            <Button key={href} variant="ghost" size="sm" asChild className="text-sm text-muted-foreground hover:text-foreground">
              <a href={href}>{label}</a>
            </Button>
          ))}
        </nav>
        <Button variant="outline" size="sm" asChild className="ml-auto text-sm sm:ml-0">
          <a href={GITHUB_URL} target="_blank" rel="noreferrer">
            <GithubLogoIcon weight="fill" />
            GitHub
          </a>
        </Button>
      </div>
    </header>
  )
}
