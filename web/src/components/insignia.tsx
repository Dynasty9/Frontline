import { CheckIcon, LockSimpleIcon, SignOutIcon, WarningIcon } from "@phosphor-icons/react"
import { memo, useId, useRef, useState } from "react"
import { SectionLabel } from "@/components/battles"
import { InsigniaImg } from "@/components/insignia-img"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import { type User, useAccount } from "@/lib/account"
import {
  GROUPS,
  INSIGNIA,
  type Insignia,
  insigniaUrl,
  isUnlocked,
  MAX_RANK,
  nextUnlock,
  rankName,
  unlockText,
  wornInsignia,
} from "@/lib/insignia"
import { cn } from "@/lib/utils"

export function InsigniaSection({ accounts }: { accounts: string | undefined }) {
  const account = useAccount()
  const off = accounts === "off"
  const user = off ? null : account.user

  return (
    <section id="insignia" className="scroll-mt-16 border-t">
      <div className="mx-auto max-w-6xl px-4 py-20 sm:px-6">
        <SectionLabel>Ranks</SectionLabel>
        <h2 className="mt-2 text-3xl font-semibold">{user ? "Your insignia" : "Earn your insignia"}</h2>
        <p className="mt-2 max-w-2xl text-sm text-muted-foreground">
          Play battles while you're signed in to your account and you earn experience, more for a win. Fifty ranks climb
          from Recruit to General of the Army, and each one you reach unlocks a patch you can wear as your insignia,
          shown beside your callsign when you host. Every account starts with ten.
        </p>

        <div className="mt-8 grid items-start gap-8 lg:grid-cols-[19rem_1fr]">
          <div className="lg:sticky lg:top-20">
            {user ? <Profile user={user} /> : off ? <AccountsOff /> : <SignIn />}
          </div>
          <Collection user={user} onPick={account.setIcon} />
        </div>
      </div>
    </section>
  )
}

function Profile({ user }: { user: User }) {
  const { error, signOut } = useAccount()
  const worn = wornInsignia(user.icon)
  const top = user.next_xp === null || user.rank >= MAX_RANK
  const span = top ? 1 : Math.max(1, (user.next_xp ?? 0) - user.rank_xp)
  const into = top ? 1 : Math.min(span, Math.max(0, user.xp - user.rank_xp))
  const next = nextUnlock(user.rank)

  return (
    <Card className="gap-0 py-0 text-sm">
      <div className="flex items-center gap-4 p-4">
        <div className="relative grid size-24 shrink-0 place-items-center bg-muted/60 ring-1 ring-white/10">
          <Corners />
          {worn && <InsigniaImg id={worn.id} className="size-20" />}
        </div>
        <div className="min-w-0">
          <p className="truncate text-xl font-semibold">{user.callsign || "Commander"}</p>
          <p className="mt-1 text-xs font-bold tracking-[0.14em] text-primary uppercase">{rankName(user.rank)}</p>
          <p className="mt-0.5 text-xs text-muted-foreground">
            Rank {user.rank} of {MAX_RANK}
          </p>
          {worn && <p className="mt-2 truncate text-xs text-muted-foreground">Wearing {worn.name}</p>}
        </div>
      </div>

      <div className="border-t px-4 py-3">
        <div className="flex items-baseline justify-between gap-3 text-xs">
          <span className="text-muted-foreground">{top ? "Max rank" : `Next: ${rankName(user.rank + 1)}`}</span>
          <span className="tabular-nums">
            {top ? `${user.xp.toLocaleString()} XP` : `${into.toLocaleString()} / ${span.toLocaleString()} XP`}
          </span>
        </div>
        {/* a real <progress> for screen readers; the bar is drawn, so it animates */}
        <progress
          className="sr-only"
          aria-label={top ? "Max rank" : `Experience towards ${rankName(user.rank + 1)}`}
          max={span}
          value={into}
        />
        <div aria-hidden="true" className="mt-2 h-1.5 bg-muted">
          <div
            className="h-full bg-primary transition-[width] duration-500"
            style={{ width: `${(into / span) * 100}%` }}
          />
        </div>
      </div>

      <dl className="grid grid-cols-2 border-t">
        <Stat label="Battles" value={user.battles} />
        <Stat label="Wins" value={user.wins} className="border-l" />
      </dl>

      {next && (
        <div className="flex items-center gap-3 border-t px-4 py-3">
          <div className="grid size-9 shrink-0 place-items-center bg-muted/60 ring-1 ring-white/10">
            <InsigniaImg id={next.id} className="size-7 opacity-40 grayscale" />
          </div>
          <p className="text-xs text-muted-foreground">
            Rank {next.unlock} unlocks <span className="text-foreground">{next.name}</span>
          </p>
        </div>
      )}

      {error && (
        <p role="alert" className="flex items-center gap-2 border-t px-4 py-2.5 text-xs text-destructive">
          <WarningIcon className="size-4 shrink-0" />
          {error}
        </p>
      )}

      <div className="flex items-center justify-between gap-3 border-t py-1.5 pr-1.5 pl-4 text-xs text-muted-foreground">
        <span className="truncate">{user.email}</span>
        <Button variant="ghost" size="sm" onClick={signOut} className="shrink-0">
          <SignOutIcon />
          Sign out
        </Button>
      </div>
    </Card>
  )
}

