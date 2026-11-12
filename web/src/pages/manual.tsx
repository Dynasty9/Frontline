import { ArrowRightIcon } from "@phosphor-icons/react"
import type { ReactNode } from "react"
import { Link } from "react-router"
import { SectionLabel } from "@/components/battles"
import { SideMark } from "@/components/catalogue"
import { HudCorners } from "@/components/footage"
import { ManualNav } from "@/components/manual-nav"
import { Reveal } from "@/components/reveal"
import { usePageTitle } from "@/hooks/use-page-title"
import { LOGISTICS, SECTIONS, TALLY } from "@/lib/manual"

const n = (x: number) => x.toLocaleString("en-GB")
const SIDES = ["Coalition", "Rebels"]

type Chapter = {
  code: string
  title: [string, string]
  body: ReactNode
  /** the figures, as codes along the bottom */
  figures: string[]
  still: { src: string; caption: string }
  more: { to: string; label: string }
}

/**
 * How the game fights, chapter by chapter, each with the figures from the
 * game's tables and a still from the game, and a way into the catalogue
 * that goes with it. What's here is true of the game: keep it so.
 */
const CHAPTERS: Chapter[] = [
  {
    code: "01 / Command",
    title: ["Orders,", "not clicks."],
    body: (
      <>
        You command squads, not soldiers. Right-click the ground and coloured dots show where each man will stand: green
        is good cover, yellow only hides him, red is open ground. Attack, and the squad advances in bounds, one team
        covering the other. Hold, and it spreads into the best cover there and stays.
      </>
    ),
    figures: [`${TALLY.squads} squads and teams`, `${TALLY.soldiers} kinds of soldier`, `${TALLY.weapons} weapons`],
    still: { src: "/media/m-bridgehead.jpg", caption: "Bridgehead · Grid C6" },
    more: { to: "/manual/infantry", label: "Infantry" },
  },
  {
    code: "02 / Drills",
    title: ["They know", "the drill."],
    body: (
      <>
        Every man runs his own reflexes. When a grenade lands he throws it back, kicks it away, dives clear or, when
        it's too late, smothers it. Squads react to contact, clear houses room by room, lie in wait and spring ambushes,
        and break contact when the fight turns. Fire they can't answer wears them down: steady, shaken, breaking,
        routed.
      </>
    ),
    figures: ["React to contact", "Bounding overwatch", "Clear the house", "Throw it back", "Break contact"],
    still: { src: "/media/infantry.jpg", caption: "Infantry · Grid E3" },
    more: { to: "/manual/infantry?entry=rifle_squad", label: "Squads" },
  },
  {
    code: "03 / Two sides",
    title: ["Two armies.", "Two ways to fight."],
    body: (
      <>
        The Coalition fights with armour, helicopters and air power on call. The Rebels fight with what they have:
        technicals, RPGs, FPV drones, barricades, tunnels and rocket barrages. Both build, dig in and fight for the
        towns.
      </>
    ),
    figures: [],
    still: { src: "/media/m-ambush.jpg", caption: "Ambush Alley · Rebels" },
    more: { to: "/manual/vehicles", label: "Vehicles" },
  },
  {
    code: "04 / Combined arms",
    title: ["Bring the", "heavy hitters."],
    body: (
      <>
        {n(TALLY.vehicles)} vehicles, from quad bikes to main battle tanks, gunships and patrol boats. Crews fight on
        their own: they pop smoke when a missile is fired at them, turn their front armour to the threat, wait for the
        infantry before driving into a town and pull back to be patched up. Research brings heavier tiers to the Factory
        and the Helipad.
      </>
    ),
    figures: [`${TALLY.buildable} to build`, "3 tiers", "Smoke & back out", "Front armour to the threat"],
    still: { src: "/shots/armour.jpg", caption: "Armour · Grid B4" },
    more: { to: "/manual/vehicles", label: "Vehicles" },
  },
  {
    code: "05 / Build",
    title: ["Build it.", "Dig in."],
    body: (
      <>
        Engineers put up the base. Each FOB extends your reach, lays a supply road and raises your unit cap by{" "}
        {LOGISTICS.capPerFob}; the Barracks trains squads, the Factory builds vehicles, the Helipad helicopters and the
        Dock boats. Out in the field they dig trenches that deepen as the crew works, lay wire and mines, and raise
        sandbags, bunkers, MG nests and watchtowers.
      </>
    ),
    figures: [
      `${TALLY.bases} base buildings`,
      `${TALLY.defences} field defences`,
      `+${LOGISTICS.capPerFob} units a FOB`,
    ],
    still: { src: "/media/m-skyhook.jpg", caption: "Helipad · Sky Hook" },
    more: { to: "/manual/buildings", label: "Buildings" },
  },
  {
    code: "06 / Supply",
    title: ["Supply", "decides it."],
    body: (
      <>
        Everything costs supply, and you start with {LOGISTICS.startSupply}. Trucks drive it down the road from your
        depot to the FOBs; the town and every village pay it to whoever holds them, and their own lorries truck it in.
        Cut a supply road and the front starves: ambush the convoy, or fly supply over it by helicopter.
      </>
    ),
    figures: [
      `Start ${LOGISTICS.startSupply}`,
      `Truck ${LOGISTICS.truckLoad.join(" / ")}`,
      `Village ${LOGISTICS.townYield[0]} a min`,
      `Town ${LOGISTICS.townYield[1]} a min`,
    ],
    still: { src: "/shots/river_bridge.jpg", caption: "River crossing · Village" },
    more: { to: "/manual/buildings?entry=fob", label: "The FOB" },
  },
  {
    code: "07 / Fire support",
    title: ["Call it in.", "Danger close."],
    body: (
      <>
        {TALLY.support} kinds of off-map support, each with its own cooldown: strike jets, gun runs, orbiting gunships,
        armed drones, artillery, rocket barrages and mortars. Recon flights light up the ground they pass over; ground
        your side can't see is drawn darker. Shellfire sets woods, hedgerows and roofs alight, and the wind carries it.
      </>
    ),
    figures: [`${TALLY.support} fire missions`, "Recon flights", "Fire spreads with the wind"],
    still: { src: "/media/reel.jpg", caption: "Fire mission · Grid G4" },
    more: { to: "/manual/support", label: "Fire support" },
  },
  {
    code: "08 / The battlefield",
    title: ["Every map,", "a new war."],
    body: (
      <>
        Seeded battlefields 1,024, 2,048 or 3,072 metres square: a town in the middle, villages on the country roads,
        rivers and bridges, mountains, and the sea. Boats land raiding parties on the beach; helicopters carry vehicles
        forward on a cable. Fight it alone against the AI, with friends against it, or against each other online.
      </>
    ),
    figures: ["1,024 / 2,048 / 3,072 m", "Sea & river", "Co-op & versus"],
    still: { src: "/shots/patrol_ship.jpg", caption: "Naval · Patrol ship" },
    more: { to: "/play", label: "Play" },
  },
]

