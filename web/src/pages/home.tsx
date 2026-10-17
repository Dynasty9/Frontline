import { useState } from "react"
import { Navigate, useSearchParams } from "react-router"
import { Battles } from "@/components/battles"
import { WhatsNew } from "@/components/changelog"
import { Downloads } from "@/components/downloads"
import { Features } from "@/components/features"
import { Finale } from "@/components/finale"
import { Gallery } from "@/components/gallery"
import { Hero } from "@/components/hero"
import { InsigniaSection } from "@/components/insignia"
import { TickerBands } from "@/components/marquee"
import { Missions } from "@/components/missions"
import { ReelDialog } from "@/components/reel-dialog"
import { Stats } from "@/components/stats"
import { usePageTitle } from "@/hooks/use-page-title"
import { usePoll } from "@/hooks/use-poll"
import { fetchLobbies } from "@/lib/matchmaker"
import { guessPlatform } from "@/lib/releases"
import { useSite } from "@/hooks/use-site"

/** How many battles the front page lists before sending you to the battles page for the rest. */
const FRONT_PAGE_BATTLES = 5

/** The front page: the game, what's on right now, and how to get it. */
export default function Home() {
  usePageTitle()
  const { health } = useSite()
  const lobbies = usePoll(fetchLobbies, 5_000)
  const [platform] = useState(guessPlatform)
  // after a Join or Find Match link: a note on what should happen next
  const [launched, setLaunched] = useState(false)
  const [watching, setWatching] = useState(false)
  // an invite from a friend's lobby (?join=ID), from the game: the battles page shows it
  const [search] = useSearchParams()
  const invite = search.get("join")
  if (invite) return <Navigate to={`/battles?join=${encodeURIComponent(invite)}`} replace />

  return (
    <>
      <Hero health={health} platform={platform} onWatch={() => setWatching(true)} />
      <TickerBands />
      <Stats />
      <Features />
      <Missions />
      <Battles
        lobbies={lobbies.data}
        error={lobbies.error}
        updatedAt={lobbies.updatedAt}
        launched={launched}
        onLaunch={() => setLaunched(true)}
        onDismissLaunch={() => setLaunched(false)}
        limit={FRONT_PAGE_BATTLES}
      />
      <InsigniaSection accounts={health?.accounts} />
      <WhatsNew />
      <Downloads platform={platform} />
      <Gallery />
      <Finale platform={platform} onLaunch={() => setLaunched(true)} />
      <ReelDialog open={watching} onClose={() => setWatching(false)} />
    </>
  )
}
