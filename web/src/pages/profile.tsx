import { CheckCircleIcon, CheckIcon, WarningIcon } from "@phosphor-icons/react"
import { useId, useState } from "react"
import { SiteSignIn } from "@/components/account-form"
import { SectionLabel } from "@/components/battles"
import { Collection, Profile } from "@/components/insignia"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { usePageTitle } from "@/hooks/use-page-title"
import { type User, useAccount } from "@/lib/account"
import { EMAIL_SIGN_IN } from "@/lib/config"
import { useSite } from "@/hooks/use-site"

const PERKS = [
  "Your callsign is yours: nobody else can host a battle under it",
  "Every battle you fight earns experience, more for a win, up fifty ranks from Recruit to General of the Army",
  "Each rank unlocks an insignia to wear beside your name",
  "Your service record: every battle you've fought, with its after-action report, in the game",
]

/**
 * /profile: your profile, the rank you've reached, your callsign and the
 * insignia you wear, and where signing in takes you. Signed out, it's the
 * way to sign in. It's the same account the game signs in to.
 */
export default function ProfilePage() {
  const { health } = useSite()
  const account = useAccount()
  const off = health?.accounts === "off"
  const user = off ? null : account.user
  usePageTitle(user ? "Your profile" : "Sign in")

  return (
    <div className="topo">
      <div className="mx-auto max-w-6xl px-4 pt-14 pb-24 sm:px-6">
        <SectionLabel>Profile</SectionLabel>
        <h1 className="mt-2 text-4xl font-semibold">{user ? "Your profile" : "Sign in to Frontline"}</h1>
        <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
          {user
            ? "Your rank, your callsign and the insignia you wear: the same in the game and on this site."
            : "One account for the game and this site. You don't need one to play, online or off."}
        </p>

        {off ? (
          <Card className="mt-8 max-w-md p-4 text-sm">
            <p className="font-medium">Accounts are switched off</p>
            <p className="text-xs leading-relaxed text-muted-foreground">
              The matchmaker isn't taking sign-ins right now. You can still play, online too, under any callsign.
            </p>
          </Card>
        ) : !user ? (
          <div className="mt-8 grid items-start gap-8 lg:grid-cols-[22rem_1fr]">
            <Card className="gap-0 py-0 text-sm">
              <SiteSignIn email={EMAIL_SIGN_IN} />
            </Card>
            <div>
              <h2 className="font-semibold">What an account gives you</h2>
              <ul className="mt-3 space-y-2.5 text-sm text-muted-foreground">
                {PERKS.map((p) => (
                  <li key={p} className="flex items-start gap-2">
                    <CheckIcon weight="bold" className="mt-0.5 size-4 shrink-0 text-good" />
                    {p}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        ) : (
          <div className="mt-8 grid items-start gap-8 lg:grid-cols-[19rem_1fr]">
            <div className="lg:sticky lg:top-20">
              <Profile user={user} />
            </div>
            <div className="min-w-0 space-y-12">
              <CallsignForm key={user.id} user={user} />
              <section aria-labelledby="your-insignia">
                <h2 id="your-insignia" className="text-xl font-semibold">
                  Your insignia
                </h2>
                <p className="mt-1 mb-6 text-sm text-muted-foreground">
                  Pick one you've unlocked to wear it, here and in the game. Every rank you reach unlocks another.
                </p>
                <Collection user={user} onPick={account.setIcon} />
              </section>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

function CallsignForm({ user }: { user: User }) {
  const { rename } = useAccount()
  const id = useId()
  const [name, setName] = useState(user.callsign)
  const [saving, setSaving] = useState(false)
  const [result, setResult] = useState<{ ok: boolean; text: string } | null>(null)
  const changed = name.trim() !== user.callsign

  const submit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (saving || !changed) return
    setSaving(true)
    setResult(null)
    const err = await rename(name)
    setSaving(false)
    setResult(
      err
        ? { ok: false, text: err }
        : { ok: true, text: `You're ${name.trim()} now. The game picks it up the next time it starts.` }
    )
  }

  return (
    <section aria-labelledby={`${id}-title`}>
      <h2 id={`${id}-title`} className="text-xl font-semibold">
        Callsign
      </h2>
      <Card className="mt-3 gap-3 p-4 text-sm">
        <form onSubmit={submit} className="flex flex-wrap items-end gap-3">
          <div className="min-w-48 flex-1 space-y-1.5">
            <Label htmlFor={`${id}-callsign`}>Your callsign</Label>
            <Input
              id={`${id}-callsign`}
              autoComplete="nickname"
              required
              minLength={3}
              maxLength={20}
              pattern="[A-Za-z0-9 _.\-]{3,20}"
              title="3 to 20 letters, digits, spaces, _ . or -"
              aria-describedby={`${id}-hint`}
              value={name}
              onChange={(e) => {
                setName(e.target.value)
                setResult(null)
              }}
            />
          </div>
          <Button type="submit" disabled={saving || !changed} className="h-9 px-4 font-semibold">
            {saving ? "Saving…" : "Save"}
          </Button>
        </form>
        <p id={`${id}-hint`} className="text-xs text-muted-foreground">
          3 to 20 letters, digits, spaces, _ . or -. It's the name beside the battles you host.
        </p>
        {result &&
          (result.ok ? (
            <output className="flex items-center gap-2 text-xs text-good">
              <CheckCircleIcon weight="fill" className="size-4 shrink-0" />
              {result.text}
            </output>
          ) : (
            <p role="alert" className="flex items-center gap-2 text-xs text-destructive">
              <WarningIcon className="size-4 shrink-0" />
              {result.text}
            </p>
          ))}
      </Card>
    </section>
  )
}
