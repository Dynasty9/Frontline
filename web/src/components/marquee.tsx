import { Fragment } from "react"
import { Emblem } from "@/components/emblem"
import { HARDWARE, TICKER } from "@/lib/intel"
import { cn } from "@/lib/utils"

type Props = {
  items: string[]
  reverse?: boolean
  /** seconds for one full pass */
  time?: number
  className?: string
  itemClassName?: string
  mark?: React.ReactNode
}

/** An endless ticker: the row twice over, sliding left by one row's width, so the join never shows. */
export function Marquee({ items, reverse, time = 60, className, itemClassName, mark }: Props) {
  const row = (copy: number) =>
    items.map((it, i) => (
      <Fragment key={`${copy}-${i}`}>
        <span className={cn("px-6 whitespace-nowrap", itemClassName)}>{it}</span>
        <span className="flex items-center" aria-hidden="true">
          {mark ?? "✦"}
        </span>
      </Fragment>
    ))
  return (
    <div className={cn("overflow-hidden", className)}>
      <div
        className="marquee"
        data-reverse={reverse || undefined}
        style={{ "--marquee-time": `${time}s` } as React.CSSProperties}
      >
        <div className="flex items-center">{row(0)}</div>
        <div className="flex items-center" aria-hidden="true">
          {row(1)}
        </div>
      </div>
    </div>
  )
}

/** Two bands crossing under the hero, like tape across a crate: what you'll do, and what you'll do it with. */
export function TickerBands() {
  const band = "absolute inset-x-[-3rem] top-1/2 -translate-y-1/2"
  return (
    <div className="relative z-10 -mt-10 h-36 overflow-hidden" role="presentation">
      <Marquee
        items={HARDWARE}
        reverse
        time={70}
        className={cn(band, "rotate-[2deg] border-y border-white/10 bg-card py-2.5")}
        itemClassName="font-display text-xl font-bold tracking-wider uppercase text-outline"
        mark={<span className="size-1.5 rotate-45 bg-primary/60" />}
      />
      <Marquee
        items={TICKER}
        time={55}
        className={cn(
          band,
          "-rotate-[2deg] bg-primary py-3 text-primary-foreground shadow-[0_10px_40px_-10px_rgb(245_201_110/0.5)]"
        )}
        itemClassName="font-display text-2xl font-extrabold tracking-wide uppercase"
        mark={<Emblem className="size-5 [&_circle]:fill-[#15120b] [&_path]:stroke-[#15120b]" />}
      />
    </div>
  )
}
