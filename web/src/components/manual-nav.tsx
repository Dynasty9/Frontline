import { NavLink } from "react-router"
import { SECTIONS } from "@/lib/manual"

const LINK =
  "shrink-0 border-b-2 border-transparent py-4 text-sm text-muted-foreground hover:text-foreground aria-[current=page]:border-primary aria-[current=page]:text-primary"

/** The Field Manual's chapters: how the game works, then a page for each kind of thing in it. */
export function ManualNav() {
  return (
    <nav aria-label="Field Manual" className="border-b">
      <div className="mx-auto flex max-w-6xl [scrollbar-width:none] gap-6 overflow-x-auto px-4 sm:px-6">
        <NavLink to="/manual" end className={LINK}>
          Overview
        </NavLink>
        {SECTIONS.map((s) => (
          <NavLink key={s.key} to={`/manual/${s.key}`} className={LINK}>
            {s.title}
          </NavLink>
        ))}
      </div>
    </nav>
  )
}
