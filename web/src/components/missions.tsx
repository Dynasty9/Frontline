import { SectionLabel } from "@/components/battles"
import { HudCorners } from "@/components/footage"
import { Reveal } from "@/components/reveal"
import { type Mission, MISSIONS } from "@/lib/intel"
import { cn } from "@/lib/utils"

// the first mission gets the big tile; the rest fill in round it
const SPANS = [
  "lg:col-span-4 lg:row-span-2 min-h-[22rem] lg:min-h-[34rem]",
  "lg:col-span-2 min-h-[16.5rem]",
  "lg:col-span-2 min-h-[16.5rem]",
  "lg:col-span-3 min-h-[18rem]",
  "lg:col-span-3 min-h-[18rem]",
]

export function Missions() {
  return (
    <section id="missions" className="scroll-mt-16 border-y border-white/10 bg-card/40">
      <div className="mx-auto max-w-6xl px-4 py-24 sm:px-6">
        <Reveal className="flex flex-wrap items-end justify-between gap-6">
          <div>
            <SectionLabel>Missions</SectionLabel>
            <h2 className="mt-3 font-display text-5xl leading-[0.95] font-extrabold uppercase sm:text-6xl">
              Five operations. <span className="text-primary">Zero margin.</span>
            </h2>
          </div>
          <p className="max-w-sm text-sm leading-relaxed text-muted-foreground">
            Short, hand-built operations with objectives, radio traffic and a twist, each built around something the
            game does well. Play them alone, or bring a friend: every one works in co-op.
          </p>
        </Reveal>

        <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-6">
          {MISSIONS.map((m, i) => (
            <Reveal key={m.key} from="zoom" delay={i * 80} className={cn("flex", SPANS[i], i === 0 && "sm:col-span-2")}>
              <MissionCard m={m} n={i + 1} big={i === 0} />
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  )
}

function MissionCard({ m, n, big }: { m: Mission; n: number; big: boolean }) {
  return (
    <article className="group sweep relative isolate flex w-full flex-col justify-end overflow-hidden bg-black p-5 ring-1 ring-white/10 transition-shadow hover:ring-primary/50 sm:p-6">
      <img
        src={`/media/m-${m.key}.jpg`}
        alt=""
        loading="lazy"
        className="absolute inset-0 -z-20 size-full object-cover transition-transform duration-[1.4s] ease-out group-hover:scale-110"
      />
      <div className="absolute inset-0 -z-10 bg-gradient-to-t from-black via-black/55 to-black/5" />
      <div className="scanlines pointer-events-none absolute inset-0 -z-10 opacity-60" />
      <div className="opacity-0 transition-opacity duration-300 group-hover:opacity-100">
        <HudCorners inset="0.6rem" />
      </div>

      <div className="absolute top-4 left-5 flex items-center gap-2 font-mono text-[10px] tracking-[0.2em] text-cream/85 uppercase sm:left-6">
        <span className="bg-primary px-1.5 py-0.5 font-bold text-primary-foreground">
          Op {String(n).padStart(2, "0")}
        </span>
        {m.time}
      </div>

      <p className="text-[11px] font-bold tracking-[0.22em] text-primary uppercase">{m.op}</p>
      <h3
        className={cn(
          "mt-1 font-display leading-none font-extrabold uppercase",
          big ? "text-5xl sm:text-7xl" : "text-4xl"
        )}
      >
        {m.title}
      </h3>
      <p className={cn("mt-3 leading-relaxed text-cream/85", big ? "max-w-lg text-base" : "text-sm")}>{m.blurb}</p>
      <p className="mt-3 max-h-0 overflow-hidden text-xs text-muted-foreground opacity-0 transition-all duration-500 group-hover:max-h-12 group-hover:opacity-100">
        <span className="font-bold tracking-wider text-cream/70 uppercase">Force</span> · {m.force}
      </p>
    </article>
  )
}