/** The Field Manual's front page: how the game fights, and the way into every catalogue. */
export default function ManualPage() {
  usePageTitle("Field Manual")
  return (
    <div>
      <ManualNav />
      <section className="mx-auto max-w-6xl px-4 pt-12 pb-16 sm:px-6">
        <SectionLabel>Field Manual</SectionLabel>
        <div className="mt-4 flex flex-wrap items-end justify-between gap-6">
          <h1 className="max-w-3xl font-display text-5xl leading-[0.95] font-extrabold uppercase sm:text-7xl">
            How Frontline <br />
            <span className="text-primary">fights.</span>
          </h1>
          <p className="max-w-sm text-sm leading-relaxed text-muted-foreground">
            Every soldier, squad, weapon, vehicle, building, fire mission and upgrade in the game, with its own numbers
            and its 3D model. Read how the game fights, or open a chapter.
          </p>
        </div>

        <nav aria-label="Chapters" className="mt-12 grid gap-px border bg-border sm:grid-cols-2 lg:grid-cols-5">
          {SECTIONS.map((s, i) => (
            <Link
              key={s.key}
              to={`/manual/${s.key}`}
              className="group relative flex flex-col bg-background/80 p-5 transition-colors hover:bg-background/40 focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-primary"
            >
              <span className="font-mono text-[10px] tracking-[0.18em] text-muted-foreground uppercase">
                FM 2-0{i + 1}
              </span>
              <span className="mt-3 font-display text-2xl leading-none font-bold uppercase group-hover:text-primary">
                {s.title}
              </span>
              <span className="mt-1 font-mono text-xs text-primary">
                {s.entries.length} {s.entries.length === 1 ? s.noun[0] : s.noun[1]}
              </span>
              <span className="mt-3 flex-1 text-xs leading-relaxed text-muted-foreground">{s.groups.join(" · ")}</span>
              <ArrowRightIcon
                aria-hidden="true"
                className="mt-4 size-4 text-muted-foreground transition-transform group-hover:translate-x-1 group-hover:text-primary"
              />
            </Link>
          ))}
        </nav>
      </section>

      <div className="mx-auto max-w-6xl px-4 pb-24 sm:px-6">
        {CHAPTERS.map((c, i) => (
          <article
            key={c.code}
            aria-labelledby={`chapter-${i}`}
            className="grid items-center gap-8 border-t py-14 md:grid-cols-2 md:gap-14"
          >
            <Reveal from="signal" className={i % 2 ? "md:order-2" : undefined}>
              <figure className="relative">
                <img
                  src={c.still.src}
                  alt=""
                  loading="lazy"
                  decoding="async"
                  className="aspect-video w-full object-cover ring-1 ring-white/10"
                />
                <HudCorners inset="0.6rem" className="size-4 border-primary/70" />
                <figcaption className="pointer-events-none absolute bottom-3 left-4 font-mono text-[10px] tracking-[0.18em] text-cream uppercase drop-shadow">
                  {c.still.caption}
                </figcaption>
              </figure>
            </Reveal>
            <Reveal from="type" delay={80}>
              <SectionLabel>{c.code}</SectionLabel>
              <h2
                id={`chapter-${i}`}
                className="mt-3 font-display text-4xl leading-none font-extrabold uppercase sm:text-5xl"
              >
                {c.title[0]} <br />
                <span className="text-primary">{c.title[1]}</span>
              </h2>
              <p className="mt-5 leading-relaxed text-muted-foreground">{c.body}</p>
              {c.code.startsWith("03") ? <Sides /> : <Codes figures={c.figures} />}
              <Link
                to={c.more.to}
                className="mt-6 inline-flex min-h-11 items-center gap-2 text-sm font-semibold text-foreground underline-offset-4 hover:text-primary hover:underline"
              >
                {c.more.label}
                <ArrowRightIcon aria-hidden="true" className="size-4" />
              </Link>
            </Reveal>
          </article>
        ))}
      </div>
    </div>
  )
}

