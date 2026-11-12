import { useState } from "react"
import { Navigate, useLocation, useSearchParams } from "react-router"
import { WhatsNew } from "@/components/changelog"
import { Features } from "@/components/features"
import { Finale } from "@/components/finale"
import { Gallery } from "@/components/gallery"
import { PlayerHome } from "@/components/player-home"
import { useAccount } from "@/lib/account"
import { Hero } from "@/components/hero"
import { Missions } from "@/components/missions"
import { ReelDialog } from "@/components/reel-dialog"
import { usePageTitle } from "@/hooks/use-page-title"
import { guessPlatform } from "@/lib/releases"
import { useSite } from "@/hooks/use-site"

// Sections the front page used to have, which have pages of their own now.
// The game opens /#download, and older copies will go on doing so.
const MOVED: Record<string, string> = { "#download": "/play#download", "#insignia": "/ranks", "#battles": "/battles" }

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
  const [watching, setWatching] = useState(false)
  const { hash } = useLocation()
  // an invite from a friend's lobby (?join=ID), from the game: the battles page shows it
  const [search] = useSearchParams()
  const invite = search.get("join")
  if (invite) return <Navigate to={`/battles?join=${encodeURIComponent(invite)}`} replace />
  if (MOVED[hash]) return <Navigate to={MOVED[hash]} replace />

  return (
    <>
      <Hero health={health} platform={platform} onWatch={() => setWatching(true)} />
      {user && health?.accounts !== "off" && <PlayerHome user={user} live={health?.lobbies} />}
      <Features />
      <Missions />
      <Gallery />
      <WhatsNew />
      <Finale platform={platform} />
      <ReelDialog open={watching} onClose={() => setWatching(false)} />
    </>
  )
}
