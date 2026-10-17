import { CheckCircleIcon, CheckIcon, GithubLogoIcon, SignOutIcon, WarningIcon } from "@phosphor-icons/react"
import { useId, useState } from "react"
import { Link } from "react-router"
import { SiteSignIn } from "@/components/account-form"
import { SectionLabel } from "@/components/battles"
import { Collection, Profile } from "@/components/insignia"
import { PlayerAvatar } from "@/components/player-avatar"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { usePageTitle } from "@/hooks/use-page-title"
import { type User, useAccount } from "@/lib/account"
import { EMAIL_SIGN_IN } from "@/lib/config"
import { playerPath } from "@/lib/players"
import { cn } from "@/lib/utils"
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
              <PublicPage user={user} />
              <CallsignForm key={user.id} user={user} />
              <PictureChoice user={user} />
              <section aria-labelledby="your-insignia">
                <h2 id="your-insignia" className="text-xl font-semibold">
                  Your insignia
                </h2>
                <p className="mt-1 mb-6 text-sm text-muted-foreground">
                  Pick one you've unlocked to wear it, here and in the game. Every rank you reach unlocks another.
                </p>
                <Collection user={user} onPick={account.setIcon} />
              </section>
              <Sessions />
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

/** A change to the profile on its way, and what came of it. */
function useChange() {
  const { changeProfile } = useAccount()
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const change = async (c: Parameters<typeof changeProfile>[0]) => {
    setSaving(true)
    setError(null)
    setError(await changeProfile(c))
    setSaving(false)
  }
  return { saving, error, change }
}

function Problem({ text }: { text: string | null }) {
  if (!text) return null
  return (
    <p role="alert" className="flex items-center gap-2 text-xs text-destructive">
      <WarningIcon className="size-4 shrink-0" />
      {text}
    </p>
  )
}

/** Their page as everyone else sees it, and whether their battles are on it. */
function PublicPage({ user }: { user: User }) {
  const { saving, error, change } = useChange()
  const id = useId()
  return (
    <section aria-labelledby={`${id}-title`}>
      <h2 id={`${id}-title`} className="text-xl font-semibold">
        Your public page
      </h2>
      <Card className="mt-3 gap-3 p-4 text-sm">
        <p className="text-muted-foreground">
          Anyone can see your rank, experience and record, and your place on the leaderboards.{" "}
          <Link to={playerPath(user.callsign)} className="text-foreground underline underline-offset-4">
            See your page as they do
          </Link>
          .
        </p>
        <div className="flex items-start gap-3">
          <input
            id={`${id}-show`}
            type="checkbox"
            className="mt-0.5 size-4 shrink-0 accent-primary"
            checked={!user.hide_history}
            disabled={saving}
            aria-describedby={`${id}-show-note`}
            onChange={(e) => void change({ hide_history: !e.target.checked })}
          />
          <div>
            <label htmlFor={`${id}-show`} className="font-medium">
              Show my battles
            </label>
            <p id={`${id}-show-note`} className="text-xs text-muted-foreground">
              Every battle you fight signed in, with its after-action report, and your career totals. Turn it off and
              they're yours alone: the game still shows you your service record.
            </p>
          </div>
        </div>
        <Problem text={error} />
      </Card>
    </section>
  )
}

/** Their picture: their insignia, or the one on their GitHub account. */
function PictureChoice({ user }: { user: User }) {
  const { saving, error, change } = useChange()
  const id = useId()
  const options = [
    { value: "insignia", label: "Your insignia", note: "The patch you wear, as the game shows it.", picture: null },
    {
      value: "github",
      label: "Your GitHub picture",
      note: user.github_avatar ? "The picture on your GitHub account." : "For accounts signed in with GitHub.",
      picture: user.github_avatar,
    },
  ] as const
  return (
    <section aria-labelledby={`${id}-title`}>
      <h2 id={`${id}-title`} className="text-xl font-semibold">
        Picture
      </h2>
      <p className="mt-1 text-sm text-muted-foreground">
        Shown beside your callsign on this site: on the leaderboards and your page.
      </p>
      <fieldset className="mt-3 grid gap-3 sm:grid-cols-2" disabled={saving}>
        <legend className="sr-only">Your picture</legend>
        {options.map((o) => {
          const off = o.value === "github" && !user.github_avatar
          return (
            <label
              key={o.value}
              className={cn(
                "flex items-center gap-3 border bg-card p-3 text-sm transition-colors",
                user.avatar === o.value ? "border-primary ring-1 ring-primary" : "hover:bg-muted/50",
                off && "opacity-60"
              )}
            >
              <input
                type="radio"
                name={`${id}-picture`}
                value={o.value}
                className="size-4 shrink-0 accent-primary"
                checked={user.avatar === o.value}
                disabled={off}
                onChange={() => void change({ avatar: o.value })}
              />
              {off ? (
                <span className="grid size-10 shrink-0 place-items-center bg-muted">
                  <GithubLogoIcon className="size-5 text-muted-foreground" />
                </span>
              ) : (
                <PlayerAvatar icon={user.icon} avatar={o.picture} className="size-10" />
              )}
              <span className="min-w-0">
                <span className="font-medium">{o.label}</span>
                <span className="block text-xs text-muted-foreground">{o.note}</span>
              </span>
            </label>
          )
        })}
      </fieldset>
      <div className="mt-2">
        <Problem text={error} />
      </div>
    </section>
  )
}

function Sessions() {
  const { signOutEverywhere } = useAccount()
  return (
    <section aria-labelledby="sessions">
      <h2 id="sessions" className="text-xl font-semibold">
        Signed in elsewhere
      </h2>
      <Card className="mt-3 flex-row flex-wrap items-center justify-between gap-3 p-4 text-sm">
        <p className="max-w-md text-muted-foreground">
          Your account stays signed in in each game and browser you've used it in. Lost track of one? Sign out of all of
          them, this one too.
        </p>
        <Button variant="outline" onClick={signOutEverywhere}>
          <SignOutIcon />
          Sign out everywhere
        </Button>
      </Card>
    </section>
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
