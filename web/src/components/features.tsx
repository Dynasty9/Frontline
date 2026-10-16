import { SectionLabel } from "@/components/battles"
import { Clip } from "@/components/footage"
import { Reveal } from "@/components/reveal"
import { cn } from "@/lib/utils"

type Feature = {
  clip: string
  cam: string
  grid: string
  kicker: string
  title: string
  text: string
  tags: string[]
}

const FEATURES: Feature[] = [
  {
    clip: "infantry",
    cam: "Cam 02 · Infantry",
    grid: "C6",
    kicker: "Infantry",
    title: "Soldiers that think for themselves",
    text: "They take cover behind real walls and wrecks, keep their heads down under fire, drag the wounded to safety and throw enemy grenades back. You never have to tell a man where to stand.",
    tags: ["Cover", "Suppression", "Casualty drag", "Grenade throw-back"],
  },
  {
    clip: "squads",
    cam: "Cam 03 · Assault",
    grid: "E3",
    kicker: "Squads",
    title: "Squads that fight like squads",
    text: "Teams leapfrog forward under covering fire, clear houses room by room, set ambushes on the roads, and break and run when a fight goes badly. Give the order; they work out the drill.",
    tags: ["Bounding overwatch", "Room clearing", "Ambushes", "Morale"],
  },
  {
    clip: "armour",
    cam: "Cam 04 · Armour",
    grid: "B4",
    kicker: "Armour",
    title: "Armour that hits like a hammer",
    text: "Tanks pop smoke when a missile is fired at them. Infantry fighting vehicles drop their squads at the enemy's wire. Ninety-seven vehicles, from quad bikes and technicals to main battle tanks.",
    tags: ["Main battle tanks", "IFVs", "Tank destroyers", "Smoke"],
  },
  {
    clip: "fires",
    cam: "Cam 05 · Fire mission",
    grid: "G4",
    kicker: "Fire support",
    title: "Call it in",
    text: "155 mm artillery, rocket barrages, mortars, A-10 gun runs and an AC-130 on station. Shellfire sets woods, hedgerows, roofs and cars alight, and the fire spreads with the wind and drives men out of cover.",
    tags: ["Artillery", "Gun runs", "Gunships", "Spreading fire"],
  },
  {
    clip: "sea",
    cam: "Cam 06 · Naval",
    grid: "H5",
    kicker: "Sea and sky",
    title: "From the sea and the sky",
    text: "Boats land raiding parties on the beach under a patrol ship's guns. Helicopters carry vehicles to the front on a cable, and attack helicopters come in low from the sea.",
    tags: ["Patrol ships", "RHIB landings", "Sling loads", "Helicopters"],
  },
]

export function Features() {
  return (
    <section id="intel" className="relative mx-auto max-w-6xl scroll-mt-16 px-4 py-24 sm:px-6">
      <Reveal>
        <SectionLabel>The game</SectionLabel>
        <h2 className="mt-3 max-w-3xl font-display text-5xl leading-[0.95] font-extrabold uppercase sm:text-6xl">
          Give the order. <span className="text-primary">Watch them fight.</span>
        </h2>
        <p className="mt-5 max-w-2xl text-base leading-relaxed text-muted-foreground">
          You command squads, not soldiers. Every clip on this page was recorded in the game as it plays: no cutscenes,
          no mock-ups, no pre-rendered anything.
        </p>
      </Reveal>

      <div className="mt-20 space-y-28">
        {FEATURES.map((f, i) => (
          <FeatureRow key={f.clip} f={f} n={i + 1} flip={i % 2 === 1} />
        ))}
      </div>
    </section>
  )
}

function FeatureRow({ f, n, flip }: { f: Feature; n: number; flip: boolean }) {
  return (
    <article className="grid items-center gap-10 lg:grid-cols-12 lg:gap-14">
      <Reveal from={flip ? "right" : "left"} className={cn("lg:col-span-7", flip && "lg:order-2")}>
        <div className="relative">
          <div className="absolute -inset-3 -z-10 bg-[radial-gradient(ellipse_at_center,rgb(245_201_110/0.14),transparent_70%)] blur-2xl" />
          <Clip name={f.clip} label={f.cam} grid={f.grid} className="sweep aspect-video" />
        </div>
      </Reveal>
      <Reveal delay={120} className={cn("lg:col-span-5", flip && "lg:order-1")}>
        <div className="flex items-end gap-4">
          <span className="stencil text-7xl sm:text-8xl">{String(n).padStart(2, "0")}</span>
          <span className="mb-2 text-xs font-bold tracking-[0.25em] text-primary uppercase">{f.kicker}</span>
        </div>
        <h3 className="mt-4 font-display text-4xl leading-none font-extrabold uppercase sm:text-5xl">{f.title}</h3>
        <p className="mt-4 leading-relaxed text-muted-foreground">{f.text}</p>
        <ul className="mt-5 flex flex-wrap gap-2">
          {f.tags.map((t) => (
            <li
              key={t}
              className="border border-primary/30 bg-primary/5 px-2.5 py-1 text-[11px] font-bold tracking-[0.14em] text-primary/90 uppercase"
            >
              {t}
            </li>
          ))}
        </ul>
      </Reveal>
    </article>
  )
}
