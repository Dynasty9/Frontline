import { insigniaUrl } from "@/lib/insignia"
import { cn } from "@/lib/utils"

/** An insignia's art. The alt is empty: a name is always shown or read out beside it. */
export function InsigniaImg({ id, className }: { id: string; className?: string }) {
  return (
    <img
      src={insigniaUrl(id)}
      alt=""
      loading="lazy"
      width={128}
      height={128}
      draggable={false}
      className={cn("size-6 shrink-0 object-contain", className)}
    />
  )
}
