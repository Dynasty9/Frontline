import { MagnifyingGlassIcon } from "@phosphor-icons/react"
import { useQuery } from "@tanstack/react-query"
import { useEffect, useId, useState } from "react"
import { Link, useNavigate } from "react-router"
import { PlayerAvatar } from "@/components/player-avatar"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { rankName } from "@/lib/insignia"
import { type BoardRow, findPlayers, type Period, playerPath, winRate } from "@/lib/players"
import { cn } from "@/lib/utils"

// the podium: gold, the emblem's cream for silver, and bronze
const PLACES = ["bg-primary text-primary-foreground", "bg-cream text-background", "bg-[#c9874a] text-background"]

/** A place on a board: the top three on the podium. */
export function Place({ position, className }: { position: number; className?: string }) {
  return (
    <span
      className={cn(
        "inline-grid h-6 min-w-6 place-items-center px-1 text-xs font-bold tabular-nums",
        PLACES[position - 1] ?? "text-muted-foreground",
        className
      )}
    >
      {position}
    </span>
  )
}

/**
 * A page of a leaderboard. `you`: the signed-in player's callsign, their row
 * marked; `me`: their row from wherever they are on the board, added at the
 * foot when it isn't on this page.
 */
export function LeaderboardTable({
  rows,
  period,
  you,
  me,
}: {
  rows: BoardRow[]
  period: Period
  you: string | null
  me: BoardRow | null
}) {
  const mine = (r: BoardRow) => !!you && r.callsign.toLowerCase() === you.toLowerCase()
  const away = me && !rows.some(mine) ? me : null
  return (
    <Table>
      <TableHeader>
        <TableRow className="hover:bg-transparent">
          <TableHead className="w-14 pl-4">
            <span className="sr-only">Place</span>#
          </TableHead>
          <TableHead>Commander</TableHead>
          <TableHead className="text-right">{period === "all" ? "XP" : "XP earned"}</TableHead>
          <TableHead className="hidden text-right sm:table-cell">Battles</TableHead>
          <TableHead className="hidden pr-4 text-right md:table-cell">Won</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {rows.map((r) => (
          <Row key={r.callsign} row={r} you={mine(r)} />
        ))}
        {away && (
          <>
            <TableRow className="hover:bg-transparent" aria-hidden="true">
              <TableCell colSpan={5} className="py-1 text-center text-muted-foreground">
                ⋯
              </TableCell>
            </TableRow>
            <Row row={away} you />
          </>
        )}
      </TableBody>
    </Table>
  )
}

function Row({ row: r, you }: { row: BoardRow; you: boolean }) {
  return (
    <TableRow className={cn(you && "bg-primary/5")}>
      <TableCell className="py-2.5 pl-4">
        <Place position={r.position} />
      </TableCell>
      <TableCell className="py-2.5">
        <Link to={playerPath(r.callsign)} className="group flex min-w-0 items-center gap-3">
          <PlayerAvatar icon={r.icon} avatar={r.avatar} className="size-8" />
          <span className="min-w-0">
            <span className="flex items-center gap-2 font-medium text-foreground group-hover:underline">
              <span className="truncate">{r.callsign}</span>
              {you && (
                <Badge variant="outline" className="border-primary/40 text-primary">
                  You
                </Badge>
              )}
            </span>
            <span className="block text-xs text-muted-foreground">
              {rankName(r.rank)} · rank {r.rank}
            </span>
          </span>
        </Link>
      </TableCell>
      <TableCell className="text-right font-semibold tabular-nums">{r.score.toLocaleString()}</TableCell>
      <TableCell className="hidden text-right tabular-nums sm:table-cell">{r.battles.toLocaleString()}</TableCell>
      <TableCell className="hidden pr-4 text-right tabular-nums md:table-cell">{winRate(r.wins, r.battles)}</TableCell>
    </TableRow>
  )
}

/** Finding a commander as their callsign is typed: the matches, and Enter goes to the first. */
export function PlayerSearch({ className }: { className?: string }) {
  const id = useId()
  const navigate = useNavigate()
  const [q, setQ] = useState("")
  const [asked, setAsked] = useState("")
  // ask once the typing pauses
  useEffect(() => {
    const t = window.setTimeout(() => setAsked(q.trim()), 250)
    return () => window.clearTimeout(t)
  }, [q])
  const found = useQuery({
    queryKey: ["find", asked.toLowerCase()],
    queryFn: ({ signal }) => findPlayers(asked, signal),
    enabled: asked.length >= 2,
  })
  const open = q.trim().length >= 2

  return (
    <search className={cn("relative block", className)}>
      <form
        onSubmit={(e) => {
          e.preventDefault()
          const first = found.data?.[0]
          if (first) void navigate(playerPath(first.callsign))
          else if (q.trim().length >= 3) void navigate(playerPath(q.trim()))
        }}
      >
        <Label htmlFor={`${id}-q`} className="sr-only">
          Find a commander
        </Label>
        <MagnifyingGlassIcon className="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          id={`${id}-q`}
          type="search"
          autoComplete="off"
          placeholder="Find a commander"
          maxLength={20}
          value={q}
          onChange={(e) => setQ(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Escape") setQ("")
          }}
          aria-controls={open ? `${id}-found` : undefined}
          className="h-9 w-full pl-8 sm:w-64"
        />
        {open && (
          <div
            id={`${id}-found`}
            className="absolute inset-x-0 top-full z-20 mt-1 border bg-popover text-sm shadow-md sm:w-64"
          >
            {asked !== q.trim() || found.isPending ? (
              <p className="px-3 py-2 text-xs text-muted-foreground">Looking…</p>
            ) : found.isError ? (
              <p className="px-3 py-2 text-xs text-destructive">Can't search right now.</p>
            ) : !found.data?.length ? (
              <p className="px-3 py-2 text-xs text-muted-foreground">No commander's callsign starts with that.</p>
            ) : (
              <ul aria-label="Commanders found">
                {found.data.map((p) => (
                  <li key={p.callsign}>
                    <Link
                      to={playerPath(p.callsign)}
                      className="flex items-center gap-2.5 px-3 py-2 hover:bg-muted focus-visible:bg-muted focus-visible:outline-none"
                    >
                      <PlayerAvatar icon={p.icon} avatar={p.avatar} className="size-6" />
                      <span className="min-w-0 flex-1 truncate font-medium">{p.callsign}</span>
                      <span className="text-xs text-muted-foreground tabular-nums">rank {p.rank}</span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}
      </form>
    </search>
  )
}
