import { DownloadSimpleIcon, PlayIcon } from "@phosphor-icons/react"
import { useEffect, useRef } from "react"
import { Link } from "react-router"
import { Reveal } from "@/components/reveal"
import { Button } from "@/components/ui/button"
import { useInView } from "@/hooks/use-in-view"
import { useReducedMotion } from "@/hooks/use-reduced-motion"
import { media, saveData } from "@/lib/media"
import { assetFor, type Platform, PLATFORM_NAMES, platformList } from "@/lib/releases"

type Props = {
  platform: Platform
}

/** The last word: footage behind a call to arms (the hero's own clip, which the browser already has). */
export function Finale({ platform }: Props) {
  const asset = assetFor(platform)
  const [ref, inView] = useInView<HTMLElement>({ margin: "200px" })
  const video = useRef<HTMLVideoElement>(null)
  const reduced = useReducedMotion()

  useEffect(() => {
    const v = video.current
    if (!v) return
    if (inView && !reduced && !saveData()) v.play().catch(() => {})
    else v.pause()
  }, [inView, reduced])

  return (
    <section ref={ref} className="relative isolate overflow-hidden border-t border-white/10">
      <video
        ref={video}
        src={media("hero", "mp4")}
        poster={media("hero", "jpg")}
        muted
        loop
        playsInline
        preload="none"
        aria-hidden="true"
        className="absolute inset-0 -z-30 size-full object-cover"
      />
      <div className="absolute inset-0 -z-20 bg-[linear-gradient(to_bottom,var(--background),rgb(10_12_11/0.55)_30%,rgb(10_12_11/0.55)_70%,var(--background))]" />
      <div className="scanlines absolute inset-0 -z-10 opacity-70" />

      <Reveal className="mx-auto flex max-w-6xl flex-col items-center px-4 py-36 text-center sm:px-6 sm:py-44">
        <p className="text-xs font-bold tracking-[0.3em] text-primary uppercase">Report for duty</p>
        <h2 className="mt-4 font-display text-[clamp(3.2rem,10vw,8rem)] leading-[0.85] font-extrabold text-[#f2ebd6] uppercase">
          The front
          <br />
          is waiting
        </h2>
        <p className="mt-6 max-w-lg text-base text-cream/80">
          Free and open source, for {platformList()}. Unzip it and play: nothing to install, and it keeps itself up to
          date.
        </p>
        <div className="mt-9 flex flex-wrap justify-center gap-3">
          <Button size="lg" asChild className="shine h-12 px-7 text-sm font-bold tracking-wider uppercase">
            <a href={asset.url}>
              <DownloadSimpleIcon weight="bold" />
              Download for {PLATFORM_NAMES[platform]}
            </a>
          </Button>
          <Button
            size="lg"
            variant="outline"
            asChild
            className="h-12 border-white/25 bg-black/30 px-7 text-sm font-bold tracking-wider uppercase backdrop-blur-sm"
          >
            {/* launching the game, finding a match: the play page says what happened */}
            <Link to="/play">
              <PlayIcon weight="fill" />
              Play now
            </Link>
          </Button>
        </div>
      </Reveal>
    </section>
  )
}
