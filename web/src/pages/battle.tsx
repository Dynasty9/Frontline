import { ArrowLeftIcon, InfoIcon, RobotIcon, WarningIcon } from "@phosphor-icons/react"
import { useQuery } from "@tanstack/react-query"
import { Link, useParams } from "react-router"
import { SectionLabel } from "@/components/battles"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import { usePageTitle } from "@/hooks/use-page-title"
import {
  type Battle,
  type Commander,
  fetchBattle,
  type Figures,
  formatDuration,
  MODE_NAMES,
  playerPath,
  SIDE_NAMES,
} from "@/lib/players"
import { accuracy, measure, measureValue, rating, ratingWord, score, SUMMARY } from "@/lib/report"
import { cn } from "@/lib/utils"
import { ResultBadge } from "@/pages/player"

/**
 * /player/:callsign/battle/:id: one battle's after-action report, as the
 * player's game kept it (BattleStats.trim_report): how it went, their part
 * in it, every commander, and the two sides head to head. Their game's word,
 * and said to be.
 */
export default function BattlePage() {
  const { callsign = "", id = "" } = useParams()
  const battle = useQuery({
    queryKey: ["battle", callsign.toLowerCase(), id],
    queryFn: ({ signal }) => fetchBattle(callsign, id, signal),
  })
  const b = battle.data
  usePageTitle(b ? `${b.title} · ${callsign}` : "Battle")

  return (
    <div className="topo">
      <div className="mx-auto max-w-6xl px-4 pt-10 pb-24 sm:px-6">
        <Button asChild variant="ghost" size="sm" className="-ml-2.5 text-muted-foreground">
          <Link to={playerPath(callsign)}>
            <ArrowLeftIcon />
            {callsign}
          </Link>
        </Button>
        {battle.isPending ? (
          <div className="mt-6 space-y-4">
            <Skeleton className="h-10 w-80" />
            <Skeleton className="h-48" />
          </div>
        ) : battle.isError ? (
          <Alert variant="destructive" className="mt-6 border-destructive/30">
            <WarningIcon />
            <AlertTitle>This battle didn't load</AlertTitle>
            <AlertDescription>The matchmaker didn't answer. Try again in a moment.</AlertDescription>
          </Alert>
        ) : !b ? (
          <div className="mt-6">
            <h1 className="text-3xl font-semibold">No such battle</h1>
            <p className="mt-2 text-sm text-muted-foreground">
              It isn't on {callsign}'s record, or they keep their battles to themselves.
            </p>
          </div>
        ) : (
          <Report battle={b} callsign={callsign} />
        )}
      </div>
    </div>
  )
}

