import { useEffect, useLayoutEffect, useRef, useState } from "react"
import { NavLink, useLocation } from "react-router"
import { SECTIONS } from "@/lib/manual"

const LINK =
  "shrink-0 border-b-2 border-transparent py-4 text-sm text-muted-foreground hover:text-foreground aria-[current=page]:border-primary aria-[current=page]:text-primary"

/** The Field Manual's chapters: how the game works, then a page for each kind of thing in it. */
export function ManualNav() {
  const strip = useRef<HTMLDivElement>(null)
  const { pathname } = useLocation()
  // on a narrow screen the chapters scroll sideways: the edge with more past it fades out, so it's plain there are more
  const [more, setMore] = useState({ before: false, after: false })

  useEffect(() => {
    const el = strip.current
    if (!el) return
    const measure = () => {
      const before = el.scrollLeft > 2
      const after = el.scrollLeft + el.clientWidth < el.scrollWidth - 2
      setMore((m) => (m.before === before && m.after === after ? m : { before, after }))
    }
    measure()
    el.addEventListener("scroll", measure, { passive: true })
    const observer = new ResizeObserver(measure)
    observer.observe(el)
    return () => {
      el.removeEventListener("scroll", measure)
      observer.disconnect()
    }
  }, [])

  // the chapter you're on is in sight, not off past the edge
  useLayoutEffect(() => {
    const el = strip.current
    const on = el?.querySelector<HTMLElement>("[aria-current=page]")
    if (!el || !on) return
    if (on.offsetLeft < el.scrollLeft || on.offsetLeft + on.offsetWidth > el.scrollLeft + el.clientWidth)
      el.scrollLeft = on.offsetLeft - 16
    // the current tab changes with the address, which the effect doesn't read itself
    // oxlint-disable-next-line react/exhaustive-effect-dependencies
  }, [pathname])

  const fade = `linear-gradient(to right, ${more.before ? "transparent, black 2.5rem" : "black"}, ${more.after ? "black calc(100% - 2.5rem), transparent" : "black"})`
  return (
    <nav aria-label="Field Manual" className="border-b">
      <div
        ref={strip}
        style={{ maskImage: fade }}
        className="relative mx-auto flex max-w-6xl [scrollbar-width:none] gap-6 overflow-x-auto px-4 sm:px-6"
      >
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
