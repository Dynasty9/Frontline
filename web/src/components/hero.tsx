import { CrosshairIcon, DownloadSimpleIcon } from "@phosphor-icons/react"
import { Emblem, Wordmark } from "@/components/emblem"
import { Button } from "@/components/ui/button"
import { FIND_MATCH_LINK } from "@/lib/config"
import type { Health } from "@/lib/matchmaker"
import { type Build, type Platform, PLATFORM_NAMES } from "@/lib/releases"

type Props = {
  health: Health | undefined
  build: Build | null
  platform: Platform
  onLaunch: () => void
}

export function Hero({ health, build, platform, onLaunch }: Props) {
  const asset = build?.assets[platform]
  return (
    <section id="top" className="topo relative overflow-hidden border-b">
      <div className="mx-auto grid max-w-6xl items-center gap-12 px-4 pt-16 pb-20 sm:px-6 lg:grid-cols-[1fr_1.1fr] lg:pt-24 lg:pb-28">
        <div>
          <div className="flex items-center gap-4">
            <Emblem className="size-14 shrink-0" />
            <Wordmark className="text-4xl sm:text-5xl" />
          </div>
          <div className="mt-5 h-px w-full max-w-md bg-primary/70" />
          <p className="mt-3 text-xs font-bold tracking-[0.22em] text-primary uppercase">
            Squad tactics · Combined arms · Command
          </p>
          <h1 className="mt-8 max-w-xl text-3xl leading-tight font-semibold text-balance sm:text-4xl">
            A squad-level strategy game where every soldier thinks for himself.
          </h1>
          <p className="mt-4 max-w-xl text-base leading-relaxed text-muted-foreground">
            You decide where your squads go; they decide how to get there and how to fight. Take on the AI alone, team
            up with friends against it, or fight each other online.
          </p>

          <div className="mt-8 flex flex-wrap items-center gap-3">
            <Button size="lg" asChild className="h-11 px-5 text-sm font-semibold">
              <a href={asset?.url ?? "#download"}>
                <DownloadSimpleIcon weight="bold" />
                Download for {PLATFORM_NAMES[platform]}
              </a>
            </Button>
            <Button size="lg" variant="outline" asChild className="h-11 px-5 text-sm font-semibold">
              <a href={FIND_MATCH_LINK} onClick={onLaunch}>
                <CrosshairIcon weight="bold" />
                Find a match
              </a>
            </Button>
          </div>
          <p className="mt-3 text-xs text-muted-foreground">
            Free and open source.{" "}
            {build ? (
              <>
                {build.prerelease ? "Latest build" : build.name} ·{" "}
                <a href="#download" className="underline-offset-4 hover:text-foreground hover:underline">
                  other platforms
                </a>
              </>
            ) : (
              <a href="#download" className="underline-offset-4 hover:text-foreground hover:underline">
                All downloads
              </a>
            )}
          </p>

          <LiveLine health={health} />
        </div>

        <figure>
          <div className="relative">
            <Brackets />
            <img
              src="/shots/battle.jpg"
              alt="A firefight around a Coalition trench line"
              className="aspect-video w-full object-cover ring-1 ring-white/10"
              width={1600}
              height={900}
            />
          </div>
          <figcaption className="mt-2 text-xs text-muted-foreground">
            A firefight around a Coalition trench line
          </figcaption>
        </figure>
      </div>
    </section>
  )
}

function LiveLine({ health }: { health: Health | undefined }) {
  if (!health) return <p className="mt-8 h-5" />
  const n = health.lobbies
  return (
    <p className="mt-8 flex items-center gap-2 text-sm text-muted-foreground">
      <span className="relative flex size-2">
        <span className="absolute inline-flex size-full animate-ping rounded-full bg-good opacity-60" />
        <span className="relative inline-flex size-2 rounded-full bg-good" />
      </span>
      <a href="#battles" className="hover:text-foreground">
        {n === 0 ? "No battles hosted right now" : `${n} ${n === 1 ? "battle" : "battles"} live`}
        {health.players > 0 && ` · ${health.players} ${health.players === 1 ? "player" : "players"}`}
      </a>
    </p>
  )
}

/** Amber corner marks, like a target frame in the game's HUD. */
function Brackets() {
  const c = "pointer-events-none absolute size-5 border-primary"
  return (
    <>
      <span className={`${c} -top-2 -left-2 border-t-2 border-l-2`} />
      <span className={`${c} -top-2 -right-2 border-t-2 border-r-2`} />
      <span className={`${c} -bottom-2 -left-2 border-b-2 border-l-2`} />
      <span className={`${c} -right-2 -bottom-2 border-r-2 border-b-2`} />
    </>
  )
}
