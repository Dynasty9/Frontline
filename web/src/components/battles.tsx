import {
  CrosshairIcon,
  EnvelopeSimpleOpenIcon,
  InfoIcon,
  LockSimpleIcon,
  SealCheckIcon,
  WarningIcon,
  XIcon,
} from "@phosphor-icons/react"
import { useEffect, useState } from "react"
import { Link } from "react-router"
import { Emblem } from "@/components/emblem"
import { InsigniaImg } from "@/components/insignia-img"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import { FIND_MATCH_LINK, joinLink } from "@/lib/config"
import { findInsignia, rankName } from "@/lib/insignia"
import { joinable, type Lobby } from "@/lib/matchmaker"
import { playerPath } from "@/lib/players"
import { cn } from "@/lib/utils"

// Battles you can join first; within each, the matchmaker's order (fullest first).
const byJoinable = (a: Lobby, b: Lobby) => Number(joinable(b)) - Number(joinable(a))

type Props = {
  lobbies: Lobby[] | undefined
  error: Error | null
  updatedAt: number | null
  launched: boolean
  onLaunch: () => void
  onDismissLaunch: () => void
  // the battle an invite link (?join=ID) points at
  invite?: string | null
  onDismissInvite?: () => void
  /** the page's own heading (the battles page), rather than a section's */
  page?: boolean
}

export function Battles({
  lobbies,
  error,
  updatedAt,
  launched,
  onLaunch,
  onDismissLaunch,
  invite = null,
  onDismissInvite = () => {},
  page = false,
}: Props) {
  const Heading = page ? "h1" : "h2"
  return (
    <section id="battles" className={cn("mx-auto max-w-6xl scroll-mt-16 px-4 sm:px-6", page ? "pt-14 pb-24" : "py-24")}>
      <SectionLabel>Online</SectionLabel>
      <div className="mt-2 flex flex-wrap items-end justify-between gap-4">
        <div>
          <Heading className="mt-1 font-display text-5xl leading-[0.95] font-extrabold uppercase sm:text-6xl">
            Live battles. <span className="text-primary">Join in a click.</span>
          </Heading>
          <p className="mt-4 max-w-2xl text-sm text-muted-foreground">
            Choose a battle and join it in the desktop game. Play co-op, take on another commander, or follow a friend’s
            invite. No account required.
          </p>
        </div>
        <Updated at={updatedAt} failing={!!error && !!lobbies} />
      </div>

      <p className="mt-4 text-sm text-muted-foreground">
        New here?{" "}
        <Link to="/play#download" className="text-foreground underline underline-offset-4">
          Download Frontline
        </Link>{" "}
        and start it once before joining. To host, open the game and choose Host a Battle.
      </p>

      {invite && !launched && (
        <Invite
          lobby={lobbies?.find((l) => l.id === invite)}
          loaded={!!lobbies}
          onLaunch={onLaunch}
          onDismiss={onDismissInvite}
        />
      )}

      {launched && (
        <Alert className="mt-6 border-primary/40 bg-primary/5">
          <InfoIcon />
          <AlertTitle>Opening Frontline…</AlertTitle>
          <AlertDescription>
            Your browser may ask whether to open the game. If nothing happens,{" "}
            <Link to="/play#download" className="text-foreground underline underline-offset-4">
              download Frontline
            </Link>{" "}
            and start it once: the first launch teaches your computer to open these links.
          </AlertDescription>
          <button
            type="button"
            onClick={onDismissLaunch}
            className="absolute top-2.5 right-2.5 text-muted-foreground hover:text-foreground"
            aria-label="Dismiss"
          >
            <XIcon className="size-4" />
          </button>
        </Alert>
      )}

      <Card className="mt-6 gap-0 py-0 text-sm">
        {error && !lobbies ? (
          <Unreachable />
        ) : !lobbies ? (
          <Loading />
        ) : lobbies.length === 0 ? (
          <Empty onLaunch={onLaunch} />
        ) : (
          <LobbyRows lobbies={lobbies.toSorted(byJoinable)} invite={invite} onLaunch={onLaunch} />
        )}
      </Card>
    </section>
  )
}

export function SectionLabel({ children }: { children: React.ReactNode }) {
  return <p className="text-xs font-bold tracking-[0.2em] text-primary uppercase">{children}</p>
}

