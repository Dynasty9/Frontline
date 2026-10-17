import { CheckCircleIcon, CircleNotchIcon, GithubLogoIcon, WarningIcon } from "@phosphor-icons/react"
import { useCallback, useEffect, useRef, useState } from "react"
import { SignInChoices } from "@/components/account-form"
import { SectionLabel } from "@/components/battles"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { finishGitHub, type GitHubReturn, useAccount } from "@/lib/account"
import { EMAIL_SIGN_IN, signInLink } from "@/lib/config"
import type { SignInRequest } from "@/lib/game-sign-in"
import { watchHandoff } from "@/lib/launch"
import { cn } from "@/lib/utils"

type Props = {
  request: SignInRequest
  /** the matchmaker's /health answer: "off" means it takes no sign-ins */
  accounts?: string
  onClose: () => void
  /** back from GitHub, with the game's sign-in to finish */
  returned?: GitHubReturn
  /** email and password too: for testing (EMAIL_SIGN_IN), never on the live site */
  email?: boolean
  /** where the dialog sends the browser: GitHub, then the game (the stories only record it) */
  navigate?: (url: string) => void
}

const go = (url: string) => window.location.assign(url)

/** Handing the sign-in to the game: on its way, gone to it (or the browser's prompt for it), or nothing took it. */
type Handoff = "waiting" | "opened" | "missing"

/**
 * The game sent the player here to sign in (?sign-in=, src/lib/game-sign-in.ts).
 * They sign in with GitHub (back on this page, `returned`), and the site hands
 * the game a session of its own in a frontline:// link: the browser asks to
 * open Frontline, and the game is signed in. The site itself stays as it was.
 *
 * Nothing on this page can see the game sign in, so it says what it can: the
 * two steps and which one this is, and whether the browser handed the link on
 * (the page loses focus to the browser's prompt or the game: src/lib/launch.ts).
 * If nothing took it, it says so, with the button to open the link again (some
 * browsers only open an app straight from a click).
 */
