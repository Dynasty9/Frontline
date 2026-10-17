import { NavLink } from "react-router"

/** Rankings compare players; the guide explains progression. Neither edits your account. */
export function CommandersNav() {
  return (
    <nav aria-label="Commanders" className="mx-auto flex max-w-6xl gap-6 border-b px-4 sm:px-6">
      <NavLink
        to="/leaderboards"
        className="border-b-2 border-transparent py-4 text-sm text-muted-foreground hover:text-foreground aria-[current=page]:border-primary aria-[current=page]:text-primary"
      >
        Leaderboards
      </NavLink>
      <NavLink
        to="/ranks"
        className="border-b-2 border-transparent py-4 text-sm text-muted-foreground hover:text-foreground aria-[current=page]:border-primary aria-[current=page]:text-primary"
      >
        Rank guide
      </NavLink>
    </nav>
  )
}
