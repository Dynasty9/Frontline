import { useEffect, useState } from "react"
import { Battles } from "@/components/battles"
import { WhatsNew } from "@/components/changelog"
import { Downloads } from "@/components/downloads"
import { Emblem } from "@/components/emblem"
import { Features } from "@/components/features"
import { Finale } from "@/components/finale"
import { Gallery } from "@/components/gallery"
import { GameSignIn } from "@/components/game-sign-in"
import { Hero } from "@/components/hero"
import { InsigniaSection } from "@/components/insignia"
import { TickerBands } from "@/components/marquee"
import { Missions } from "@/components/missions"
import { ReelDialog } from "@/components/reel-dialog"
import { SiteHeader } from "@/components/site-header"
import { Stats } from "@/components/stats"
import { TooltipProvider } from "@/components/ui/tooltip"
import { usePoll } from "@/hooks/use-poll"
import { finishGitHub, takeGitHubReturn } from "@/lib/account"
import { GITHUB_URL } from "@/lib/config"
import { readSignInRequest, withoutSignInRequest } from "@/lib/game-sign-in"
import { fetchHealth, fetchLobbies } from "@/lib/matchmaker"
import { guessPlatform } from "@/lib/releases"

export default function App() {
  const lobbies = usePoll(fetchLobbies, 5_000)
  const health = usePoll(fetchHealth, 15_000)
  const [platform] = useState(guessPlatform)
  // after a Join or Find Match link: a note on what should happen next
  const [launched, setLaunched] = useState(false)
  // an invite from a friend's lobby (?join=ID): that battle, up top
  const [invite, setInvite] = useState(() => new URLSearchParams(window.location.search).get("join"))
  useEffect(() => {
    if (invite) document.getElementById("battles")?.scrollIntoView()
  }, [invite])
  const dismissInvite = () => {
    setInvite(null)
    window.history.replaceState(null, "", window.location.pathname + window.location.hash)
  }
  const [watching, setWatching] = useState(false)
  // back from signing in with GitHub (?code=): the game's sign-in (its dialog
  // finishes it), or the site's (finished here, then the profile)
  const [github] = useState(() => takeGitHubReturn())
  useEffect(() => {
    if (!github) return
    window.history.replaceState(null, "", github.clean)
    if (github.back.game) return
    void finishGitHub(github.back).then(() => document.getElementById("insignia")?.scrollIntoView())
  }, [github])
  // the game sent the player here to sign in (?sign-in=STATE)
  const [gameSignIn, setGameSignIn] = useState(
    () => readSignInRequest(window.location.search) ?? github?.back.game ?? null
  )
  const closeGameSignIn = () => {
    setGameSignIn(null)
    window.history.replaceState(null, "", withoutSignInRequest(window.location.href))
  }

  return (
    <TooltipProvider delayDuration={150}>
      <SiteHeader overlay accounts={health.data?.accounts} />
      {/* things slide in from the sides as they reveal: never let them widen the page */}
      <main className="overflow-x-clip">
        <Hero
          health={health.data}
          platform={platform}
          onLaunch={() => setLaunched(true)}
          onWatch={() => setWatching(true)}
        />
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
          invite={invite}
          onDismissInvite={dismissInvite}
        />
        <InsigniaSection accounts={health.data?.accounts} />
        <WhatsNew />
        <Downloads platform={platform} />
        <Gallery />
        <Finale platform={platform} onLaunch={() => setLaunched(true)} />
      </main>
      <ReelDialog open={watching} onClose={() => setWatching(false)} />
      {gameSignIn && (
        <GameSignIn
          request={gameSignIn}
          accounts={health.data?.accounts}
          onClose={closeGameSignIn}
          returned={github?.back.game ? github.back : undefined}
        />
      )}
      <footer className="border-t">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center gap-x-6 gap-y-3 px-4 py-8 text-xs text-muted-foreground sm:px-6">
          <span className="flex items-center gap-2">
            <Emblem className="size-5" />
            Frontline is free and open source under the MIT License.
          </span>
          <a href={GITHUB_URL} className="hover:text-foreground sm:ml-auto">
            Source on GitHub
          </a>
          <a href={`${GITHUB_URL}/issues`} className="hover:text-foreground">
            Report a bug
          </a>
        </div>
      </footer>
    </TooltipProvider>
  )
}
