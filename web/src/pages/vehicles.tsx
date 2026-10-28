import { useState } from "react"
import { SectionLabel } from "@/components/battles"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { usePageTitle } from "@/hooks/use-page-title"
import { VEHICLES } from "@/lib/vehicles"

export default function VehiclesPage() {
  usePageTitle("Vehicles")
  const [query, setQuery] = useState("")
  const [availability, setAvailability] = useState("All")
  const shown = VEHICLES.filter(
    (v) =>
      (availability === "All" || v.availability.startsWith(availability)) &&
      `${v.name} ${v.faction} ${v.role} ${v.description}`.toLowerCase().includes(query.trim().toLowerCase())
  )
  return (
    <div className="topo">
      <section className="mx-auto max-w-6xl px-4 pt-14 pb-24 sm:px-6">
        <SectionLabel>Field Manual / Vehicles</SectionLabel>
        <h1 className="mt-3 font-display text-5xl leading-none font-extrabold uppercase sm:text-6xl">
          Know your <span className="text-primary">motor pool.</span>
        </h1>
        <p className="mt-5 max-w-2xl leading-relaxed text-muted-foreground">
          Scout cars, heavy armour, helicopters and river craft. Explore the vehicles you can field, the aircraft you
          can call in, and the rest of the game’s Field Manual.
        </p>
        <p className="mt-3 max-w-2xl text-sm text-muted-foreground">
          Buildable vehicles depend on your side and research. Field Manual only entries are reference vehicles, not
          units you can order.
        </p>
        <div className="mt-10 border-y py-5">
          <label htmlFor="vehicle-search" className="block text-sm font-semibold">
            Search vehicles
          </label>
          <Input
            id="vehicle-search"
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Name, faction or role…"
            className="mt-2 min-h-11 max-w-lg text-base"
          />
          <fieldset className="mt-4 flex flex-wrap gap-2">
            <legend className="sr-only">Vehicle availability</legend>
            {["All", "Buildable", "Air support", "Automatic supply", "Field Manual only"].map((label) => (
              <Button
                key={label}
                variant={availability === label ? "default" : "outline"}
                aria-pressed={availability === label}
                onClick={() => setAvailability(label)}
                className="min-h-11"
              >
                {label}
              </Button>
            ))}
          </fieldset>
        </div>
        <output className="mt-5 block font-mono text-xs text-muted-foreground">
          {shown.length} of {VEHICLES.length} vehicles
        </output>
        <ul className="mt-4 grid gap-x-10 sm:grid-cols-2">
          {shown.map((v) => (
            <li key={v.id} className="border-b py-6">
              <p className="font-mono text-xs text-primary">
                {v.faction} · {v.availability}
              </p>
              <h2 className="mt-2 font-display text-2xl font-bold">{v.name}</h2>
              <p className="mt-1 text-sm font-medium capitalize">{v.role}</p>
              <p className="mt-3 text-sm leading-relaxed text-muted-foreground">{v.description}</p>
            </li>
          ))}
        </ul>
        {shown.length === 0 && (
          <div className="py-12">
            <h2 className="text-xl font-semibold">No vehicles found</h2>
            <p className="mt-2 text-muted-foreground">Try another name, faction or role, or clear the filters.</p>
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
      </section>
    </div>
  )
}
