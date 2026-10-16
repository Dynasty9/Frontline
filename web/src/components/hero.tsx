import { CaretDoubleDownIcon, CrosshairIcon, DownloadSimpleIcon, PlayIcon } from "@phosphor-icons/react"
import { type CSSProperties, type RefObject, useEffect, useRef, useState } from "react"
import { Emblem } from "@/components/emblem"
import { HudCorners, Timecode } from "@/components/footage"
import { RadioLog } from "@/components/radio-log"
import { Button } from "@/components/ui/button"
import { useInView } from "@/hooks/use-in-view"
import { useReducedMotion } from "@/hooks/use-reduced-motion"
import { FIND_MATCH_LINK } from "@/lib/config"
import type { Health } from "@/lib/matchmaker"
import { media, saveData } from "@/lib/media"
import { latest, type Platform, PLATFORM_NAMES } from "@/lib/releases"

type Props = {
  health: Health | undefined
  platform: Platform
  onLaunch: () => void
  onWatch: () => void
}

/** What you command, typed into the headline one after another. */
const COMMANDS = ["squads", "armour", "gunships", "artillery", "patrol boats", "A-10s"]

export function Hero({ health, platform, onLaunch, onWatch }: Props) {
  const asset = latest.assets[platform]
  const video = useRef<HTMLVideoElement>(null)
  const [ref, inView] = useInView<HTMLElement>()
  const reduced = useReducedMotion()

  // the footage runs while you can see it
  useEffect(() => {
    const v = video.current
    if (!v) return
    if (inView && !reduced && !saveData()) v.play().catch(() => {})
    else v.pause()
  }, [inView, reduced])

  return (
    <section ref={ref} id="top" className="relative isolate flex min-h-[100svh] flex-col overflow-hidden">
      {/* the footage, and what's drawn over it to make the text read */}
      <video
        ref={video}
        src={media("hero", "mp4")}
        poster={media("hero", "jpg")}
        muted
        loop
        playsInline
        preload={saveData() ? "none" : "auto"}
        aria-hidden="true"
        className="absolute inset-0 -z-30 size-full object-cover"
      />
      <div className="hero-shade absolute inset-0 -z-20" />
      <div className="scanlines absolute inset-0 -z-10 opacity-70" />
      <div className="pointer-events-none absolute inset-0 -z-10 overflow-hidden">
        <div className="grain absolute" />
      </div>
      <HeroHud video={video} />

      <div className="mx-auto flex w-full max-w-6xl flex-1 flex-col justify-center px-4 pt-32 pb-28 sm:px-6">
        <div className="flex items-center gap-3">
          <Emblem className="size-9 shrink-0 sm:size-11" />
          <p className="text-[11px] font-bold tracking-[0.3em] text-primary uppercase sm:text-xs">
            Squad tactics · Combined arms · Command
          </p>
        </div>

        <h1 className="mt-4 font-display text-[clamp(4.2rem,15vw,11.5rem)] leading-[0.82] font-extrabold tracking-[0.02em] text-[#f2ebd6] uppercase">
          <span className="sr-only">Frontline</span>
          <span className="glitch drop-in" data-text="Frontline" aria-hidden="true">
            {[..."Frontline"].map((ch, i) => (
              <span key={i} style={{ "--i": i } as CSSProperties}>
                {ch}
              </span>
            ))}
          </span>
        </h1>

        <p className="mt-5 font-display text-2xl font-bold tracking-wide uppercase sm:text-4xl">
          You command the <Typewriter words={COMMANDS} />
        </p>
        <p className="mt-4 max-w-xl text-base leading-relaxed text-cream/80 sm:text-lg">
          A squad-level strategy game where every soldier thinks for himself. You decide where they go; they decide how
          to get there and how to fight. Take on the AI alone, team up with friends against it, or fight each other online.
        </p>

        <div className="mt-9 flex flex-wrap items-center gap-3">
          <Button size="lg" asChild className="shine h-12 px-6 text-sm font-bold tracking-wider uppercase">
            <a href={asset.url}>
              <DownloadSimpleIcon weight="bold" />
              Download for {PLATFORM_NAMES[platform]}
            </a>
          </Button>
          <Button
            size="lg"
            variant="outline"
            asChild
            className="h-12 border-white/25 bg-black/30 px-6 text-sm font-bold tracking-wider uppercase backdrop-blur-sm"
          >
            <a href={FIND_MATCH_LINK} onClick={onLaunch}>
              <CrosshairIcon weight="bold" />
              Find a match
            </a>
          </Button>
          <button
            type="button"
            onClick={onWatch}
            className="group ml-1 inline-flex h-12 items-center gap-3 px-2 text-sm font-bold tracking-wider text-cream uppercase"
          >
            <span className="relative grid size-10 place-items-center rounded-full border border-primary/60 bg-primary/10 transition-colors group-hover:bg-primary/25">
              <span className="absolute inset-0 animate-ping rounded-full border border-primary/40 [animation-duration:2.2s] motion-reduce:hidden" />
              <PlayIcon weight="fill" className="size-4 text-primary" />
            </span>
            Watch the footage
          </button>
        </div>

        <p className="mt-4 text-xs text-muted-foreground">
          Free and open source · {latest.name} ·{" "}
          <a href="#download" className="underline-offset-4 hover:text-foreground hover:underline">
            other platforms
          </a>
        </p>
        <LiveLine health={health} />
      </div>

      <RadioLog className="absolute right-6 bottom-20 hidden w-[22rem] xl:block" />

      <a
        href="#intel"
        className="absolute bottom-5 left-1/2 flex -translate-x-1/2 flex-col items-center gap-1 text-[10px] font-bold tracking-[0.3em] text-muted-foreground uppercase hover:text-foreground"
      >
        Scroll
        <CaretDoubleDownIcon className="nudge size-4" />
      </a>
    </section>
  )
}

