import { ArrowUpRightIcon } from "@phosphor-icons/react"
import { useEffect, useRef, useState } from "react"
import { useSearchParams } from "react-router"
import { ModelPreview } from "@/components/model-preview"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { useViewer } from "@/hooks/use-viewer"
import type { Entry, Fact, Section } from "@/lib/manual"
import { cn } from "@/lib/utils"

const SIDE_FILTERS = [
  [-1, "All sides"],
  [0, "Coalition"],
  [1, "Rebels"],
] as const

/** Which entries a page is showing: by kind, by side, and by what's typed in the search. */
type Filters = { section: string; group: string; side: number; query: string }

/**
 * One chapter of the Field Manual: every entry of its kind in a list you can
 * filter and search, and the chosen one with its 3D model, what it is and its
 * figures. The choice is in the address (?entry=), so a link opens on it.
 */
export function Catalogue({ section }: { section: Section }) {
  const [search, setSearch] = useSearchParams()
  const fresh: Filters = { section: section.key, group: "All", side: -1, query: "" }
  const [kept, setFilters] = useState(fresh)
  // a new chapter starts unfiltered (the page stays, so the viewer stays loaded)
  const filters = kept.section === section.key ? kept : fresh
  const set = (change: Partial<Filters>) => setFilters({ ...filters, ...change })
  const viewer = useViewer()
  const list = useRef<HTMLUListElement>(null)
  const detail = useRef<HTMLElement>(null)

  const words = filters.query.trim().toLowerCase()
  const shown = section.entries.filter(
    (e) =>
      (filters.group === "All" || e.group === filters.group) &&
      (filters.side < 0 || e.team === filters.side || e.team < 0) &&
      `${e.name} ${e.side} ${e.kind} ${e.group} ${e.description}`.toLowerCase().includes(words)
  )
  const asked = search.get("entry")
  const selected =
    shown.find((e) => e.id === asked) ?? shown[0] ?? section.entries.find((e) => e.id === asked) ?? section.entries[0]
  const select = (id: string) => {
    setSearch(
      (now) => {
        const next = new URLSearchParams(now)
        next.set("entry", id)
        return next
      },
      { replace: true, preventScrollReset: true }
    )
    // on a phone the details are under the list: take the visitor to them
    if (window.matchMedia("(max-width: 1023px)").matches) detail.current?.scrollIntoView({ block: "start" })
  }
  const models = section.entries.some((e) => e.model)

  // a link to an entry (?entry=) opens with it in sight in the list
  useEffect(() => {
    const ul = list.current
    const item = ul?.querySelector<HTMLElement>("[aria-pressed=true]")
    if (ul && item) ul.scrollTop = item.offsetTop - ul.clientHeight / 3
    // only when the page opens on a chapter, not as the visitor picks along the list
    // oxlint-disable-next-line react/exhaustive-effect-dependencies
  }, [section.key])

  return (
    <>
      <div className="mt-9 flex flex-wrap items-center justify-between gap-4 border-y py-4">
        <fieldset className="flex flex-wrap gap-2">
          <legend className="sr-only">Kind</legend>
          {["All", ...section.groups].map((label) => (
            <Button
              key={label}
              variant={filters.group === label ? "default" : "ghost"}
              aria-pressed={filters.group === label}
              onClick={() => set({ group: label })}
              className="min-h-11"
            >
              {label}
            </Button>
          ))}
        </fieldset>
        <fieldset className="flex border">
          <legend className="sr-only">Side</legend>
          {SIDE_FILTERS.map(([team, label]) => (
            <button
              key={team}
              type="button"
              aria-pressed={filters.side === team}
              onClick={() => set({ side: team })}
              className="inline-flex min-h-11 items-center gap-2 px-4 text-xs font-semibold tracking-[0.12em] text-muted-foreground uppercase transition-colors hover:text-foreground aria-pressed:bg-primary aria-pressed:text-primary-foreground"
            >
              <SideMark team={team} />
              {label}
            </button>
          ))}
        </fieldset>
      </div>

      <div className="mt-8 grid items-start gap-8 lg:grid-cols-[minmax(0,0.8fr)_minmax(0,1.6fr)]">
        <div>
          <div className="flex items-baseline justify-between gap-3">
            <label htmlFor="manual-search" className="font-mono text-xs tracking-widest uppercase">
              {section.title}
            </label>
            <output className="font-mono text-xs text-muted-foreground">
              {shown.length} / {section.entries.length}
            </output>
          </div>
          <Input
            id="manual-search"
            type="search"
            value={filters.query}
            onChange={(e) => set({ query: e.target.value })}
            placeholder={`Search ${section.noun[1]}…`}
            className="mt-3 mb-4 min-h-11 bg-background/60 text-base"
          />
          <ul
            ref={list}
            aria-label={section.title}
            className="relative max-h-72 overflow-y-auto border-t lg:max-h-[640px]"
          >
            {shown.map((e) => (
              <li key={e.id} className="border-b">
                <button
                  type="button"
                  aria-pressed={selected.id === e.id}
                  onClick={() => select(e.id)}
                  className="group flex w-full items-center gap-3 border-l-2 border-transparent px-4 py-3.5 text-left transition-colors hover:bg-foreground/5 focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-primary aria-pressed:border-primary aria-pressed:bg-primary/5"
                >
                  <SideMark team={e.team} />
                  <span className="min-w-0 flex-1">
                    <span className="block font-display text-xl leading-tight font-bold group-aria-pressed:text-primary">
                      {e.name}
                    </span>
                    <span className="mt-0.5 block truncate text-xs text-muted-foreground">
                      {e.side} · {e.kind}
                    </span>
                  </span>
                  <ArrowUpRightIcon
                    aria-hidden="true"
                    className="size-4 shrink-0 text-muted-foreground group-aria-pressed:text-primary"
                  />
                </button>
              </li>
            ))}
          </ul>
          {shown.length === 0 && (
            <div className="py-8">
              <h2 className="font-display text-2xl font-bold">Nothing found</h2>
              <p className="mt-2 text-sm text-muted-foreground">Try another name, side or kind.</p>
              <Button className="mt-4" variant="outline" onClick={() => setFilters(fresh)}>
                Clear filters
              </Button>
            </div>
          )}
        </div>

        <article
          ref={detail}
          hidden={shown.length === 0}
          aria-labelledby="manual-entry"
          className="min-w-0 scroll-mt-20 lg:sticky lg:top-24"
        >
          <p className="font-mono text-[10px] tracking-[0.16em] text-primary uppercase">
            {selected.side} / {selected.status ?? selected.group}
          </p>
          <h2
            id="manual-entry"
            className="mt-2 mb-5 font-display text-4xl leading-none font-bold uppercase sm:text-5xl"
          >
            {selected.name}
          </h2>
          {/* kept while the visitor moves between entries, so the viewer loads once */}
          {models && (
            <div hidden={!selected.model}>
              <ModelPreview entry={selected} available={viewer} />
            </div>
          )}
          <div className="pt-6">
            <p className="font-mono text-xs tracking-wider text-primary uppercase">{selected.kind}</p>
            {selected.description && (
              <p className="mt-3 max-w-2xl text-base leading-relaxed text-muted-foreground">{selected.description}</p>
            )}
            <Figures facts={selected.facts} />
            {selected.notes.length > 0 && (
              <ul className="mt-5 space-y-1.5 text-xs leading-relaxed text-muted-foreground">
                {selected.notes.map((n) => (
                  <li key={n} className="flex gap-2">
                    <span aria-hidden="true" className="mt-[0.45rem] h-px w-3 shrink-0 bg-primary" />
                    {n}
                  </li>
                ))}
              </ul>
            )}
            <Availability entry={selected} />
          </div>
        </article>
      </div>
    </>
  )
}

