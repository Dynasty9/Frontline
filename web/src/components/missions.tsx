import { useState } from "react"
import { SectionLabel } from "@/components/battles"
import { HudCorners } from "@/components/footage"
import { Reveal } from "@/components/reveal"
import { MISSIONS } from "@/lib/intel"
import { cn } from "@/lib/utils"

export function Missions() {
  const [selected, setSelected] = useState(0)
  const mission = MISSIONS[selected]
  return (
    <section id="missions" className="story scroll-mt-16 border-y bg-card/40">
      <div className="mx-auto max-w-6xl px-4 py-24 sm:px-6">
        <Reveal from="signal">
          <SectionLabel>03 / Your first operation</SectionLabel>
          <h2 className="mt-4 font-display text-5xl leading-none font-extrabold uppercase sm:text-7xl">
            A plan. A squad.
            <br />
            <span className="text-primary">Then contact.</span>
          </h2>
          <p className="mt-6 max-w-xl leading-relaxed text-muted-foreground">
            Seize a bridge before the counterattack. Slip into town after dark. Short, hand-built operations put your
            decisions to the test, with objectives and radio traffic as the fight unfolds.
          </p>
        </Reveal>
        <div className="mt-12 grid items-start gap-8 lg:grid-cols-[1fr_2fr]">
          <div aria-label="Choose an operation" className="border-t">
            {MISSIONS.map((m, i) => (
              <button
                key={m.key}
                type="button"
                aria-pressed={selected === i}
                aria-controls="operation-briefing"
                onClick={() => setSelected(i)}
                className={cn(
                  "flex min-h-16 w-full items-center gap-4 border-b px-3 py-4 text-left focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-primary",
                  selected === i
                    ? "border-primary bg-primary/10 text-primary"
                    : "text-muted-foreground hover:bg-secondary hover:text-foreground"
                )}
              >
                <span className="font-mono text-xs">{String(i + 1).padStart(2, "0")}</span>
                <span className="flex-1 font-display text-xl font-bold uppercase">{m.title}</span>
                <span aria-hidden="true">{selected === i ? "↗" : "+"}</span>
              </button>
            ))}
            <p className="mt-5 text-sm leading-relaxed text-muted-foreground">
              Every operation plays solo or in co-op. Bring a friend and share command.
            </p>
          </div>
          <div id="operation-briefing" aria-live="polite" aria-atomic="true">
            <article key={mission.key} className="operation-cut">
              <div className="relative">
                <img
                  src={`/media/m-${mission.key}.jpg`}
                  alt={`${mission.title} battlefield`}
                  loading="lazy"
                  width={1600}
                  height={900}
                  className="aspect-video w-full object-cover"
                />
                <HudCorners inset="0.75rem" />
              </div>
              <div className="mt-5 flex flex-wrap justify-between gap-2 font-mono text-xs tracking-wider text-primary uppercase">
                <p>{mission.op}</p>
                <p>{mission.time}</p>
              </div>
              <h3 className="mt-3 font-display text-4xl font-bold uppercase">{mission.title}</h3>
              <p className="mt-2 max-w-xl leading-relaxed text-muted-foreground">{mission.blurb}</p>
              <p className="mt-5 border-t pt-4 text-sm text-muted-foreground">
                <span className="font-mono text-xs text-foreground">YOUR FORCE / </span>
                {mission.force}
              </p>
            </article>
          </div>
        </div>
      </div>
    </section>
  )
}
