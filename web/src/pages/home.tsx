import { lazy, Suspense, useState } from "react"
import { Navigate, useLocation, useSearchParams } from "react-router"
import { Features } from "@/components/features"
import { Finale } from "@/components/finale"
import { Gallery } from "@/components/gallery"
import { PlayerHome } from "@/components/player-home"
import { useAccount } from "@/lib/account"
import { Hero } from "@/components/hero"
import { Missions } from "@/components/missions"
import { ReelDialog } from "@/components/reel-dialog"
import { useInView } from "@/hooks/use-in-view"
import { usePageTitle } from "@/hooks/use-page-title"
import { withFreshBuild } from "@/lib/stale-build"
import { guessDevice, guessPlatform } from "@/lib/releases"
import { useSite } from "@/hooks/use-site"

// Sections the front page used to have, which have pages of their own now.
// The game opens /#download, and older copies will go on doing so.
const MOVED: Record<string, string> = { "#download": "/play#download", "#insignia": "/ranks", "#battles": "/battles" }

// What's new reads the whole changelog (every release's notes, and the
// Markdown to show them): fetched as the visitor scrolls towards it, so the
// front page's first load, and every other page's, doesn't carry it.
const WhatsNew = lazy(async () => ({
  default: (await withFreshBuild(() => import("@/components/changelog"))).WhatsNew,
}))

function NearWhatsNew() {
  const [ref, near] = useInView<HTMLDivElement>({ once: true, margin: "900px 0px" })
  // about its own height while it comes, so nothing below it moves much when it lands
  const room = <div aria-hidden="true" className="min-h-[34rem] lg:min-h-[26rem]" />
  return <div ref={ref}>{near ? <Suspense fallback={room}>{<WhatsNew />}</Suspense> : room}</div>
}

/**
 * Home: what the game is, to someone who's never played it, and to everyone
 * else. A signed-in player also gets their progress and the way back into a
 * battle, just under the footage. The live battles, the ranks, the downloads,
 * the Field Manual and your profile have pages of their own.
 */
export default function Home() {
  usePageTitle()
  const { health } = useSite()
  const { user } = useAccount()
  const [platform] = useState(guessPlatform)
  // on a phone or tablet, where it doesn't run, the download is sent to a computer instead
  const [phone] = useState(() => guessDevice() === "mobile")
  const [watching, setWatching] = useState(false)
  const { hash } = useLocation()
  // an invite from a friend's lobby (?join=ID), from the game: the battles page shows it
  const [search] = useSearchParams()
  const invite = search.get("join")
  if (invite) return <Navigate to={`/battles?join=${encodeURIComponent(invite)}`} replace />
  if (MOVED[hash]) return <Navigate to={MOVED[hash]} replace />

  return (
    <>
      <Hero health={health} platform={platform} phone={phone} onWatch={() => setWatching(true)} />
      {user && health?.accounts !== "off" && <PlayerHome user={user} live={health?.lobbies} />}
      <Features />
      <Missions />
      <Gallery />
      <NearWhatsNew />
      <Finale platform={platform} phone={phone} />
      <ReelDialog open={watching} onClose={() => setWatching(false)} />
    </>
  )
}