function Stat({ label, value, className }: { label: string; value: number; className?: string }) {
  return (
    <div className={cn("px-4 py-3", className)}>
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="mt-0.5 text-lg font-semibold tabular-nums">{value.toLocaleString()}</dd>
    </div>
  )
}

/** Amber corner marks, the HUD's target frame, round the insignia being worn. */
function Corners() {
  const c = "pointer-events-none absolute size-3 border-primary"
  return (
    <>
      <span className={`${c} top-0 left-0 border-t-2 border-l-2`} />
      <span className={`${c} top-0 right-0 border-t-2 border-r-2`} />
      <span className={`${c} bottom-0 left-0 border-b-2 border-l-2`} />
      <span className={`${c} right-0 bottom-0 border-r-2 border-b-2`} />
    </>
  )
}

function SignIn() {
  const { busy, error, notice, signIn, signUp, clearError } = useAccount()
  const [creating, setCreating] = useState(false)
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [callsign, setCallsign] = useState("")
  const id = useId()

  const switchTo = (c: boolean) => {
    setCreating(c)
    clearError()
  }

  const submit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    if (busy) return
    if (!creating) {
      if (await signIn(email, password)) setPassword("")
      return
    }
    const r = await signUp(email, password, callsign)
    if (r) setPassword("")
    if (r === "confirm") setCreating(false)
  }

  return (
    <Card className="gap-0 py-0 text-sm">
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
        <p className="text-xs leading-relaxed text-muted-foreground">
          {creating
            ? "The account works here and in the game. It keeps your callsign yours, and every battle you play signed in counts towards your rank."
            : "The same account you sign in with in the game. You don't need one to play online."}
        </p>
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

        {error && (
          <p role="alert" className="flex items-start gap-2 text-xs text-destructive">
            <WarningIcon className="mt-px size-4 shrink-0" />
            {error}
          </p>
        )}
        {notice && !error && <output className="block text-xs text-good">{notice}</output>}

        <Button type="submit" disabled={busy} className="h-9 w-full text-sm font-semibold">
          {busy ? (creating ? "Creating your account…" : "Signing in…") : creating ? "Create account" : "Sign in"}
        </Button>
      </form>
    </Card>
  )
}

function AccountsOff() {
  return (
    <Card className="p-4 text-sm">
      <p className="font-medium">Accounts are switched off</p>
      <p className="text-xs leading-relaxed text-muted-foreground">
        The matchmaker isn't taking sign-ins right now, so there are no ranks to earn for the moment. This is the
        collection every new account starts with.
      </p>
    </Card>
  )
}

