import { SectionLabel } from "@/components/battles"

const SHOTS = [
  ["armour", "A tank battle"],
  ["river_bridge", "A bridge over the river, by a village"],
  ["sling_load", "A helicopter carrying a Humvee"],
  ["patrol_ship", "A patrol ship off the coast"],
  ["mission_kingpin", "Kingpin: one of the missions"],
] as const

const POINTS = [
  ["Soldiers that think", "They take cover behind real walls and wrecks, keep their heads down under fire, drag the wounded to safety and throw grenades back."],
  ["Squads that fight like squads", "Teams leapfrog forward under covering fire, clear houses room by room, set ambushes on the roads, and break when a fight goes badly."],
  ["Combined arms", "Tanks, helicopters, boats, mortars, artillery and air strikes, on a square kilometre of countryside with a town, a river and the sea."],
] as const

export function Gallery() {
  return (
    <section id="screenshots" className="mx-auto max-w-6xl scroll-mt-16 px-4 py-20 sm:px-6">
      <SectionLabel>The game</SectionLabel>
      <h2 className="mt-2 text-3xl font-semibold">You command squads, not soldiers</h2>
      <div className="mt-8 grid gap-6 md:grid-cols-3">
        {POINTS.map(([title, text]) => (
          <div key={title} className="border-l-2 border-primary/60 pl-4">
            <h3 className="font-semibold">{title}</h3>
            <p className="mt-1 text-sm leading-relaxed text-muted-foreground">{text}</p>
          </div>
        ))}
      </div>
      <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-6">
        {SHOTS.map(([file, caption], i) => (
          <figure key={file} className={i < 2 ? "lg:col-span-3" : "lg:col-span-2"}>
            <img
              src={`/shots/${file}.jpg`}
              alt={caption}
              loading="lazy"
              className="aspect-video w-full object-cover ring-1 ring-white/10"
              width={1600}
              height={900}
            />
            <figcaption className="mt-2 text-xs text-muted-foreground">{caption}</figcaption>
          </figure>
        ))}
      </div>
      <p className="mt-8 text-sm text-muted-foreground">
        Everything you see and hear is made in code: there are no imported 3D models, textures or sound files.
      </p>
    </section>
  )
}
