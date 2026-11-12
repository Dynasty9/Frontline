import { SECTIONS, type SectionKey } from "@/lib/manual"

// Every page the site has at a fixed address, with what a search engine or a
// chat app shows for a link to it: its title, a line about it and a picture.
// Those don't run the site's code, so the build writes each page out with its
// own (scripts/prerender.mjs), lists them in sitemap.xml, and the server answers
// any other address, but a player's or a battle's, with a 404. Keep the titles
// in step with each page's usePageTitle.

export type PageMeta = {
  /** the address, from the site's root, without a trailing slash ("/" for the front page) */
  path: string
  title: string
  description: string
  /** a picture from the site's own files, for the link's card */
  image: string
  /** listed in the sitemap for search engines (not sign-in pages or old addresses) */
  listed: boolean
}

const SITE = "Frontline"
const titled = (title?: string) => (title ? `${title} · ${SITE}` : SITE)

/** What the link to a Field Manual chapter shows: a still from the game that goes with it. */
const PICTURES: Record<SectionKey, string> = {
  infantry: "/media/infantry.jpg",
  vehicles: "/shots/armour.jpg",
  buildings: "/media/m-skyhook.jpg",
  support: "/media/reel.jpg",
  research: "/media/m-bridgehead.jpg",
}

const GAME =
  "A free, open-source squad-level RTS where every soldier thinks for himself. Tanks, gunships, patrol boats, artillery and A-10s."

export function sitePages(): PageMeta[] {
  const pages: PageMeta[] = [
    {
      path: "/",
      title: titled(),
      description: `${GAME} Watch the footage, join a battle in a click, and download the game.`,
      image: "/media/hero.jpg",
      listed: true,
    },
    {
      path: "/play",
      title: titled("Play"),
      description:
        "Download Frontline for Windows, macOS or Linux, or launch it and find a match. No account or purchase needed.",
      image: "/media/hero.jpg",
      listed: true,
    },
    {
      path: "/battles",
      title: titled("Live battles"),
      description:
        "Every Frontline battle being hosted right now, each with a Join link that opens the game and connects you.",
      image: "/shots/battle.jpg",
      listed: true,
    },
    {
      path: "/leaderboards",
      title: titled("Leaderboards"),
      description: "The Frontline commanders with the most experience: all time, this month and this week.",
      image: "/media/squads.jpg",
      listed: true,
    },
    {
      path: "/ranks",
      title: titled("Rank guide"),
      description: "How Frontline's ranks work: the experience each takes, and the insignia each one unlocks.",
      image: "/media/squads.jpg",
      listed: true,
    },
    {
      path: "/changelog",
      title: titled("Changelog"),
      description: "Every Frontline release: what changed, with screenshots and footage.",
      image: "/media/reel.jpg",
      listed: true,
    },
    {
      path: "/manual",
      title: titled("Field Manual"),
      description:
        "How Frontline fights, and every soldier, squad, weapon, vehicle, building, fire mission and upgrade in the game, with its figures and 3D model.",
      image: "/media/m-bridgehead.jpg",
      listed: true,
    },
    {
      path: "/profile",
      title: titled("Your profile"),
      description: "Your Frontline callsign, rank, insignia and service record.",
      image: "/media/hero.jpg",
      listed: false,
    },
    // old addresses, sent on by the site itself
    {
      path: "/account",
      title: titled("Your profile"),
      description: "Your Frontline callsign, rank, insignia and service record.",
      image: "/media/hero.jpg",
      listed: false,
    },
    {
      path: "/vehicles",
      title: titled("Vehicles · Field Manual"),
      description: SECTIONS.find((s) => s.key === "vehicles")!.summary,
      image: PICTURES.vehicles,
      listed: false,
    },
  ]
  for (const s of SECTIONS) {
    pages.push({
      path: `/manual/${s.key}`,
      title: titled(`${s.title} · Field Manual`),
      description: s.summary,
      image: PICTURES[s.key],
      listed: true,
    })
    for (const e of s.entries)
      pages.push({
        path: `/manual/${s.key}/${encodeURIComponent(e.id)}`,
        title: titled(`${e.name} · ${s.title}`),
        description: `${e.side} ${e.kind}. ${e.description}`.replace(/\s+/g, " ").trim(),
        image: PICTURES[s.key],
        listed: true,
      })
  }
  return pages
}

const attr = (value: string) => value.replaceAll("&", "&amp;").replaceAll('"', "&quot;").replaceAll("<", "&lt;")

/** The page's head for a link to it: title, description, its card and its address. */
export function headFor(page: PageMeta, origin: string) {
  const url = origin + (page.path === "/" ? "/" : page.path)
  return [
    `<title>${attr(page.title)}</title>`,
    `<meta name="description" content="${attr(page.description)}" />`,
    `<link rel="canonical" href="${attr(url)}" />`,
    `<meta property="og:type" content="website" />`,
    `<meta property="og:site_name" content="${SITE}" />`,
    `<meta property="og:title" content="${attr(page.title)}" />`,
    `<meta property="og:description" content="${attr(page.description)}" />`,
    `<meta property="og:url" content="${attr(url)}" />`,
    `<meta property="og:image" content="${attr(origin + page.image)}" />`,
    `<meta name="twitter:card" content="summary_large_image" />`,
    ...(page.listed ? [] : [`<meta name="robots" content="noindex" />`]),
  ].join("\n    ")
}