function Collection({ user, onPick }: { user: User | null; onPick: (id: string) => void }) {
  // a visitor sees what a brand-new account would
  const rank = user?.rank ?? 0
  const wearing = user ? wornInsignia(user.icon)?.id : undefined

  return (
    <div className="space-y-10">
      {GROUPS.map((g) => {
        const items = INSIGNIA.filter((i) => i.group === g.key)
        if (items.length === 0) return null
        const have = items.filter((i) => isUnlocked(i, rank)).length
        return (
          <section key={g.key} aria-labelledby={`insignia-${g.key}`}>
            <div className="flex flex-wrap items-end justify-between gap-x-4 gap-y-1">
              <div className="min-w-0">
                <h3 id={`insignia-${g.key}`} className="font-semibold">
                  {g.title}
                </h3>
                <p className="mt-0.5 text-xs text-muted-foreground">{g.blurb}</p>
              </div>
              <p className="text-xs text-muted-foreground tabular-nums">
                <span className={have > 0 ? "font-semibold text-primary" : undefined}>{have}</span> / {items.length}{" "}
                unlocked
              </p>
            </div>
            <div className="mt-2 h-0.5 bg-border">
              <div className="h-full bg-primary/80" style={{ width: `${(have / items.length) * 100}%` }} />
            </div>
            <ul className="mt-3 grid grid-cols-5 gap-1.5 sm:grid-cols-10">
              {items.map((i) => (
                <li key={i.id}>
                  <Tile
                    ins={i}
                    unlocked={isUnlocked(i, rank)}
                    selectable={!!user && isUnlocked(i, rank)}
                    selected={i.id === wearing}
                    signedIn={!!user}
                    onPick={onPick}
                  />
                </li>
              ))}
            </ul>
          </section>
        )
      })}
    </div>
  )
}

type TileProps = {
  ins: Insignia
  unlocked: boolean
  selectable: boolean
  selected: boolean
  signedIn: boolean
  onPick: (id: string) => void
}

const Tile = memo(function Tile({ ins, unlocked, selectable, selected, signedIn, onPick }: TileProps) {
  // Controlled, so a tap can open it: a phone has no hover, and the name and
  // what unlocks it are the whole point of looking.
  const [open, setOpen] = useState(false)
  const pointer = useRef("")

  const status = selected
    ? "Wearing it"
    : signedIn && unlocked
      ? ins.unlock > 0
        ? `Unlocked at rank ${ins.unlock}: pick it to wear it`
        : "Unlocked: pick it to wear it"
      : unlockText(ins)

  return (
    <Tooltip open={open} onOpenChange={setOpen}>
      <TooltipTrigger asChild>
        <button
          type="button"
          aria-label={`${ins.name}. ${status}`}
          aria-pressed={selectable ? selected : undefined}
          aria-disabled={selectable ? undefined : true}
          onPointerDown={(e) => {
            pointer.current = e.pointerType
          }}
          onClick={(e) => {
            // keep the tooltip up after a pick (it then says "Wearing it"), and show it on a tap
            e.preventDefault()
            if (e.detail > 0 && pointer.current !== "mouse") setOpen(true)
            if (selectable) onPick(ins.id)
          }}
          className={cn(
            "group relative block aspect-square w-full overflow-hidden bg-muted/50 bg-[radial-gradient(circle_at_50%_38%,rgb(255_255_255/0.07),transparent_68%)] ring-1 ring-white/[0.07] transition-[background-color,box-shadow] ring-inset focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring",
            selectable ? "hover:bg-accent hover:ring-primary/50" : "cursor-default",
            selected && "bg-primary/10 ring-2 ring-primary hover:ring-primary"
          )}
        >
          <img
            src={insigniaUrl(ins.id)}
            alt=""
            loading="lazy"
            width={128}
            height={128}
            draggable={false}
            className={cn(
              "size-full object-contain p-[12%] transition-[opacity,filter,transform] duration-200",
              unlocked ? (selectable ? "group-hover:scale-105" : "") : "opacity-25 grayscale"
            )}
          />
          {selected && (
            <span className="absolute top-0 left-0 grid size-4 place-items-center bg-primary text-primary-foreground">
              <CheckIcon weight="bold" className="size-3" />
            </span>
          )}
          {!unlocked && (
            <LockSimpleIcon weight="fill" className="absolute top-1 right-1 size-3 text-muted-foreground" />
          )}
          {!unlocked && ins.unlock > 0 && (
            <span className="absolute inset-x-0 bottom-0 bg-background/70 py-px text-center text-[10px] font-semibold tracking-wide text-muted-foreground uppercase tabular-nums">
              Rank {ins.unlock}
            </span>
          )}
        </button>
      </TooltipTrigger>
      <TooltipContent
        side="top"
        sideOffset={4}
        collisionPadding={8}
        className="max-w-60 flex-col items-start gap-0.5 py-2"
      >
        <span className="text-[13px] font-semibold">{ins.name}</span>
        {ins.blurb && <span className="text-xs/snug opacity-75">{ins.blurb}</span>}
        <span className="mt-1 text-[11px] font-semibold tracking-wide uppercase">{status}</span>
      </TooltipContent>
    </Tooltip>
  )
})
