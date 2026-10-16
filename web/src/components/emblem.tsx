import { cn } from "@/lib/utils"

/** The game's emblem, as on the splash: a cream triangle with a red dot. */
export function Emblem({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 100 100" className={cn("size-10", className)} aria-hidden="true">
      <path d="M8 86 L50 12 L92 86 Z" fill="none" stroke="var(--cream)" strokeWidth="7" strokeLinejoin="round" />
      <circle cx="50" cy="64" r="10" fill="var(--emblem)" />
    </svg>
  )
}

/** FRONTLINE, spaced out the way the splash sets it. */
export function Wordmark({ className }: { className?: string }) {
  return <span className={cn("font-bold tracking-[0.28em] text-[#f2ebd6] uppercase", className)}>Frontline</span>
}