/** Types a word, holds it, deletes it, types the next. */
function Typewriter({ words }: { words: string[] }) {
  const reduced = useReducedMotion()
  const [w, setW] = useState(0)
  const [n, setN] = useState(0)
  const [deleting, setDeleting] = useState(false)
  const word = words[w % words.length]

  useEffect(() => {
    let t: number
    if (reduced) {
      t = window.setTimeout(() => setW((x) => x + 1), 2600)
    } else if (!deleting && n < word.length) {
      t = window.setTimeout(() => setN(n + 1), 75)
    } else if (!deleting) {
      t = window.setTimeout(() => setDeleting(true), 1700)
    } else if (n > 0) {
      t = window.setTimeout(() => setN(n - 1), 35)
    } else {
      t = window.setTimeout(() => {
        setDeleting(false)
        setW((x) => x + 1)
      }, 250)
    }
    return () => window.clearTimeout(t)
  }, [n, deleting, word, reduced])

  return (
    <span className="text-primary">
      {reduced ? word : word.slice(0, n)}
      <span className="caret" />
    </span>
  )
}

/** Corner marks round the whole frame, a recording light and the footage's own timecode. */
function HeroHud({ video }: { video: RefObject<HTMLVideoElement | null> }) {
  return (
    <div className="pointer-events-none absolute inset-x-4 top-20 bottom-4 -z-10 hidden sm:block lg:inset-x-6">
      <HudCorners inset="0" className="size-7 border-primary/70" />
      <div className="absolute top-3 left-4 flex items-center gap-2 font-mono text-[10px] tracking-[0.2em] text-cream/80 uppercase">
        <span className="rec-dot" />
        Rec · Cam 01 · In-game footage
      </div>
      <div className="absolute top-3 right-4 font-mono text-[10px] tracking-[0.2em] text-cream/80 uppercase">
        TC <Timecode video={video} />
      </div>
    </div>
  )
}

function LiveLine({ health }: { health: Health | undefined }) {
  if (!health) return <p className="mt-6 h-5" />
  const n = health.lobbies
  return (
    <p className="mt-6 flex items-center gap-2 text-sm text-muted-foreground">
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
