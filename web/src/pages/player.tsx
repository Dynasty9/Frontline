import { EyeSlashIcon, PencilSimpleIcon, UserCircleDashedIcon, WarningIcon } from "@phosphor-icons/react"
import { useInfiniteQuery, useQuery } from "@tanstack/react-query"
import { Link, useParams } from "react-router"
import { CommandersNav } from "@/components/commanders-nav"
import { SectionLabel } from "@/components/battles"
import { Corners, XpProgress } from "@/components/insignia"
import { PlayerSearch } from "@/components/leaderboard"
import { PlayerAvatar } from "@/components/player-avatar"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { usePageTitle } from "@/hooks/use-page-title"
import { pictureOf, useAccount } from "@/lib/account"
import { MAX_RANK, rankName } from "@/lib/insignia"
import {
  type BattleHead,
  battlePath,
  type Career,
  fetchBattles,
  fetchCareer,
  fetchPlayer,
  formatDay,
  formatDuration,
  type Mode,
  MODE_NAMES,
  type PublicPlayer,
  SIDE_NAMES,
  timeAgo,
  winRate,
} from "@/lib/players"
import { ratingWord } from "@/lib/report"
import { cn } from "@/lib/utils"

/**
 * /player/:callsign: a commander's public page. Their rank and record, which
 * only the accounts database writes; and, unless they keep them to
 * themselves, their career and every battle on it, each with its
 * after-action report, which are their own game's word.
 */
export default function PlayerPage() {
  const { callsign = "" } = useParams()
  const { user } = useAccount()
  const player = useQuery({
    queryKey: ["player", callsign.toLowerCase()],
    queryFn: ({ signal }) => fetchPlayer(callsign, signal),
  })
  usePageTitle(player.data?.callsign ?? callsign)
  const you = !!user && !!player.data && user.callsign.toLowerCase() === player.data.callsign.toLowerCase()
  // Your own page: your picture and whether your battles show as you've just
  // set them (everyone else sees the change within the half minute the
  // matchmaker keeps a page for).
  const p =
    you && user && player.data
      ? {
          ...player.data,
          icon: user.icon ?? player.data.icon,
          avatar: pictureOf(user),
          history: !user.hide_history,
        }
      : player.data

  return (
    <div className="topo">
      <CommandersNav />
      <div className="mx-auto max-w-6xl px-4 pt-14 pb-24 sm:px-6">
        <SectionLabel>Commander</SectionLabel>
        {player.isPending ? (
          <Card className="mt-3 flex-row items-center gap-5 p-6">
            <Skeleton className="size-28" />
            <div className="flex-1 space-y-3">
              <Skeleton className="h-9 w-56" />
              <Skeleton className="h-4 w-40" />
            </div>
          </Card>
        ) : player.isError ? (
          <Alert variant="destructive" className="mt-3 border-destructive/30">
            <WarningIcon />
            <AlertTitle>This page didn't load</AlertTitle>
            <AlertDescription>The matchmaker didn't answer. Try again in a moment.</AlertDescription>
          </Alert>
        ) : !p ? (
          <NoSuchPlayer callsign={callsign} />
        ) : (
          <>
            <Header player={p} you={you} />
            {p.history ? (
              <>
                <CareerTiles callsign={p.callsign} />
                <Battles callsign={p.callsign} />
              </>
            ) : (
              <Card className="mt-10 flex-row items-center gap-3 p-5 text-sm text-muted-foreground">
                <EyeSlashIcon className="size-5 shrink-0" />
                {you ? (
                  <span>
                    You keep your battles to yourself, so nobody else sees them here.{" "}
                    <Link to="/profile" className="text-foreground underline underline-offset-4">
                      Show them
                    </Link>
                  </span>
                ) : (
                  `${p.callsign} keeps their battles to themselves.`
                )}
              </Card>
            )}
          </>
        )}
      </div>
    </div>
  )
}

