import { Link } from "react-router"
import { SectionLabel } from "@/components/battles"
import { Button } from "@/components/ui/button"
import { usePageTitle } from "@/hooks/use-page-title"

/** Anywhere the site has no page for. */
export default function NotFound() {
  usePageTitle("Not found")
  return (
    <div className="topo">
      <div className="mx-auto flex min-h-[60svh] max-w-6xl flex-col items-start justify-center px-4 py-24 sm:px-6">
        <SectionLabel>404</SectionLabel>
        <h1 className="mt-3 font-display text-5xl leading-[0.95] font-extrabold uppercase sm:text-6xl">
          Off the map. <span className="text-primary">No such page.</span>
        </h1>
        <p className="mt-4 max-w-xl text-sm text-muted-foreground">
          The link may be old, or mistyped. Fall back to the front page, or straight to a battle.
        </p>
        <div className="mt-8 flex flex-wrap gap-3">
          <Button asChild className="font-semibold">
            <Link to="/">The front page</Link>
          </Button>
          <Button asChild variant="outline">
            <Link to="/play">Play</Link>
          </Button>
        </div>
      </div>
    </div>
  )
}
