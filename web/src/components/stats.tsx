import { useEffect } from "react"
import { Reveal } from "@/components/reveal"
import { useInView } from "@/hooks/use-in-view"
import { useReducedMotion } from "@/hooks/use-reduced-motion"
import { STATS } from "@/lib/intel"

export function Stats() {
  return (
    <section aria-label="The game in numbers" className="mx-auto max-w-6xl px-4 pt-10 pb-6 sm:px-6">
      <div className="grid grid-cols-2 gap-px border border-white/10 bg-white/10 md:grid-cols-5">
        {STATS.map((s, i) => (
          <Reveal key={s.label} delay={i * 90} className="bg-background last:col-span-2 md:last:col-span-1">
            <div className="group relative h-full overflow-hidden p-5 transition-colors hover:bg-card">
              <div className="absolute inset-x-0 top-0 h-px origin-left scale-x-0 bg-primary transition-transform duration-500 group-hover:scale-x-100" />
              <div className="font-display text-6xl leading-none font-extrabold text-primary tabular-nums">
                <CountUp to={s.value} from={s.from} />
                {s.unit && <span className="ml-1 text-3xl">{s.unit}</span>}
              </div>
              <div className="mt-2 text-xs font-bold tracking-[0.18em] uppercase">{s.label}</div>
              <p className="mt-1.5 text-xs leading-relaxed text-muted-foreground">{s.note}</p>
            </div>
          </Reveal>
        ))}
      </div>
    </section>
  )
}

/** Rolls a number from `from` to `to` (easing out) the first time it comes into view. */
function CountUp({ to, from }: { to: number; from: number }) {
  const [ref, inView] = useInView<HTMLSpanElement>({ once: true })
  const reduced = useReducedMotion()

  useEffect(() => {
    const el = ref.current
    if (!el) return
    if (reduced) {
      el.textContent = String(to)
      return
    }
    if (!inView) return
    const t0 = performance.now()
    const dur = 1600
    let raf = 0
    const step = (now: number) => {
      const k = Math.min(1, (now - t0) / dur)
      const e = 1 - Math.pow(1 - k, 4)
      el.textContent = String(Math.round(from + (to - from) * e))
      if (k < 1) raf = requestAnimationFrame(step)
    }
    raf = requestAnimationFrame(step)
    return () => cancelAnimationFrame(raf)
  }, [ref, inView, reduced, to, from])

  return <span ref={ref}>{reduced ? to : from}</span>
}
