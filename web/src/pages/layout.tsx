import { useEffect, useLayoutEffect, useState } from "react"
import { Outlet, ScrollRestoration, useLocation, useNavigate } from "react-router"
import { GameSignIn } from "@/components/game-sign-in"
import { SiteFooter } from "@/components/site-footer"
import { SiteHeader } from "@/components/site-header"
import { TooltipProvider } from "@/components/ui/tooltip"
import { usePoll } from "@/hooks/use-poll"
import type { Site } from "@/hooks/use-site"
import { finishGitHub, takeGitHubReturn } from "@/lib/account"
import { readSignInRequest, withoutSignInRequest } from "@/lib/game-sign-in"
import { fetchHealth } from "@/lib/matchmaker"

/**
 * Every page: the header, the page, the footer. The game opens the site's
 * front page for a few things (?sign-in=, ?join=; GitHub comes back to it
 * with ?code=), and older copies of the game will go on doing so, so they're
 * taken care of here, whichever page they land on.
 */
export function Layout() {
  const health = usePoll(fetchHealth, 15_000)
  const location = useLocation()
  const navigate = useNavigate()

  // back from signing in with GitHub (?code=): the game's sign-in (its dialog
  // finishes it), or the site's (finished here, then back to the page the
  // player signed in from)
  const [github] = useState(() => takeGitHubReturn())
  useEffect(() => {
    if (!github) return
    void navigate(github.clean, { replace: true })
    if (github.back.game) return
    void finishGitHub(github.back).then((r) => {
      if (r === "in" && github.to) void navigate(github.to, { replace: true })
    })
  }, [github, navigate])

  // the game sent the player here to sign in (?sign-in=STATE)
  const [gameSignIn, setGameSignIn] = useState(() => readSignInRequest(location.search) ?? github?.back.game ?? null)
  const closeGameSignIn = () => {
    setGameSignIn(null)
    const here = window.location.origin + location.pathname + location.search + location.hash
    void navigate(withoutSignInRequest(here), { replace: true })
  }

  return (
    <TooltipProvider delayDuration={150}>
      <SiteHeader overlay={location.pathname === "/"} accounts={health.data?.accounts} live={health.data?.lobbies} />
      {/* things slide in from the sides as they reveal: never let them widen the page */}
      <main className="overflow-x-clip">
        <Outlet context={{ health: health.data } satisfies Site} />
      </main>
      <SiteFooter />
      {gameSignIn && (
        <GameSignIn
          request={gameSignIn}
          accounts={health.data?.accounts}
          onClose={closeGameSignIn}
          returned={github?.back.game ? github.back : undefined}
        />
      )}
      {/* a new one for each page */}
      <InstantPageScroll key={location.pathname} />
      <ScrollRestoration />
    </TooltipProvider>
  )
}

/**
 * The site scrolls smoothly within a page (index.css), but a new page should
 * start at its top, or its section, at once, not glide there from wherever
 * the last page was left. Its layout effect runs just before
 * ScrollRestoration's, which does the scrolling.
 */
function InstantPageScroll() {
  useLayoutEffect(() => {
    const html = document.documentElement
    html.style.scrollBehavior = "auto"
    const frame = requestAnimationFrame(() => {
      html.style.scrollBehavior = ""
    })
    return () => cancelAnimationFrame(frame)
  }, [])
  return null
}
