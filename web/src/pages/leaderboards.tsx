import { CaretLeftIcon, CaretRightIcon, TrophyIcon, WarningIcon } from "@phosphor-icons/react"
import { keepPreviousData, useQuery } from "@tanstack/react-query"
import { Link, useSearchParams } from "react-router"
import { CommandersNav } from "@/components/commanders-nav"
import { SectionLabel } from "@/components/battles"
import { LeaderboardTable, PlayerSearch } from "@/components/leaderboard"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import { usePageTitle } from "@/hooks/use-page-title"
import { useAccount } from "@/lib/account"
import { fetchBoard, type Period, PERIOD_NAMES, PERIODS } from "@/lib/players"
import { cn } from "@/lib/utils"

/** A board's address: /leaderboards, /leaderboards?period=week&page=2 */
function at(period: Period, page = 1) {
  const q = new URLSearchParams()
  if (period !== "all") q.set("period", period)
  if (page > 1) q.set("page", String(page))
  return q.size ? `/leaderboards?${q}` : "/leaderboards"
}

const SINCE: Record<Period, string> = {
  all: "Every point of experience ever earned.",
  month: "Experience earned since the first of the month (UTC).",
  week: "Experience earned since Monday (UTC).",
}

/**
 * /leaderboards: the commanders with the most experience, of all time, this
 * month and this week (?period=, ?page=). XP is the figure to rank: only the
 * accounts database writes it, timed on its own clock, so it can't be
 * claimed, only earned.
 */
export default function LeaderboardsPage() {
  usePageTitle("Leaderboards")
  const [search] = useSearchParams()
  const asked = search.get("period")
  const period: Period = PERIODS.includes(asked as Period) ? (asked as Period) : "all"
  const page = Math.max(1, Math.floor(Number(search.get("page")) || 1))
  const { user } = useAccount()
  const you = user?.callsign ?? null
  const board = useQuery({
    queryKey: ["board", period, page, you],
    queryFn: ({ signal }) => fetchBoard(period, page, you, signal),
    placeholderData: keepPreviousData,
  })

  return (
    <div className="topo">
      <CommandersNav />
      <div className="mx-auto max-w-6xl px-4 pt-14 pb-24 sm:px-6">
        <SectionLabel>Commanders / Leaderboards</SectionLabel>
        <h1 className="mt-2 font-display text-5xl leading-[0.95] font-extrabold uppercase sm:text-6xl">
          Top commanders. <span className="text-primary">Earned in battle.</span>
        </h1>
        <p className="mt-4 max-w-2xl text-sm text-muted-foreground">
          Meet the commanders earning their place through time in battle. Compare experience across all time, this month
          or this week. For rank thresholds and unlocks, visit the rank guide.
        </p>

        <div className="mt-8 flex flex-wrap items-end justify-between gap-4">
          <nav aria-label="Leaderboards" className="flex border">
            {PERIODS.map((p) => (
              <Link
                key={p}
                to={at(p)}
                aria-current={p === period ? "page" : undefined}
                className={cn(
                  "px-4 py-2 text-xs font-semibold tracking-[0.12em] uppercase transition-colors",
                  p === period ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:text-foreground"
                )}
              >
                {PERIOD_NAMES[p]}
              </Link>
            ))}
          </nav>
          <PlayerSearch className="w-full sm:w-auto" />
        </div>
        <p className="mt-3 text-xs text-muted-foreground">{SINCE[period]}</p>

        <Card className={cn("mt-4 gap-0 py-0 text-sm transition-opacity", board.isPlaceholderData && "opacity-60")}>
          {board.isPending ? (
            <div className="space-y-3 p-4">
              {[0, 1, 2, 3, 4].map((i) => (
                <div key={i} className="flex items-center gap-4">
                  <Skeleton className="size-8" />
                  <Skeleton className="h-4 flex-1" />
                  <Skeleton className="h-4 w-16" />
                </div>
              ))}
            </div>
          ) : board.isError ? (
            <div className="p-4">
              <Alert variant="destructive" className="border-destructive/30">
                <WarningIcon />
                <AlertTitle>The leaderboards aren't available right now</AlertTitle>
                <AlertDescription>
                  The matchmaker didn't answer. They'll be back; your experience is safe in the meantime.
                </AlertDescription>
              </Alert>
            </div>
          ) : board.data.rows.length === 0 && page === 1 ? (
            <div className="flex flex-col items-center px-6 py-14 text-center">
              <TrophyIcon className="size-10 text-muted-foreground" />
              <p className="mt-4 text-base font-medium">Nobody on the board yet</p>
              <p className="mt-1 max-w-md text-sm text-muted-foreground">
                {period === "all"
                  ? "Fight a battle signed in and you'll be the first."
                  : `Nobody has earned any experience ${period === "week" ? "this week" : "this month"} yet. Fight a battle signed in and you'll top it.`}
              </p>
              <Button asChild variant="outline" className="mt-6">
                <Link to="/play">Play</Link>
              </Button>
            </div>
          ) : (
            <LeaderboardTable rows={board.data.rows} period={period} you={you} me={board.data.me} />
          )}
        </Card>

        {board.data && board.data.pages > 1 && (
          <nav aria-label="Pages" className="mt-4 flex items-center justify-between gap-4 text-sm">
            <PageLink to={page > 1 ? at(period, page - 1) : null}>
              <CaretLeftIcon /> Higher
            </PageLink>
            <span className="text-muted-foreground tabular-nums">
              Page {page} of {board.data.pages} · {board.data.total.toLocaleString()} commanders
            </span>
            <PageLink to={page < board.data.pages ? at(period, page + 1) : null}>
              Lower <CaretRightIcon />
            </PageLink>
          </nav>
        )}
      </div>
    </div>
  )
}

/** The way up or down the board, greyed out at either end. */
function PageLink({ to, children }: { to: string | null; children: React.ReactNode }) {
  if (!to)
    return (
      <Button variant="outline" size="sm" disabled>
        {children}
      </Button>
    )
  return (
    <Button asChild variant="outline" size="sm">
      <Link to={to}>{children}</Link>
    </Button>
  )
}
