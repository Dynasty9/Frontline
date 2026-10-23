import { SectionLabel } from "@/components/battles"
import { Clip } from "@/components/footage"
import { Reveal } from "@/components/reveal"
import { COUNTS } from "@/lib/intel"

/** Start with a decision, then widen the battlefield. Each beat has its own scale. */
export function Features() {
  return (
    <section id="intel" className="story mx-auto max-w-6xl scroll-mt-16 px-4 py-24 sm:px-6">
      <Reveal from="signal">
        <SectionLabel>01 / Take command</SectionLabel>
        <h2 className="mt-4 max-w-3xl font-display text-5xl leading-none font-extrabold uppercase sm:text-7xl">
          The road is covered.
          <br />
          <span className="text-primary">Find another way.</span>
        </h2>
        <p className="mt-6 max-w-xl text-lg leading-relaxed text-muted-foreground">
          Pin them down. Send a squad around the flank. Decide when to push and when to pull back. Frontline is a
          real-time strategy game about reading the fight and making the call.
        </p>
      </Reveal>

      <article className="mt-12 grid items-center gap-8 lg:grid-cols-[1.6fr_1fr] lg:gap-14">
        <Reveal from="signal">
          <Clip name="squads" label="Assault · In-game footage" grid="E3" className="aspect-video" />
        </Reveal>
        <Reveal from="type" delay={120}>
          <p className="font-mono text-xs tracking-widest text-primary uppercase">Your orders. Their instincts.</p>
          <h3 className="mt-4 font-display text-4xl leading-none font-bold uppercase">
            You choose the move.
            <br />
            They fight as a team.
          </h3>
          <p className="mt-5 leading-relaxed text-muted-foreground">
            One team covers while another advances. Squads clear houses, spring ambushes and break contact when the
            fight turns against them. Give the order; they work out the drill.
          </p>
          <p className="mt-6 border-t pt-4 font-mono text-xs tracking-wide text-muted-foreground">
            COVER → ADVANCE → ASSAULT
          </p>
        </Reveal>
      </article>

      <article className="my-20 grid items-center gap-8 border-y py-10 md:grid-cols-[1fr_1.2fr] md:gap-16">
        <Reveal from="signal">
          <SectionLabel>Every soldier matters</SectionLabel>
          <h3 className="mt-4 font-display text-4xl leading-none font-bold uppercase sm:text-5xl">
            Under fire,
            <br />
            instinct takes over.
          </h3>
          <p className="mt-5 max-w-md leading-relaxed text-muted-foreground">
            Watch a man duck behind a wreck, drag a wounded comrade to safety or throw an enemy grenade back. These are
            soldiers reacting to the battle you set in motion.
          </p>
        </Reveal>
        <Reveal from="type">
          <Clip name="infantry" label="Infantry · In-game footage" grid="C6" className="aspect-video" />
        </Reveal>
      </article>

      <article>
        <Reveal from="signal" className="mb-10 flex flex-wrap items-end justify-between gap-6">
          <div>
            <SectionLabel>02 / Change the fight</SectionLabel>
            <h3 className="mt-4 font-display text-5xl leading-none font-extrabold uppercase sm:text-7xl">
              Now bring the
              <br />
              <span className="text-primary">heavy hitters.</span>
            </h3>
          </div>
          <p className="max-w-sm leading-relaxed text-muted-foreground">
            A tank breaks the deadlock. A fire mission forces the enemy out of cover. A landing opens a whole new front.
            Make your forces work together.
          </p>
        </Reveal>
        <Reveal from="signal">
          <Clip name="armour" label="Armour · In-game footage" grid="B4" className="aspect-video sm:aspect-[21/9]" />
        </Reveal>
        <div className="flex flex-wrap justify-between gap-3 border-b py-5">
          <p className="font-display text-xl font-bold uppercase">Break through on the ground</p>
          <p className="font-mono text-xs text-muted-foreground">
            {COUNTS.vehicles} vehicles · From quad bikes to main battle tanks
          </p>
        </div>
        <div className="mt-10 grid gap-10 md:grid-cols-2">
          <div>
            <Reveal from="type">
              <Clip name="fires" label="Fire mission · In-game footage" grid="G4" className="aspect-video" />
            </Reveal>
            <h4 className="mt-5 font-display text-3xl font-bold uppercase">Call it in</h4>
            <p className="mt-2 leading-relaxed text-muted-foreground">
              Mortars, artillery and gun runs. Shellfire sets cover alight; the wind carries the flames. The battlefield
              changes with every strike.
            </p>
          </div>
          <div className="md:pt-16">
            <Reveal from="signal">
              <Clip name="sea" label="Naval · In-game footage" grid="H5" className="aspect-video" />
            </Reveal>
            <h4 className="mt-5 font-display text-3xl font-bold uppercase">Open another front</h4>
            <p className="mt-2 leading-relaxed text-muted-foreground">
              Land raiders under a patrol ship’s guns. Sling a vehicle forward by helicopter. Bring the fight from
              somewhere they weren’t watching.
            </p>
          </div>
        </div>
      </article>
      <p className="mt-12 font-mono text-xs text-muted-foreground">
        Actual gameplay throughout. Every clip recorded in Frontline.
      </p>
    </section>
  )
}
