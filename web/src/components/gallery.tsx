import { SectionLabel } from "@/components/battles"
import { HudCorners } from "@/components/footage"
import { Reveal } from "@/components/reveal"

const SHOTS = [
  ["battle", "A firefight around a Coalition trench line"],
  ["river_bridge", "A bridge over the river, by a village"],
  ["sling_load", "A helicopter carrying a Humvee"],
] as const

export function Gallery() {
  return (
    <section id="screenshots" className="mx-auto max-w-6xl scroll-mt-16 px-4 py-24 sm:px-6">
      <Reveal>
        <SectionLabel>Screenshots</SectionLabel>
        <h2 className="mt-3 font-display text-5xl leading-[0.95] font-extrabold uppercase sm:text-6xl">
          A battlefield worth <span className="text-primary">a closer look.</span>
        </h2>
        <p className="mt-5 max-w-2xl text-base leading-relaxed text-muted-foreground">
          Trench lines, river crossings and reinforcements arriving by air. Get a closer look at the ground you’ll fight
          for.
        </p>
      </Reveal>
      <div className="mt-12 grid gap-4 sm:grid-cols-2">
        {SHOTS.map(([file, caption], i) => (
          <Reveal key={file} from="signal" className={i === 0 ? "sm:col-span-2" : ""}>
            <figure className="group">
              <div className="relative overflow-hidden ring-1 ring-white/10">
                <img
                  src={`/shots/${file}.jpg`}
                  alt={caption}
                  loading="lazy"
                  className="aspect-video w-full object-cover transition-transform duration-700 ease-out group-hover:scale-105"
                  width={1600}
                  height={900}
                />
                <div className="opacity-0 transition-opacity duration-300 group-hover:opacity-100">
                  <HudCorners inset="0.5rem" />
                </div>
              </div>
              <figcaption className="mt-2 text-xs text-muted-foreground">{caption}</figcaption>
            </figure>
          </Reveal>
        ))}
      </div>
    </section>
  )
}
