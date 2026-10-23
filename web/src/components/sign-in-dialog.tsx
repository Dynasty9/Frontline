import { CircleNotchIcon, GithubLogoIcon } from "@phosphor-icons/react"
import { SiteSignIn } from "@/components/account-form"
import { SectionLabel } from "@/components/battles"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { EMAIL_SIGN_IN } from "@/lib/config"

type Props = {
  open: boolean
  onClose: () => void
  /** the matchmaker's /health answer: "off" means it takes no sign-ins */
  accounts?: string
  /** back from GitHub, the code being swapped for a session */
  finishing?: boolean
  /** email and password too: for testing (EMAIL_SIGN_IN), never on the live site */
  email?: boolean
  /** where Sign in with GitHub sends the browser (the stories only record it) */
  navigate?: (url: string) => void
}

const go = (url: string) => window.location.assign(url)

/**
 * Signing in to the site, over whatever page the player is on: Sign in with
 * GitHub, off to GitHub and back. Back from GitHub it says it's signing them
 * in, or, if that failed, why, with the button to try again. Once they're in,
 * the layout closes it and takes them to their profile.
 */
export function SignInDialog({
  open,
  onClose,
  accounts,
  finishing = false,
  email = EMAIL_SIGN_IN,
  navigate = go,
}: Props) {
  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="gap-0 p-0 text-sm sm:max-w-md">
        <DialogHeader className="gap-1.5 p-4 pr-10">
          <SectionLabel>Account</SectionLabel>
          <DialogTitle className="text-xl font-semibold">
            {finishing ? "Signing you in…" : "Sign in to Frontline"}
          </DialogTitle>
          <DialogDescription>
            {finishing
              ? "Back from GitHub. Getting your account ready."
              : "One account for the game and this site. You don't need one to play, online or off."}
          </DialogDescription>
        </DialogHeader>

        {accounts === "off" ? (
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
            <SiteSignIn email={email} navigate={navigate} />
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}
