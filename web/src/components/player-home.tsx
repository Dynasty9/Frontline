import { Link } from "react-router"
import { SectionLabel } from "@/components/battles"
import { PlayerAvatar } from "@/components/player-avatar"
import { XpProgress } from "@/components/insignia"
import { Button } from "@/components/ui/button"
import { type User, pictureOf } from "@/lib/account"
import { rankName } from "@/lib/insignia"
import { playerPath } from "@/lib/players"

/** A returning player's front door. Discovery stays available below and in the navigation. */
export function PlayerHome({ user, live }: { user: User; live?: number }) {
  return (
    <section className="topo border-b">
      <div className="mx-auto grid max-w-6xl gap-12 px-4 pt-16 pb-16 sm:px-6 lg:grid-cols-[1.4fr_1fr]">
        <div>
          <SectionLabel>Ready when you are</SectionLabel>
          <h1 className="mt-4 font-display text-5xl leading-none font-extrabold uppercase sm:text-7xl">
            Welcome back, <br />
            <span className="break-words text-primary">{user.callsign}.</span>
          </h1>
          <p className="mt-5 max-w-lg leading-relaxed text-muted-foreground">
            Pick up command. Play a mission, find an opponent, or bring your friends into the same fight.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Button size="lg" asChild className="h-11 px-5 text-sm">
              <Link to="/play">Play Frontline</Link>
            </Button>
            <Button variant="outline" size="lg" asChild className="h-11 px-5 text-sm">
              <Link to="/battles">Browse battles{live ? ` · ${live} live` : ""}</Link>
            </Button>
          </div>
          <p className="mt-5 text-sm text-muted-foreground">
            {live === undefined
              ? "Open Battles to check who is hosting."
              : live === 0
                ? "No public battles right now. Play solo or host one in the game."
                : "Join a public battle or host your own from the game."}
          </p>
        </div>
        <div className="self-center border-y py-6">
          <div className="flex items-center gap-4">
            <PlayerAvatar icon={user.icon} avatar={pictureOf(user)} className="size-16" />
            <div>
              <p className="font-mono text-xs tracking-wider text-muted-foreground uppercase">Your progress</p>
              <h2 className="mt-1 font-display text-3xl font-bold uppercase">{rankName(user.rank)}</h2>
            </div>
          </div>
          <XpProgress {...user} className="mt-5" />
          <dl className="mt-5 flex gap-10">
            <div>
              <dt className="text-xs text-muted-foreground">Battles</dt>
              <dd className="font-mono text-2xl">{user.battles}</dd>
            </div>
            <div>
              <dt className="text-xs text-muted-foreground">Wins</dt>
              <dd className="font-mono text-2xl">{user.wins}</dd>
            </div>
          </dl>
          <div className="mt-6 flex flex-wrap gap-5 text-sm">
            <Link className="underline underline-offset-4 hover:text-primary" to={playerPath(user.callsign)}>
              Your public record
            </Link>
            <Link className="underline underline-offset-4 hover:text-primary" to="/profile">
              Profile & insignia
            </Link>
          </div>
        </div>
      </div>
    </section>
  )
}
