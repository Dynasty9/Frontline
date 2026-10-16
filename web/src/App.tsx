import { useEffect, useState } from "react"
import { Battles } from "@/components/battles"
import { Downloads } from "@/components/downloads"
import { Emblem } from "@/components/emblem"
import { Gallery } from "@/components/gallery"
import { Hero } from "@/components/hero"
import { InsigniaSection } from "@/components/insignia"
import { SiteHeader } from "@/components/site-header"
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

  return (
    <TooltipProvider delayDuration={150}>
      <SiteHeader accounts={health.data?.accounts} />
      <main>
        <Hero health={health.data} build={builds.stable ?? builds.nightly} platform={platform} onLaunch={() => setLaunched(true)} />
        <Battles
          lobbies={lobbies.data}
          error={lobbies.error}
          updatedAt={lobbies.updatedAt}
          launched={launched}
          onLaunch={() => setLaunched(true)}
          onDismissLaunch={() => setLaunched(false)}
        />
        <InsigniaSection accounts={health.data?.accounts} />
        <Downloads {...builds} platform={platform} />
        <Gallery />
      </main>
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
