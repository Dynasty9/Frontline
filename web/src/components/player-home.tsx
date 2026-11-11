import { PlayIcon } from "@phosphor-icons/react"
import { Link } from "react-router"
import { PlayerAvatar } from "@/components/player-avatar"
import { XpProgress } from "@/components/insignia"
import { Button } from "@/components/ui/button"
import { type User, pictureOf } from "@/lib/account"
import { rankName } from "@/lib/insignia"
import { playerPath } from "@/lib/players"

/** A returning player's line on the home page, under the footage: who they are, how far along, and back into a battle. */
export function PlayerHome({ user, live }: { user: User; live?: number }) {
  return (
    <section aria-labelledby="welcome-back" className="border-y bg-background/70 backdrop-blur-sm">
      <div className="mx-auto grid max-w-6xl items-center gap-x-10 gap-y-6 px-4 py-8 sm:px-6 lg:grid-cols-[auto_minmax(0,1fr)_auto]">
        <div className="flex min-w-0 items-center gap-4">
          <PlayerAvatar icon={user.icon} avatar={pictureOf(user)} className="size-14 shrink-0" />
          <div className="min-w-0">
            <p className="font-mono text-[10px] tracking-[0.18em] text-primary uppercase">Welcome back</p>
            <h2 id="welcome-back" className="mt-1 truncate font-display text-3xl leading-none font-bold uppercase">
              {user.callsign}
            </h2>
            <p className="mt-1 text-xs text-muted-foreground uppercase">{rankName(user.rank)}</p>
          </div>
        </div>
        <div className="min-w-0">
          <XpProgress {...user} />
          <dl className="mt-3 flex gap-8 font-mono text-xs text-muted-foreground uppercase">
            <div className="flex gap-2">
              <dt>Battles</dt>
              <dd className="text-foreground">{user.battles}</dd>
            </div>
            <div className="flex gap-2">
              <dt>Wins</dt>
              <dd className="text-foreground">{user.wins}</dd>
            </div>
            <div className="flex gap-2">
              <dt>Live</dt>
              <dd className="text-foreground">{live ?? "—"}</dd>
            </div>
          </dl>
        </div>
        <div className="flex flex-wrap items-center gap-x-5 gap-y-3 text-sm">
          <Button asChild className="h-11 px-5 text-sm font-bold">
            <Link to="/play">
              <PlayIcon weight="fill" />
              Play Frontline
            </Link>
          </Button>
          <Link className="underline underline-offset-4 hover:text-primary" to="/profile">
            Profile & insignia
          </Link>
          <Link className="underline underline-offset-4 hover:text-primary" to={playerPath(user.callsign)}>
            Your public record
          </Link>
        </div>
      </div>
    </section>
  )
}