// A friend sent a link to their battle: say what it is, with a Join button.
function Invite({
  lobby,
  loaded,
  onLaunch,
  onDismiss,
}: {
  lobby: Lobby | undefined
  loaded: boolean
  onLaunch: () => void
  onDismiss: () => void
}) {
  if (!loaded) return null
  return (
    <Alert className={`mt-6 ${lobby ? "border-primary/40 bg-primary/5" : ""}`}>
      <EnvelopeSimpleOpenIcon />
      {lobby ? (
        <>
          <AlertTitle>
            {lobby.host} invited you to {lobby.name}
          </AlertTitle>
          <AlertDescription>
            <p>
              {modeText(lobby)} · {lobby.players}/{lobby.max_players} players
              {lobby.locked ? " · ask them for the password" : ""}. Join opens Frontline and takes you straight to their
              lobby. No game yet?{" "}
              <Link to="/play#download" className="text-foreground underline underline-offset-4">
                Download it
              </Link>{" "}
              and start it once first.
            </p>
            <div className="mt-3">
              {joinable(lobby) ? (
                <Button asChild className="font-semibold">
                  <a href={joinLink(lobby.id)} onClick={onLaunch}>
                    Join {lobby.host}'s battle
                  </a>
                </Button>
              ) : (
                <Button variant="outline" disabled>
                  {lobby.players >= lobby.max_players ? "It's full" : "It's under way, and closed to newcomers"}
                </Button>
              )}
            </div>
          </AlertDescription>
        </>
      ) : (
        <>
          <AlertTitle>That battle has ended</AlertTitle>
          <AlertDescription>
            The battle your invite points to isn't being hosted any more. Ask your friend to host again, or join another
            one below.
          </AlertDescription>
        </>
      )}
      <button
        type="button"
        onClick={onDismiss}
        className="absolute top-2.5 right-2.5 text-muted-foreground hover:text-foreground"
        aria-label="Dismiss"
      >
        <XIcon className="size-4" />
      </button>
    </Alert>
  )
}

const SIDES = ["Coalition", "Rebels"]

/** "Co-op vs AI · Coalition", "Versus · 2 v 1", "Mission · Bridgehead" */
function modeText(l: Lobby): string {
  switch (l.mode) {
    case "coop":
      return `Co-op vs AI · ${SIDES[l.side === 1 ? 1 : 0]}`
    case "versus":
      return `Versus · ${l.teams?.[0] ?? 0} v ${l.teams?.[1] ?? 0}`
    case "mission":
      return l.mission ? `Mission · ${l.mission}` : "Mission"
    default:
      return "Battle"
  }
}