export function GameSignIn({ request, accounts, onClose, returned, email = EMAIL_SIGN_IN, navigate = go }: Props) {
  const { signInGame, signInWithGitHub } = useAccount()
  const [finishing, setFinishing] = useState(!!returned && !("error" in returned))
  const [link, setLink] = useState<string | null>(null)
  const [handoff, setHandoff] = useState<Handoff>("waiting")
  const live = useRef(true)
  useEffect(() => {
    live.current = true
    return () => {
      live.current = false
    }
  }, [])

  // the browser is following the link (sent there, or the button clicked): did anything take it?
  const watch = useCallback(() => {
    setHandoff("waiting")
    void watchHandoff(window, document).then((handed) => {
      if (live.current) setHandoff(handed ? "opened" : "missing")
    })
  }, [])
  const handOver = useCallback(
    (l: string) => {
      setLink(l)
      watch()
      navigate(l)
    },
    [navigate, watch]
  )

  useEffect(() => {
    if (!returned) return
    // this run's own: a link handed over twice would be turned down the second time, by a game already signed in
    let current = true
    void finishGitHub(returned).then((r) => {
      if (!current) return
      setFinishing(false)
      if (r !== null && r !== "in") handOver(signInLink(request.state, r.token))
    })
    return () => {
      current = false
    }
  }, [returned, request.state, handOver])

  const submit = async (address: string, password: string, callsign: string | null) => {
    const r = await signInGame(address, password, callsign)
    if (r === null || r === "confirm") return r
    handOver(signInLink(request.state, r.token))
    return "in" as const
  }

  const step = link ? 2 : 1
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="gap-0 p-0 text-sm sm:max-w-md">
        <DialogHeader className="gap-1.5 p-4 pr-10">
          <SectionLabel>The game</SectionLabel>
          <DialogTitle className="text-xl font-semibold">
            {link ? "You're signed in" : finishing ? "Signing you in…" : "Sign in to Frontline"}
          </DialogTitle>
          <DialogDescription>
            {link
              ? "Now the game signs in with it."
              : "Your game sent you here. Sign in with GitHub, and the game signs in too."}
          </DialogDescription>
          {accounts !== "off" && <Steps at={step} done={handoff === "opened"} />}
        </DialogHeader>

        {link ? (
          <div className="space-y-4 border-t p-4">
            <HandoffNote state={handoff} />
            <div className="flex gap-2">
              <Button asChild variant={handoff === "opened" ? "outline" : "default"} className="flex-1 font-semibold">
                <a href={link} onClick={watch}>
                  Open Frontline
                </a>
              </Button>
              <DialogClose asChild>
                <Button variant={handoff === "opened" ? "default" : "outline"} className="flex-1">
                  Done
                </Button>
              </DialogClose>
            </div>
          </div>
        ) : accounts === "off" ? (
          <p className="border-t p-4 text-xs leading-relaxed text-muted-foreground">
            The matchmaker isn't taking sign-ins right now. You can still play online under any callsign.
          </p>
        ) : finishing ? (
          <output className="flex items-center gap-3 border-t p-4 text-xs text-muted-foreground">
            <span className="relative grid size-9 shrink-0 place-items-center bg-muted/60 ring-1 ring-white/10">
              <GithubLogoIcon weight="fill" className="size-4 text-foreground" />
              <CircleNotchIcon className="absolute inset-0 m-auto size-9 animate-spin text-primary motion-reduce:hidden" />
            </span>
            Signing in with GitHub…
          </output>
        ) : (
          <div className="border-t">
            <SignInChoices
              blurb="Your account keeps your callsign yours, and every battle you play counts towards your rank."
              onGitHub={() => void signInWithGitHub(request, navigate)}
              email={email}
              form={{
                create: request.create,
                callsign: request.callsign,
                intro: (creating) =>
                  creating ? "A test account, signed in to the game." : "A test account's email and password.",
                onSubmit: submit,
              }}
            />
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}

const STEPS = ["Sign in with GitHub", "Back to the game"]

/** The two steps, and which one this is: `at` (1 or 2), every step before it done, and all of them once `done`. */
function Steps({ at, done }: { at: number; done: boolean }) {
  return (
    <ol className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs">
      {STEPS.map((s, i) => {
        const n = i + 1
        const finished = done || n < at
        return (
          <li
            key={s}
            aria-current={n === at && !done ? "step" : undefined}
            className={cn(
              "flex items-center gap-1.5",
              finished ? "text-good" : n === at ? "font-semibold text-foreground" : "text-muted-foreground"
            )}
          >
            {finished ? (
              <>
                <CheckCircleIcon weight="fill" className="size-4" aria-hidden="true" />
                <span className="sr-only">Done:</span>
              </>
            ) : (
              <span
                className={cn(
                  "grid size-4 place-items-center rounded-full border text-[10px] leading-none font-bold",
                  n === at ? "border-primary text-primary" : "border-muted-foreground/50"
                )}
              >
                {n}
              </span>
            )}
            {s}
          </li>
        )
      })}
    </ol>
  )
}

/** What became of the link: the browser is handing it over, it went, or nothing took it (and what to do). */
function HandoffNote({ state }: { state: Handoff }) {
  // an <output>: read out as it changes, without taking the focus
  return (
    <output className="block text-xs leading-relaxed">
      {state === "waiting" ? (
        <span className="flex items-start gap-2 text-muted-foreground">
          <CircleNotchIcon className="mt-px size-4 shrink-0 animate-spin text-primary motion-reduce:hidden" />
          Opening Frontline… If your browser asks, let it open Frontline.
        </span>
      ) : state === "opened" ? (
        <span className="flex items-start gap-2 text-good">
          <CheckCircleIcon weight="fill" className="mt-px size-4 shrink-0" />
          Over to the game: it signs in and says so. You can close this tab.
        </span>
      ) : (
        <span className="flex items-start gap-2 text-warn">
          <WarningIcon weight="fill" className="mt-px size-4 shrink-0" />
          <span>
            Your browser didn't open Frontline. Press Open Frontline, and if your browser asks, let it. The game you
            pressed Sign in in has to be running. Still nothing? Restart the game (starting it sets it up to take these
            links), then sign in from it again.
          </span>
        </span>
      )}
    </output>
  )
}
