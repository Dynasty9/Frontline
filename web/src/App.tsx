import { useEffect, useState } from "react"
import { Battles } from "@/components/battles"
import { Downloads } from "@/components/downloads"
import { Emblem } from "@/components/emblem"
import { Features } from "@/components/features"
import { Finale } from "@/components/finale"
import { Gallery } from "@/components/gallery"
import { Hero } from "@/components/hero"
import { TickerBands } from "@/components/marquee"
import { Missions } from "@/components/missions"
import { ReelDialog } from "@/components/reel-dialog"
import { SiteHeader } from "@/components/site-header"
import { Stats } from "@/components/stats"
import { TooltipProvider } from "@/components/ui/tooltip"
import { usePoll } from "@/hooks/use-poll"
import { GITHUB_URL } from "@/lib/config"
import { fetchHealth, fetchLobbies } from "@/lib/matchmaker"
import { type Build, fetchBuilds, guessPlatform } from "@/lib/releases"

export default function App() {
  const lobbies = usePoll(fetchLobbies, 5_000)
  const health = usePoll(fetchHealth, 15_000)
  const builds = useBuilds()
  const [platform] = useState(guessPlatform)
  // after a Join or Find Match link: a note on what should happen next
  const [launched, setLaunched] = useState(false)
  const [watching, setWatching] = useState(false)
  const build = builds.stable ?? builds.nightly

  return (
    <TooltipProvider delayDuration={150}>
      <SiteHeader />
      {/* things slide in from the sides as they reveal: never let them widen the page */}
      <main className="overflow-x-clip">
        <Hero
          health={health.data}
          build={build}
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
        />
        <Downloads {...builds} platform={platform} />
        <Gallery />
        <Finale build={build} platform={platform} onLaunch={() => setLaunched(true)} />
      </main>
      <ReelDialog open={watching} onClose={() => setWatching(false)} />
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

function useBuilds() {
  const [state, setState] = useState<{ stable: Build | null; nightly: Build | null; loading: boolean; error: Error | null }>({
    stable: null,
    nightly: null,
    loading: true,
    error: null,
  })
  useEffect(() => {
    fetchBuilds()
      .then((b) => setState({ ...b, loading: false, error: null }))
      .catch((e: Error) => setState({ stable: null, nightly: null, loading: false, error: e }))
  }, [])
  return state
}
