import { GithubLogoIcon, WarningIcon } from "@phosphor-icons/react"
import { useId, useState } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { useAccount } from "@/lib/account"
import { cn } from "@/lib/utils"

/**
 * How players sign in: with GitHub (the first time makes the account). With
 * `email`, for testing only (EMAIL_SIGN_IN: never on the live site), the email
 * and password form follows. Busy, errors and notices come from the account.
 */
export function SignInChoices({
  blurb,
  onGitHub,
  email,
  form,
}: {
  blurb: string
  onGitHub: () => void
  email: boolean
  form: AccountFormProps
}) {
  const { busy } = useAccount()
  return (
    <>
      <div className="space-y-3 p-4">
        <p className="text-xs leading-relaxed text-muted-foreground">{blurb}</p>
        <Button type="button" onClick={onGitHub} disabled={busy} className="h-9 w-full text-sm font-semibold">
          <GithubLogoIcon weight="fill" />
          {busy ? "Signing in…" : "Sign in with GitHub"}
        </Button>
        <p className="text-xs leading-relaxed text-muted-foreground">
          New to Frontline? Signing in makes your account, named after your GitHub account. You can rename it in the
          game.
        </p>
        {!email && <Messages />}
      </div>
      {email && (
        <div className="border-t">
          <p className="px-4 pt-3 text-[11px] font-semibold tracking-[0.12em] text-muted-foreground uppercase">
            Email and password · for testing
          </p>
          <AccountForm {...form} />
        </div>
      )}
    </>
  )
}

/** The account's error, or a notice when there's no error. */
function Messages() {
  const { error, notice } = useAccount()
  if (error) {
    return (
      <p role="alert" className="flex items-start gap-2 text-xs text-destructive">
        <WarningIcon className="mt-px size-4 shrink-0" />
        {error}
      </p>
    )
  }
  return notice ? <output className="block text-xs text-good">{notice}</output> : null
}

type AccountFormProps = {
  /**
   * Signs in (no callsign) or makes the account: "in" when that's done,
   * "confirm" when the email needs confirming first, null when it failed (the
   * error is in the account's state).
   */
  onSubmit: (email: string, password: string, callsign: string | null) => Promise<"in" | "confirm" | null>
  /** a line over the fields: what the account is for */
  intro: (creating: boolean) => string
  /** open on Create account */
  create?: boolean
  email?: string
  callsign?: string
}

/**
 * Sign in, or create an account, with an email and password: two tabs over
 * one form. What it says while it's busy, and any error or notice, come from
 * the account (useAccount).
 */
function AccountForm({
  onSubmit,
  intro,
  create = false,
  email: email0 = "",
  callsign: callsign0 = "",
}: AccountFormProps) {
  const { busy, clearError } = useAccount()
  const [creating, setCreating] = useState(create)
  const [email, setEmail] = useState(email0)
  const [password, setPassword] = useState("")
  const [callsign, setCallsign] = useState(callsign0)
  const id = useId()

  const switchTo = (c: boolean) => {
    setCreating(c)
    clearError()
  }

  const submit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (busy) return
    const r = await onSubmit(email, password, creating ? callsign : null)
    if (r) setPassword("")
    if (r === "confirm") setCreating(false)
  }

  return (
    <>
      <fieldset className="grid min-w-0 grid-cols-2 border-b" aria-label="Sign in or create an account">
        {[false, true].map((c) => (
          <button
            key={String(c)}
            type="button"
            aria-pressed={creating === c}
            onClick={() => switchTo(c)}
            className={cn(
              "h-10 border-b-2 text-xs font-semibold tracking-[0.12em] uppercase transition-colors outline-none focus-visible:bg-muted",
              creating === c
                ? "border-primary text-foreground"
                : "border-transparent text-muted-foreground hover:text-foreground"
            )}
          >
            {c ? "Create account" : "Sign in"}
          </button>
        ))}
      </fieldset>

      <form onSubmit={submit} className="space-y-3 p-4">
        <p className="text-xs leading-relaxed text-muted-foreground">{intro(creating)}</p>
        <div className="space-y-1.5">
          <Label htmlFor={`${id}-email`}>Email</Label>
          <Input
            id={`${id}-email`}
            type="email"
            autoComplete="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </div>
        <div className="space-y-1.5">
          <Label htmlFor={`${id}-password`}>Password</Label>
          <Input
            id={`${id}-password`}
            type="password"
            autoComplete={creating ? "new-password" : "current-password"}
            required
            minLength={creating ? 8 : undefined}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </div>
        {creating && (
          <div className="space-y-1.5">
            <Label htmlFor={`${id}-callsign`}>Callsign</Label>
            <Input
              id={`${id}-callsign`}
              autoComplete="nickname"
              required
              minLength={3}
              maxLength={20}
              pattern="[A-Za-z0-9 _.\-]{3,20}"
              title="3 to 20 letters, digits, spaces, _ . or -"
              aria-describedby={`${id}-callsign-hint`}
              value={callsign}
              onChange={(e) => setCallsign(e.target.value)}
            />
            <p id={`${id}-callsign-hint`} className="text-xs text-muted-foreground">
              3 to 20 letters, digits, spaces, _ . or -. Shown beside the battles you host.
            </p>
          </div>
        )}

        <Messages />

        <Button type="submit" disabled={busy} className="h-9 w-full text-sm font-semibold">
          {busy ? (creating ? "Creating your account…" : "Signing in…") : creating ? "Create account" : "Sign in"}
        </Button>
      </form>
    </>
  )
}
