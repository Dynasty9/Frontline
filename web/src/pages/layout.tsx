import { useEffect, useLayoutEffect, useState } from "react"
import { Outlet, ScrollRestoration, useLocation, useNavigate } from "react-router"
import { GameSignIn } from "@/components/game-sign-in"
import { SiteFooter } from "@/components/site-footer"
import { SignInDialog } from "@/components/sign-in-dialog"
import { SiteHeader } from "@/components/site-header"
import { TooltipProvider } from "@/components/ui/tooltip"
import { usePoll } from "@/hooks/use-poll"
import { closeSignIn, openSignIn, useSignInDialog } from "@/hooks/use-sign-in-dialog"
import type { Site } from "@/hooks/use-site"
import { finishGitHub, takeGitHubReturn, useAccount } from "@/lib/account"
import { readSignInRequest, withoutSignInRequest } from "@/lib/game-sign-in"
import { fetchHealth } from "@/lib/matchmaker"

/**
 * Every page: the header, the page, the footer, and the sign-in dialog. The
 * game opens the site's front page for a few things (?sign-in=, ?join=;
 * GitHub comes back to it with ?code=), and older copies of the game will go
 * on doing so, so they're taken care of here, whichever page they land on.
 */
export function Layout() {
  const health = usePoll(fetchHealth, 15_000)
  const location = useLocation()
  const navigate = useNavigate()
  const { user } = useAccount()
  const signingIn = useSignInDialog()
  // this page's address as the router has it: the browser's, except in the stories
  const here = window.location.origin + location.pathname + location.search + location.hash

  // back from signing in with GitHub (?code=): the game's sign-in (its dialog
  // finishes it), or the site's: the sign-in dialog opens on whatever page
  // this is and says it's signing them in, or why it couldn't
  const [github] = useState(() => takeGitHubReturn(here))
  const [finishing, setFinishing] = useState(() => github !== null && !github.back.game)
  useEffect(() => {
    if (!github) return
    void navigate(github.clean, { replace: true })
    if (github.back.game) return
    openSignIn()
    void finishGitHub(github.back).finally(() => setFinishing(false))
  }, [github, navigate])

  // signed in through the dialog, with GitHub or (testing) a password: on to their profile
  useEffect(() => {
    if (!signingIn || !user) return
    closeSignIn()
    void navigate("/profile")
  }, [signingIn, user, navigate])

  // the game sent the player here to sign in (?sign-in=STATE)
  const [gameSignIn, setGameSignIn] = useState(() => readSignInRequest(location.search) ?? github?.back.game ?? null)
  const closeGameSignIn = () => {
    setGameSignIn(null)
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
      <SignInDialog open={signingIn} onClose={closeSignIn} accounts={health.data?.accounts} finishing={finishing} />
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
