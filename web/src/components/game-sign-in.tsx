import { CheckCircleIcon } from "@phosphor-icons/react"
import { useEffect, useState } from "react"
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

/**
 * The game sent the player here to sign in (?sign-in=, src/lib/game-sign-in.ts).
 * They sign in with GitHub (back on this page, `returned`), and the site hands
 * the game a session of its own in a frontline:// link: the browser asks to
 * open Frontline, and the game is signed in. The site itself stays as it was.
 * The button opens the link again, in case the browser didn't (some only open
 * an app straight from a click).
 */
export function GameSignIn({ request, accounts, onClose, returned, email = EMAIL_SIGN_IN, navigate = go }: Props) {
  const { signInGame, signInWithGitHub } = useAccount()
  const [link, setLink] = useState<string | null>(null)

  useEffect(() => {
    if (!returned) return
    let live = true
    void finishGitHub(returned).then((r) => {
      if (!live || r === null || r === "in") return
      const l = signInLink(request.state, r.token)
      setLink(l)
      navigate(l)
    })
    return () => {
      live = false
    }
  }, [returned, request.state, navigate])

  const submit = async (address: string, password: string, callsign: string | null) => {
    const r = await signInGame(address, password, callsign)
    if (r === null || r === "confirm") return r
    const l = signInLink(request.state, r.token)
    setLink(l)
    navigate(l)
    return "in" as const
  }

  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="gap-0 p-0 text-sm sm:max-w-md">
        <DialogHeader className="gap-1.5 p-4 pr-10">
          <SectionLabel>The game</SectionLabel>
          <DialogTitle className="text-xl font-semibold">
            {link ? "You're signed in" : "Sign in to Frontline"}
          </DialogTitle>
          <DialogDescription>
            {link
              ? "Back to the game: it's signing in now. If your browser asks, let it open Frontline."
              : "Your game sent you here. Sign in with GitHub, and the game signs in too."}
          </DialogDescription>
        </DialogHeader>

        {link ? (
          <div className="space-y-4 border-t p-4">
            <p className="flex items-center gap-2 text-xs text-good">
              <CheckCircleIcon weight="fill" className="size-4 shrink-0" />
              The game stays signed in: every battle you play counts towards your rank.
            </p>
            <div className="flex gap-2">
              <Button asChild className="flex-1 font-semibold">
                <a href={link}>Open Frontline</a>
              </Button>
              <DialogClose asChild>
                <Button variant="outline" className="flex-1">
                  Done
                </Button>
              </DialogClose>
            </div>
          </div>
        ) : accounts === "off" ? (
          <p className="border-t p-4 text-xs leading-relaxed text-muted-foreground">
            The matchmaker isn't taking sign-ins right now. You can still play online under any callsign.
          </p>
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