function Header({ player: p, you }: { player: PublicPlayer; you: boolean }) {
  return (
    <Card className="mt-3 gap-0 py-0 text-sm">
      <div className="flex flex-wrap items-center gap-5 p-5 sm:p-6">
        <div className="relative grid size-28 shrink-0 place-items-center bg-muted/60 ring-1 ring-white/10">
          <Corners />
          <PlayerAvatar icon={p.icon} avatar={p.avatar} className="size-24" />
        </div>
        <div className="min-w-0 flex-1">
          <h1 className="truncate text-4xl font-semibold">{p.callsign}</h1>
          <p className="mt-1 text-xs font-bold tracking-[0.14em] text-primary uppercase">
            {rankName(p.rank)} · rank {p.rank} of {MAX_RANK}
          </p>
          <p className="mt-2 text-xs text-muted-foreground">
            {p.joined && <>Enlisted {formatDay(p.joined)}</>}
            {p.joined && p.last_seen && " · "}
            {p.last_seen && (
              <span title={new Date(p.last_seen).toLocaleString()}>last in battle {timeAgo(p.last_seen)}</span>
            )}
          </p>
        </div>
        {you && (
          <Button asChild variant="outline" size="sm">
            <Link to="/profile">
              <PencilSimpleIcon />
              Edit your profile
            </Link>
          </Button>
        )}
      </div>
      <XpProgress {...p} className="border-t px-5 sm:px-6" />
      <dl className="grid grid-cols-2 border-t sm:grid-cols-4">
        <Stat label="All-time place">
          {p.position ? (
            <Link to="/leaderboards" className="hover:underline">
              #{p.position.toLocaleString()}
            </Link>
          ) : (
            "-"
          )}
        </Stat>
        <Stat label="Experience" className="border-l">
          {p.xp.toLocaleString()} XP
        </Stat>
        <Stat label="Battles won" className="border-t sm:border-t-0 sm:border-l">
          {p.wins.toLocaleString()} of {p.battles.toLocaleString()}
        </Stat>
        <Stat label="Win rate" className="border-t border-l sm:border-t-0">
          {winRate(p.wins, p.battles)}
        </Stat>
      </dl>
    </Card>
  )
}

function Stat({ label, className, children }: { label: string; className?: string; children: React.ReactNode }) {
  return (
    <div className={cn("px-5 py-3 sm:px-6", className)}>
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="mt-0.5 text-lg font-semibold tabular-nums">{children}</dd>
    </div>
  )
}

const favourite = (c: Career) =>
  (Object.entries(c.modes) as [Mode, number][]).toSorted((a, b) => b[1] - a[1])[0]?.[0] ?? null

function CareerTiles({ callsign }: { callsign: string }) {
  const career = useQuery({
    queryKey: ["career", callsign.toLowerCase()],
    queryFn: ({ signal }) => fetchCareer(callsign, signal),
  })
  const c = career.data
  if (career.isError) return null
  const fav = c ? favourite(c) : null
  const tiles: [string, React.ReactNode][] = c
    ? [
        ["Battles on record", c.battles.toLocaleString()],
        ["Victories", `${c.victories.toLocaleString()} (${winRate(c.victories, c.battles)})`],
        ["Enemy killed", c.kills.toLocaleString()],
        ["Kills per man lost", c.lost > 0 ? (c.kills / c.lost).toFixed(1) : c.kills.toLocaleString()],
        ["Vehicles destroyed", c.veh_kills.toLocaleString()],
        ["Accuracy", c.shots > 0 ? `${Math.round((100 * c.hits) / c.shots)}%` : "-"],
        ["Average rating", c.battles ? `${Math.round(c.rating)} · ${ratingWord(c.rating)}` : "-"],
        ["Time in battle", formatDuration(c.seconds)],
        ["Plays most", fav ? MODE_NAMES[fav] : "-"],
      ]
    : []

  return (
    <section aria-labelledby="career" className="mt-12">
      <h2 id="career" className="text-xl font-semibold">
        Career
      </h2>
      <p className="mt-1 text-sm text-muted-foreground">
        Totalled from the after-action reports {callsign}'s game sent in.
      </p>
      {career.isPending ? (
        <Skeleton className="mt-4 h-40" />
      ) : !c || c.battles === 0 ? (
        <p className="mt-4 text-sm text-muted-foreground">No battles on the record yet.</p>
      ) : (
        <>
          <dl className="mt-4 grid grid-cols-2 gap-px overflow-hidden border bg-border sm:grid-cols-3">
            {tiles.map(([label, value]) => (
              <div key={label} className="bg-card px-4 py-3">
                <dt className="text-xs text-muted-foreground">{label}</dt>
                <dd className="mt-0.5 text-lg font-semibold tabular-nums">{value}</dd>
              </div>
            ))}
          </dl>
          {c.best && (
            <p className="mt-3 text-sm text-muted-foreground">
              Best battle:{" "}
              <Link to={battlePath(callsign, c.best.id)} className="text-foreground underline underline-offset-4">
                {c.best.title}
              </Link>
              , {formatDay(c.best.played_at)}, rated {Math.round(c.best.rating)}.
            </p>
          )}
        </>
      )}
    </section>
  )
}

