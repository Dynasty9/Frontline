import { useEffect, useState } from "react"
import { useInView } from "@/hooks/use-in-view"
import { useReducedMotion } from "@/hooks/use-reduced-motion"
import { RADIO } from "@/lib/intel"
import { cn } from "@/lib/utils"

const KEEP = 3 // finished lines kept above the one coming in

/** The command net, as the game's radio log shows it: real lines from the missions, typed out as they come in. */
export function RadioLog({ className }: { className?: string }) {
  const [ref, inView] = useInView<HTMLDivElement>()
  const reduced = useReducedMotion()
  const [i, setI] = useState(KEEP) // the line coming in now
  const [n, setN] = useState(0) // how much of it has come through

  useEffect(() => {
    if (!inView) return
    const text = RADIO[i % RADIO.length][1]
    if (!reduced && n < text.length) {
      // a slightly uneven hand on the keys
      const t = window.setTimeout(() => setN((c) => c + 1), 18 + Math.random() * 34)
      return () => window.clearTimeout(t)
    }
    const t = window.setTimeout(
      () => {
        setI((c) => c + 1)
        setN(0)
      },
      reduced ? 4500 : 2200,
    )
    return () => window.clearTimeout(t)
  }, [i, n, inView, reduced])

  const lines = Array.from({ length: KEEP + 1 }, (_, k) => i - KEEP + k)
  return (
    <div
      ref={ref}
      className={cn("border border-white/10 bg-black/55 font-mono text-[11px] leading-relaxed shadow-2xl backdrop-blur-md", className)}
      aria-hidden="true"
    >
      <div className="flex items-center gap-2 border-b border-white/10 px-3 py-2 text-[10px] tracking-[0.2em] text-muted-foreground uppercase">
        <span className="rec-dot" />
        Command net
        <span className="ml-auto text-primary/80">Secure</span>
      </div>
      <ol className="space-y-2 px-3 py-3">
        {lines.map((k, row) => {
          const [who, text] = RADIO[((k % RADIO.length) + RADIO.length) % RADIO.length]
          const current = row === KEEP
          return (
            <li key={k} className={cn("transition-opacity duration-500", current ? "text-cream" : row === 0 ? "opacity-35" : "opacity-60")}>
              <span className="text-primary">{who}:</span>{" "}
              {current && !reduced ? text.slice(0, n) : text}
              {current && <span className="caret text-primary" />}
            </li>
          )
        })}
      </ol>
    </div>
  )
}