function Codes({ figures }: { figures: string[] }) {
  return (
    <ul className="mt-6 flex flex-wrap gap-x-5 gap-y-2 border-y py-3 font-mono text-xs tracking-wide text-muted-foreground uppercase">
      {figures.map((f) => (
        <li key={f}>{f}</li>
      ))}
    </ul>
  )
}

/** What each side has to fight with, counted from the tables. */
function Sides() {
  const rows = [
    ["Squads to train", "squads"],
    ["Vehicles to build", "vehicles"],
    ["Fire missions", "support"],
    ["Buildings", "buildings"],
  ] as const
  return (
    <table className="mt-6 w-full border-y font-mono text-xs">
      <caption className="sr-only">Each side's forces</caption>
      <thead>
        <tr className="text-muted-foreground uppercase">
          <th scope="col" className="py-2 text-left font-normal">
            <span className="sr-only">Forces</span>
          </th>
          {SIDES.map((side, team) => (
            <th key={side} scope="col" className="py-2 text-right font-normal tracking-wider">
              <span className="inline-flex items-center gap-2">
                <SideMark team={team} />
                {side}
              </span>
            </th>
          ))}
        </tr>
      </thead>
      <tbody>
        {rows.map(([label, key]) => (
          <tr key={key} className="border-t">
            <th scope="row" className="py-2 text-left font-normal text-muted-foreground uppercase">
              {label}
            </th>
            {TALLY.perSide.map((side, team) => (
              <td key={team} className="py-2 text-right text-foreground">
                {side[key]}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  )
}