function Battles({ callsign }: { callsign: string }) {
  const battles = useInfiniteQuery({
    queryKey: ["battles", callsign.toLowerCase()],
    queryFn: ({ pageParam, signal }) => fetchBattles(callsign, pageParam, signal),
    initialPageParam: null as string | null,
    getNextPageParam: (last) => (last.more ? (last.battles.at(-1)?.played_at ?? null) : null),
  })
  const rows = battles.data?.pages.flatMap((p) => p.battles) ?? []

  return (
    <section aria-labelledby="battles-fought" className="mt-12">
      <h2 id="battles-fought" className="text-xl font-semibold">
        Battles
      </h2>
      <Card className="mt-4 gap-0 py-0 text-sm">
        {battles.isPending ? (
          <div className="space-y-3 p-4">
            {[0, 1, 2].map((i) => (
              <Skeleton key={i} className="h-5" />
            ))}
          </div>
        ) : battles.isError ? (
          <p className="p-4 text-sm text-destructive">The battles didn't load. Try again in a moment.</p>
        ) : rows.length === 0 ? (
          <p className="p-4 text-sm text-muted-foreground">No battles on the record yet.</p>
        ) : (
          <BattleTable callsign={callsign} rows={rows} />
        )}
      </Card>
      {battles.hasNextPage && (
        <Button
          variant="outline"
          className="mt-4"
          disabled={battles.isFetchingNextPage}
          onClick={() => void battles.fetchNextPage()}
        >
          {battles.isFetchingNextPage ? "Loading…" : "Older battles"}
        </Button>
      )}
    </section>
  )
}

export function ResultBadge({ result }: { result: BattleHead["result"] }) {
  return result === "victory" ? (
    <Badge variant="outline" className="border-good/40 text-good">
      Victory
    </Badge>
  ) : (
    <Badge variant="outline" className="border-destructive/40 text-destructive">
      Defeat
    </Badge>
  )
}

function BattleTable({ callsign, rows }: { callsign: string; rows: BattleHead[] }) {
  return (
    <Table>
      <TableHeader>
        <TableRow className="hover:bg-transparent">
          <TableHead className="pl-4">Battle</TableHead>
          <TableHead>Result</TableHead>
          <TableHead className="hidden sm:table-cell">Side</TableHead>
          <TableHead className="hidden text-right md:table-cell">Length</TableHead>
          <TableHead className="hidden text-right md:table-cell">Killed / lost</TableHead>
          <TableHead className="pr-4 text-right">Rating</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {rows.map((b) => (
          <TableRow key={b.id}>
            <TableCell className="py-2.5 pl-4">
              <Link to={battlePath(callsign, b.id)} className="font-medium text-foreground hover:underline">
                {b.title || MODE_NAMES[b.mode]}
              </Link>
              <span className="block text-xs text-muted-foreground" title={new Date(b.played_at).toLocaleString()}>
                {/* the title says what kind of battle, but a mission's is only its name */}
                {b.mode === "mission" ? "Mission · " : ""}
                {timeAgo(b.played_at)}
              </span>
            </TableCell>
            <TableCell>
              <ResultBadge result={b.result} />
            </TableCell>
            <TableCell className="hidden sm:table-cell">{SIDE_NAMES[b.side]}</TableCell>
            <TableCell className="hidden text-right tabular-nums md:table-cell">
              {formatDuration(b.duration_s)}
            </TableCell>
            <TableCell className="hidden text-right tabular-nums md:table-cell">
              {b.kills.toLocaleString()} / {b.lost.toLocaleString()}
            </TableCell>
            <TableCell className="pr-4 text-right font-semibold tabular-nums">{Math.round(b.rating)}</TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}

function NoSuchPlayer({ callsign }: { callsign: string }) {
  return (
    <div className="mt-3 flex flex-col items-start">
      <h1 className="font-display text-5xl leading-[0.95] font-extrabold uppercase sm:text-6xl">
        No such commander. <span className="text-primary">Not yet.</span>
      </h1>
      <p className="mt-4 max-w-xl text-sm text-muted-foreground">
        <UserCircleDashedIcon className="mr-1 inline size-4 align-text-bottom" />
        Nobody goes by {callsign ? `"${callsign}"` : "that callsign"}. Callsigns can change: try finding them.
      </p>
      <PlayerSearch className="mt-6" />
      <Button asChild variant="outline" className="mt-6">
        <Link to="/leaderboards">The leaderboards</Link>
      </Button>
    </div>
  )
}