/** An entry's figures, as the game's manual lays them out: the label, a counted bar against the rest of its kind, the value. */
function Figures({ facts }: { facts: Fact[] }) {
  if (!facts.length) return null
  return (
    <dl className="mt-6 border-t">
      {facts.map((f) => (
        <div
          key={f.label}
          className="grid grid-cols-[minmax(0,9rem)_minmax(0,1fr)] items-baseline gap-x-4 border-b py-2.5 sm:grid-cols-[11rem_minmax(0,1fr)]"
        >
          <dt className="text-xs tracking-wider text-muted-foreground uppercase">{f.label}</dt>
          <dd className="flex min-w-0 items-center gap-4">
            {f.frac !== undefined && <Steps frac={f.frac} />}
            <span className="min-w-0 font-mono text-sm break-words">{f.value}</span>
          </dd>
        </div>
      ))}
    </dl>
  )
}

/** How it compares with the rest of its kind: as many steps lit as its share of the biggest (never none, if it has any). */
function Steps({ frac }: { frac: number }) {
  const n = 10
  const lit = frac > 0 ? Math.max(1, Math.ceil(frac * n - 0.25)) : 0
  return (
    <span aria-hidden="true" className="hidden shrink-0 gap-0.5 sm:flex">
      {Array.from({ length: n }, (_, i) => (
        <span key={i} className={cn("h-2.5 w-1.5", i < lit ? "bg-foreground/80" : "bg-foreground/15")} />
      ))}
    </span>
  )
}

/** Whose something is: a small square in its side's colour, halved between the two when both sides have it. */
export function SideMark({ team, className }: { team: number; className?: string }) {
  return (
    <span aria-hidden="true" className={cn("inline-flex size-2 shrink-0", className)}>
      {team <= 0 ? <span className={cn("h-full bg-coalition", team < 0 ? "w-1/2" : "w-full")} /> : null}
      {team === 1 || team < 0 ? <span className={cn("h-full bg-rebels", team < 0 ? "w-1/2" : "w-full")} /> : null}
    </span>
  )
}

/** Where a vehicle comes from, in a sentence. */
function Availability({ entry }: { entry: Entry }) {
  if (!entry.status) return null
  return (
    <p className="mt-5 border-t pt-4 text-xs leading-relaxed text-muted-foreground">
      {entry.status === "Field Manual only"
        ? "Reference vehicle from the Field Manual. This is not a unit you can order."
        : entry.status === "Air support"
          ? "Called in as air support. Availability depends on your side."
          : entry.status === "Automatic supply"
            ? "Runs automatically as part of your supply network."
            : "Built in battle. Availability depends on your side and research."}
    </p>
  )
}