function Report({ battle: b, callsign }: { battle: Battle; callsign: string }) {
  const sides = b.report.sides ?? []
  const commanders = (b.report.players ?? []).toSorted(
    (x, y) => (x.team ?? 0) - (y.team ?? 0) || rating(y, sides[y.team ?? 0] ?? {}) - rating(x, sides[x.team ?? 0] ?? {})
  )
  const mine = (c: Commander) => (b.report.me !== undefined ? c.id === b.report.me : c.name === b.me.name)

  return (
    <>
      <div className="mt-4">
        <SectionLabel>After-action report</SectionLabel>
        <h1 className="mt-2 text-4xl font-semibold">{b.title || MODE_NAMES[b.mode]}</h1>
        <div className="mt-3 flex flex-wrap items-center gap-x-3 gap-y-2 text-sm text-muted-foreground">
          <ResultBadge result={b.result} />
          <span>{MODE_NAMES[b.mode]}</span>
          <span>·</span>
          <span>
            {callsign} fought for the {SIDE_NAMES[b.side]}
          </span>
          <span>·</span>
          <span>{formatDuration(b.duration_s)}</span>
          <span>·</span>
          <span>{new Date(b.played_at).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" })}</span>
          {b.game_version && (
            <>
              <span>·</span>
              <span className="font-mono text-xs">{b.game_version}</span>
            </>
          )}
        </div>
        <p className="mt-3 flex items-center gap-2 text-xs text-muted-foreground">
          <InfoIcon className="size-4 shrink-0" />
          As {callsign}'s game recorded it at the end of the battle.
        </p>
      </div>

      {b.report.replay && /^[a-f0-9]{24}$/.test(b.report.replay) && (
        <Button asChild className="mt-6 min-h-11">
          <Link to={`/watch/${b.report.replay}`}>Watch replay</Link>
        </Button>
      )}
      <Part battle={b} callsign={callsign} />

      {commanders.length > 0 && (
        <section aria-labelledby="commanders" className="mt-12">
          <h2 id="commanders" className="text-xl font-semibold">
            Commanders
          </h2>
          <Card className="mt-4 gap-0 py-0 text-sm">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead className="pl-4">Commander</TableHead>
                  <TableHead className="hidden sm:table-cell">Side</TableHead>
                  <TableHead className="text-right">Rating</TableHead>
                  <TableHead className="hidden text-right md:table-cell">Killed</TableHead>
                  <TableHead className="hidden text-right md:table-cell">Lost</TableHead>
                  <TableHead className="hidden text-right lg:table-cell">Vehicles</TableHead>
                  <TableHead className="hidden text-right lg:table-cell">Accuracy</TableHead>
                  <TableHead className="pr-4 text-right">Score</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {commanders.map((c, i) => {
                  const r = rating(c, sides[c.team ?? 0] ?? {})
                  const acc = accuracy(c)
                  return (
                    <TableRow key={c.id ?? i} className={cn(mine(c) && "bg-primary/5")}>
                      <TableCell className="py-2.5 pl-4">
                        <span className="flex items-center gap-2 font-medium text-foreground">
                          {c.ai && <RobotIcon className="size-4 text-muted-foreground" aria-label="AI" />}
                          {c.name || (c.ai ? "AI" : "Commander")}
                          {/* whose record this is: their row is marked, and named if they played under another name */}
                          {mine(c) && c.name?.toLowerCase() !== callsign.toLowerCase() && (
                            <Badge variant="outline" className="border-primary/40 text-primary">
                              {callsign}
                            </Badge>
                          )}
                          {mine(c) && <span className="sr-only">(whose record this is)</span>}
                          {c.left && (
                            <Badge variant="outline" className="text-muted-foreground">
                              Left
                            </Badge>
                          )}
                        </span>
                        <span className="block text-xs text-muted-foreground sm:hidden">{SIDE_NAMES[c.team ?? 0]}</span>
                      </TableCell>
                      <TableCell className="hidden sm:table-cell">{SIDE_NAMES[c.team ?? 0]}</TableCell>
                      <TableCell className="text-right">
                        <Tooltip>
                          <TooltipTrigger asChild>
                            <button type="button" className="cursor-help font-semibold tabular-nums">
                              {Math.round(r)}
                            </button>
                          </TooltipTrigger>
                          <TooltipContent>{ratingWord(r)}</TooltipContent>
                        </Tooltip>
                      </TableCell>
                      <TableCell className="hidden text-right tabular-nums md:table-cell">
                        {(c.kills ?? 0).toLocaleString()}
                      </TableCell>
                      <TableCell className="hidden text-right tabular-nums md:table-cell">
                        {((c.lost ?? 0) + (c.captured ?? 0)).toLocaleString()}
                      </TableCell>
                      <TableCell className="hidden text-right tabular-nums lg:table-cell">
                        {c.veh_kills ?? 0} / {c.veh_lost ?? 0}
                      </TableCell>
                      <TableCell className="hidden text-right tabular-nums lg:table-cell">
                        {acc === null ? "-" : `${Math.round(acc)}%`}
                      </TableCell>
                      <TableCell className="pr-4 text-right tabular-nums">{score(c).toLocaleString()}</TableCell>
                    </TableRow>
                  )
                })}
              </TableBody>
            </Table>
          </Card>
        </section>
      )}

      {sides.length === 2 && <HeadToHead sides={sides as [Figures, Figures]} winner={b.report.winner} />}
    </>
  )
}

/** The player's own part: their rating, and their figures in groups. */
function Part({ battle: b, callsign }: { battle: Battle; callsign: string }) {
  const me = b.me
  const r = Number(me.rating ?? b.rating) || 0
  const groups: [string, [string, string][]][] = [
    [
      "Infantry",
      [
        ["Enemy killed", measure(me, "kills")],
        ["Enemy wounded", measure(me, "downs")],
        ["Men lost", measure(me, "lost")],
        ["Men captured", measure(me, "captured")],
      ],
    ],
    [
      "Armour and works",
      [
        ["Vehicles destroyed", measure(me, "veh_kills")],
        ["Vehicles lost", measure(me, "veh_lost")],
        ["Buildings destroyed", measure(me, "bld_kills")],
        ["Structures built", measure(me, "built")],
      ],
    ],
    [
      "Fire and supply",
      [
        ["Accuracy", measure(me, "acc")],
        ["Value destroyed", measure(me, "val_killed")],
        ["Supply spent", measure(me, "spent")],
        ["Fire missions", measure(me, "support")],
      ],
    ],
    [
      "Ground and men",
      [
        ["FOBs captured", measure(me, "captures")],
        ["Towns taken", measure(me, "towns")],
        ["Prisoners taken", measure(me, "prisoners")],
        ["Wounded saved", measure(me, "revived")],
      ],
    ],
  ]
  return (
    <section aria-labelledby="part" className="mt-10">
      <h2 id="part" className="text-xl font-semibold">
        {callsign}'s part
      </h2>
      <div className="mt-4 grid gap-4 lg:grid-cols-[14rem_1fr]">
        <Card className="items-center justify-center gap-1 p-5 text-center">
          <p className="text-xs font-bold tracking-[0.14em] text-muted-foreground uppercase">Rating</p>
          <p className="font-display text-6xl leading-none font-extrabold text-primary tabular-nums">{Math.round(r)}</p>
          <p className="text-sm font-semibold">{ratingWord(r)}</p>
          <p className="mt-2 text-xs text-muted-foreground">{Number(me.score ?? b.score).toLocaleString()} points</p>
        </Card>
        <div className="grid gap-4 sm:grid-cols-2">
          {groups.map(([title, rows]) => (
            <Card key={title} className="gap-0 py-0 text-sm">
              <h3 className="border-b px-4 py-2 text-xs font-bold tracking-[0.12em] text-muted-foreground uppercase">
                {title}
              </h3>
              <dl className="divide-y">
                {rows.map(([label, value]) => (
                  <div key={label} className="flex items-baseline justify-between gap-3 px-4 py-1.5">
                    <dt className="text-muted-foreground">{label}</dt>
                    <dd className="font-semibold tabular-nums">{value}</dd>
                  </div>
                ))}
              </dl>
            </Card>
          ))}
        </div>
      </div>
    </section>
  )
}

/** The two sides' totals, side by side, the better of each marked as the game's summary does. */
function HeadToHead({ sides, winner }: { sides: [Figures, Figures]; winner?: number }) {
  return (
    <section aria-labelledby="sides" className="mt-12">
      <h2 id="sides" className="text-xl font-semibold">
        The two sides
      </h2>
      <Card className="mt-4 gap-0 py-0 text-sm">
        <Table>
          <TableHeader>
            <TableRow className="hover:bg-transparent">
              <TableHead className="pl-4">
                <span className="sr-only">Measure</span>
              </TableHead>
              {SIDE_NAMES.map((s, t) => (
                <TableHead key={s} className={cn("text-right", t === 1 && "pr-4")}>
                  {s}
                  {winner === t && <span className="ml-1.5 text-good">· won</span>}
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody>
            {SUMMARY.map(([m, label, better, about]) => {
              const a = measureValue(sides[0], m)
              const z = measureValue(sides[1], m)
              const best = better === 0 || a === z ? -1 : (better > 0 ? a > z : a < z) ? 0 : 1
              return (
                <TableRow key={m}>
                  <TableCell className="py-2 pl-4">
                    <Tooltip>
                      <TooltipTrigger asChild>
                        <button type="button" className="cursor-help text-left text-muted-foreground">
                          {label}
                        </button>
                      </TooltipTrigger>
                      <TooltipContent className="max-w-64">{about}</TooltipContent>
                    </Tooltip>
                  </TableCell>
                  {sides.map((s, t) => (
                    <TableCell
                      key={t}
                      className={cn(
                        "text-right tabular-nums",
                        t === 1 && "pr-4",
                        best === t && "font-semibold text-good"
                      )}
                    >
                      {measure(s, m)}
                    </TableCell>
                  ))}
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      </Card>
    </section>
  )
}
