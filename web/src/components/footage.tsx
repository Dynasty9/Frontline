import { type ReactNode, type RefObject, useEffect, useRef } from "react"
import { useInView } from "@/hooks/use-in-view"
import { useReducedMotion } from "@/hooks/use-reduced-motion"
import { media, saveData, timecode } from "@/lib/media"
import { cn } from "@/lib/utils"

type ClipProps = {
  /** /media/NAME.mp4 and its poster frame, /media/NAME.jpg */
  name: string
  /** the camera's caption in the corner, e.g. "Cam 2 · Armour" */
  label: string
  /** the map square, as the game's radio calls it ("G4") */
  grid?: string
  className?: string
  children?: ReactNode
}

/**
 * A looping clip of gameplay in a HUD frame. It only loads and plays while it's
 * on screen (and not at all for people who prefer reduced motion or have Data
 * Saver on: they get the still), so a page of them costs no more than the one
 * you're looking at.
 */
export function Clip({ name, label, grid, className, children }: ClipProps) {
  const [ref, inView] = useInView<HTMLDivElement>({ threshold: 0.2 })
  const video = useRef<HTMLVideoElement>(null)
  const reduced = useReducedMotion()

  useEffect(() => {
    const v = video.current
    if (!v) return
    if (inView && !reduced && !saveData()) v.play().catch(() => {})
    else v.pause()
  }, [inView, reduced])

  return (
    <div ref={ref} className={cn("group relative isolate overflow-hidden bg-black ring-1 ring-white/10", className)}>
      <video
        ref={video}
        src={media(name, "mp4")}
        poster={media(name, "jpg")}
        muted
        loop
        playsInline
        preload="none"
        aria-hidden="true"
        className="size-full object-cover transition-transform duration-[1.2s] ease-out group-hover:scale-[1.04]"
      />
      <div className="scanlines pointer-events-none absolute inset-0" />
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_center,transparent_55%,rgb(0_0_0/0.5))]" />
      <HudCorners inset="0.75rem" />
      <div className="pointer-events-none absolute top-3 left-4 flex items-center gap-2 font-mono text-[10px] tracking-[0.18em] text-cream uppercase drop-shadow">
        <span className="rec-dot" />
        {label}
      </div>
      <div className="pointer-events-none absolute right-4 bottom-3 flex gap-3 font-mono text-[10px] tracking-[0.18em] text-cream/80 uppercase drop-shadow">
        {grid && <span>Grid {grid}</span>}
        <Timecode video={video} />
      </div>
      {children}
    </div>
  )
}

/** A video's running time as a camera shows it, MM:SS:FF, written straight to the DOM while it plays. */
export function Timecode({ video }: { video: RefObject<HTMLVideoElement | null> }) {
  const out = useRef<HTMLSpanElement>(null)
  useEffect(() => {
    const v = video.current
    if (!v) return
    let raf = 0
    const draw = () => {
      if (out.current) out.current.textContent = timecode(v.currentTime)
      raf = requestAnimationFrame(draw)
    }
    const start = () => {
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(draw)
    }
    const stop = () => cancelAnimationFrame(raf)
    v.addEventListener("playing", start)
    v.addEventListener("pause", stop)
    return () => {
      stop()
      v.removeEventListener("playing", start)
      v.removeEventListener("pause", stop)
    }
  }, [video])
  return (
    <span ref={out} className="tabular-nums">
      00:00:00
    </span>
  )
}

/** Amber corner marks, like a target frame in the game's HUD. */
export function HudCorners({ inset = "-0.5rem", className }: { inset?: string; className?: string }) {
  const c = cn("pointer-events-none absolute size-5 border-primary", className)
  return (
    <>
      <span className={`${c} border-t-2 border-l-2`} style={{ top: inset, left: inset }} />
      <span className={`${c} border-t-2 border-r-2`} style={{ top: inset, right: inset }} />
      <span className={`${c} border-b-2 border-l-2`} style={{ bottom: inset, left: inset }} />
      <span className={`${c} border-r-2 border-b-2`} style={{ bottom: inset, right: inset }} />
    </>
  )
}