function LobbyRows({ lobbies, invite, onLaunch }: { lobbies: Lobby[]; invite: string | null; onLaunch: () => void }) {
  return (
    <Table>
      <TableHeader>
        <TableRow className="hover:bg-transparent">
          <TableHead className="pl-4">Battle</TableHead>
          <TableHead className="hidden lg:table-cell">Mode</TableHead>
          <TableHead className="hidden md:table-cell">Commander</TableHead>
          <TableHead>Players</TableHead>
          <TableHead className="hidden sm:table-cell">Status</TableHead>
          <TableHead className="pr-4 text-right">
            <span className="sr-only">Join</span>
          </TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {lobbies.map((l) => (
          <TableRow key={l.id} className={l.id === invite ? "bg-primary/5" : undefined}>
            <TableCell className="py-3 pl-4">
              <div className="flex items-center gap-1.5 font-medium text-foreground">
                {l.locked && (
                  <Tooltip>
                    <TooltipTrigger asChild>
                      <LockSimpleIcon weight="fill" className="size-3.5 shrink-0 text-warn" aria-label="Password" />
                    </TooltipTrigger>
                    <TooltipContent>The host has set a password: the game asks for it when you join</TooltipContent>
                  </Tooltip>
                )}
                {l.name}
              </div>
              <div className="mt-0.5 flex items-center gap-1 text-xs text-muted-foreground lg:hidden">
                <span>{modeText(l)}</span>
                <span className="md:hidden">
                  {" · "}
                  <Host lobby={l} />
                </span>
              </div>
            </TableCell>
            <TableCell className="hidden lg:table-cell">{modeText(l)}</TableCell>
            <TableCell className="hidden md:table-cell">
              <Host lobby={l} />
            </TableCell>
            <TableCell>
              <Players lobby={l} />
            </TableCell>
            <TableCell className="hidden sm:table-cell">
              <Status lobby={l} />
            </TableCell>
            <TableCell className="pr-4 text-right">
              {joinable(l) ? (
                <Button size="sm" asChild className="font-semibold">
                  <a href={joinLink(l.id)} onClick={onLaunch}>
                    Join
                  </a>
                </Button>
              ) : (
                <Button size="sm" variant="outline" disabled>
                  {l.players >= l.max_players ? "Full" : "Closed"}
                </Button>
              )}
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}

function Host({ lobby }: { lobby: Lobby }) {
  // only a signed-in host's insignia is theirs to show
  const ins = lobby.verified ? findInsignia(lobby.icon) : undefined
  const rank = typeof lobby.rank === "number" ? lobby.rank : null
  return (
    <span className="inline-flex items-center gap-1">
      {ins && (
        <Tooltip>
          <TooltipTrigger asChild>
            <span className="mr-0.5 inline-flex">
              <InsigniaImg id={ins.id} className="size-5" />
            </span>
          </TooltipTrigger>
          <TooltipContent>
            {rank === null ? ins.name : `${rankName(rank)}, rank ${rank} · wearing ${ins.name}`}
          </TooltipContent>
        </Tooltip>
      )}
      {/* a signed-in host's callsign is theirs: it leads to their page */}
      {lobby.verified ? (
        <Link to={playerPath(lobby.host)} className="hover:text-foreground hover:underline">
          {lobby.host}
        </Link>
      ) : (
        lobby.host
      )}
      {ins && rank !== null && <span className="sr-only">, {rankName(rank)}</span>}
      {lobby.verified && (
        <Tooltip>
          <TooltipTrigger asChild>
            <SealCheckIcon weight="fill" className="size-4 text-primary" aria-label="Signed-in account" />
          </TooltipTrigger>
          <TooltipContent>Signed in: this callsign belongs to their account</TooltipContent>
        </Tooltip>
      )}
    </span>
  )
}

function Players({ lobby }: { lobby: Lobby }) {
  const pct = Math.min(100, (lobby.players / Math.max(1, lobby.max_players)) * 100)
  return (
    <div className="flex items-center gap-2">
      <span className="w-9 tabular-nums">
        {lobby.players}/{lobby.max_players}
      </span>
      <span className="hidden h-1 w-16 bg-muted sm:block">
        <span className="block h-full bg-primary" style={{ width: `${pct}%` }} />
      </span>
    </div>
  )
}

function Status({ lobby }: { lobby: Lobby }) {
  return (
    <div className="flex flex-wrap items-center gap-1.5">
      {!lobby.in_game ? (
        <Badge variant="outline" className="border-good/40 text-good">
          In the lobby
        </Badge>
      ) : lobby.drop_in ? (
        <Badge variant="outline" className="border-primary/40 text-primary">
          In battle · drop-in
        </Badge>
      ) : (
        <Badge variant="outline" className="text-muted-foreground">
          In battle · closed
        </Badge>
      )}
      {lobby.nat === "strict" && (
        <Tooltip>
          <TooltipTrigger asChild>
            <Badge variant="outline" className="border-warn/40 text-warn">
              <WarningIcon />
              Strict router
            </Badge>
          </TooltipTrigger>
          <TooltipContent className="max-w-64">
            This host's router can't be punched through. You'll only get in if they've forwarded UDP port 7777.
          </TooltipContent>
        </Tooltip>
      )}
    </div>
  )
}

function Updated({ at, failing }: { at: number | null; failing: boolean }) {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    const t = window.setInterval(() => setNow(Date.now()), 1000)
    return () => window.clearInterval(t)
  }, [])
  if (!at) return null
  const s = Math.max(0, Math.round((now - at) / 1000))
  return (
    <p className="flex items-center gap-2 text-xs text-muted-foreground">
      <span className={`size-1.5 rounded-full ${failing ? "bg-warn" : "bg-good"}`} />
      {failing ? "Reconnecting… " : "Live · "}updated {s < 2 ? "just now" : `${s}s ago`}
    </p>
  )
}

function Loading() {
  return (
    <div className="space-y-3 p-4">
      {[0, 1, 2].map((i) => (
        <div key={i} className="flex items-center gap-4">
          <Skeleton className="h-4 flex-1" />
          <Skeleton className="h-4 w-20" />
          <Skeleton className="h-8 w-14" />
        </div>
      ))}
    </div>
  )
}

function Empty({ onLaunch }: { onLaunch: () => void }) {
  return (
    <div className="flex flex-col items-center px-6 py-14 text-center">
      <Emblem className="size-10 opacity-40" />
      <p className="mt-4 text-base font-medium">Nobody is hosting right now</p>
      <p className="mt-1 max-w-md text-sm text-muted-foreground">
        Press Find Match and you'll host a battle for the next player to find. It shows up here the moment you do.
      </p>
      <Button variant="outline" asChild className="mt-6">
        <a href={FIND_MATCH_LINK} onClick={onLaunch}>
          <CrosshairIcon weight="bold" />
          Find a match
        </a>
      </Button>
    </div>
  )
}

function Unreachable() {
  return (
    <div className="p-4">
      <Alert variant="destructive" className="border-destructive/30">
        <WarningIcon />
        <AlertTitle>Can't reach the matchmaker</AlertTitle>
        <AlertDescription>
          The list of battles will come back by itself. You can still play against the AI, or join a friend by their
          address from the game's Join Game screen.
        </AlertDescription>
      </Alert>
    </div>
  )
}
