import type { CSSProperties, ReactNode } from "react"
import { useInView } from "@/hooks/use-in-view"
import { cn } from "@/lib/utils"

type Props = {
  children: ReactNode
  className?: string
  /** where it comes in from: rises (up), slides (left / right), grows (zoom) or is wiped on (wipe) */
  from?: "up" | "left" | "right" | "zoom" | "wipe" | "signal" | "type"
  /** ms to wait after it comes into view, to stagger a row of things */
  delay?: number
}

/** Brings its contents in as they scroll into view (once). The motion is all CSS: see .reveal in index.css. */
export function Reveal({ children, className, from = "up", delay = 0 }: Props) {
  const [ref, shown] = useInView<HTMLDivElement>({ once: true, margin: "0px 0px -12% 0px" })
  return (
    <div
      ref={ref}
      data-from={from}
      data-shown={shown || undefined}
      style={{ "--delay": `${delay}ms` } as CSSProperties}
      className={cn("reveal", className)}
    >
      {children}
    </div>
  )
}
