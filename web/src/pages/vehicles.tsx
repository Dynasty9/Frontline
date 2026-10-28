import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { ArrowUpRightIcon } from "@phosphor-icons/react"
import { SectionLabel } from "@/components/battles"
import { VehiclePreview } from "@/components/vehicle-preview"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { usePageTitle } from "@/hooks/use-page-title"
import { VEHICLES } from "@/lib/vehicles"

export default function VehiclesPage() {
  usePageTitle("Vehicles")
  const [query, setQuery] = useState("")
  const [availability, setAvailability] = useState("All")
  const [selectedId, setSelectedId] = useState(VEHICLES[0].id)
  const viewer = useQuery({
    queryKey: ["viewer-build"],
    queryFn: async ({ signal }) => {
      const response = await fetch("/game/viewer.json", { signal })
      return response.ok ? (response.json() as Promise<{ manual?: number }>) : null
    },
    retry: false,
  })
  const shown = VEHICLES.filter(
    (v) =>
      (availability === "All" || v.availability.startsWith(availability)) &&
      `${v.name} ${v.faction} ${v.role} ${v.description}`.toLowerCase().includes(query.trim().toLowerCase())
  )
  const selected = shown.find((v) => v.id === selectedId) ?? shown[0]
  return (
    <div className="topo">
      <section className="mx-auto max-w-6xl px-4 pt-12 pb-24 sm:px-6">
        <SectionLabel>Field Manual / Vehicles</SectionLabel>
        <div className="mt-4 flex flex-wrap items-end justify-between gap-6">
          <h1 className="max-w-2xl font-display text-5xl leading-[0.95] font-extrabold uppercase sm:text-7xl">
            Know your
            <br />
            <span className="text-primary">motor pool.</span>
          </h1>
          <p className="max-w-xs text-sm leading-relaxed text-muted-foreground">
            From the first scout car to the heaviest armour. Explore the roster. Turn each vehicle over. Find its place
            in your force.
          </p>
        </div>
        <div className="mt-9 border-y py-4">
          <fieldset className="flex flex-wrap gap-2">
            <legend className="sr-only">Vehicle availability</legend>
            {["All", "Buildable", "Air support", "Automatic supply", "Field Manual only"].map((label) => (
              <Button
                key={label}
                variant={availability === label ? "default" : "ghost"}
                aria-pressed={availability === label}
                onClick={() => setAvailability(label)}
                className="min-h-11"
              >
                {label}
              </Button>
            ))}
          </fieldset>
        </div>
        <div className="mt-8 grid items-start gap-8 lg:grid-cols-[minmax(0,0.8fr)_minmax(0,1.6fr)]">
          <div>
            <div className="flex items-baseline justify-between gap-3">
              <label htmlFor="vehicle-search" className="font-mono text-xs tracking-widest uppercase">
                Vehicle roster
              </label>
              <output className="font-mono text-xs text-muted-foreground">
                {shown.length} / {VEHICLES.length}
              </output>
            </div>
            <Input
              id="vehicle-search"
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search name, faction or role…"
              className="mt-3 mb-4 min-h-11 text-base"
            />
            <ul aria-label="Vehicles" className="max-h-64 overflow-y-auto border-t lg:max-h-[620px]">
              {shown.map((v) => (
                <li key={v.id} className="border-b">
                  <button
                    type="button"
                    aria-pressed={selected?.id === v.id}
                    onClick={() => setSelectedId(v.id)}
                    className="group flex w-full items-center gap-3 border-l-2 border-transparent px-4 py-4 text-left transition-colors hover:bg-foreground/5 focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-primary aria-pressed:border-primary aria-pressed:bg-primary/5"
                  >
                    <span className="min-w-0 flex-1">
                      <span className="block font-display text-xl leading-tight font-bold group-aria-pressed:text-primary">
                        {v.name}
                      </span>
                      <span className="mt-1 block text-xs text-muted-foreground">
                        {v.faction} · {v.role}
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
                <h2 className="font-display text-2xl font-bold">No vehicles found</h2>
                <p className="mt-2 text-sm text-muted-foreground">Try another name, faction or role.</p>
                <Button
                  className="mt-4"
                  variant="outline"
                  onClick={() => {
                    setQuery("")
                    setAvailability("All")
                  }}
                >
                  Clear filters
                </Button>
              </div>
            )}
          </div>
          {selected && (
            <article aria-label="Selected vehicle" className="min-w-0 lg:sticky lg:top-24">
              <div className="mb-5 flex items-start justify-between gap-4">
                <div>
                  <p className="font-mono text-[10px] tracking-[0.16em] text-primary uppercase">
                    {selected.faction} / {selected.availability}
                  </p>
                  <h2 className="mt-2 font-display text-4xl leading-none font-bold uppercase sm:text-5xl">
                    {selected.name}
                  </h2>
                </div>
              </div>
              <VehiclePreview
                key={selected.id}
                vehicle={selected}
                available={viewer.isPending ? null : viewer.data?.manual === 1}
              />
              <div className="pt-6">
                <p className="font-mono text-xs tracking-wider text-primary uppercase">{selected.role}</p>
                <p className="mt-3 text-base leading-relaxed text-muted-foreground">{selected.description}</p>
                <p className="mt-5 border-t pt-4 text-xs leading-relaxed text-muted-foreground">
                  {selected.availability === "Field Manual only"
                    ? "Reference vehicle from the Field Manual. This is not a unit you can order."
                    : selected.availability === "Air support"
                      ? "Called in as air support. Availability depends on your side."
                      : selected.availability === "Automatic supply"
                        ? "Runs automatically as part of your supply network."
                        : "Built in battle. Availability depends on your side and research."}
                </p>
              </div>
            </article>
          )}
        </div>
      </section>
    </div>
  )
}
