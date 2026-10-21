import { InsigniaImg } from "@/components/insignia-img"
import { wornInsignia } from "@/lib/insignia"
import { cn } from "@/lib/utils"

/**
 * A player's picture: the GitHub picture they've chosen (`avatar`), else the
 * insignia they wear. The alt is empty: their callsign is always beside it.
 */
export function PlayerAvatar({
  icon,
  avatar,
  className,
}: {
  icon: string | null
  avatar: string | null
  className?: string
}) {
  if (avatar) {
    return (
      <img
        src={avatar}
        alt=""
        loading="lazy"
        referrerPolicy="no-referrer"
        draggable={false}
        className={cn("size-6 shrink-0 rounded-sm bg-muted object-cover", className)}
      />
    )
  }
  const worn = wornInsignia(icon)
  return worn ? (
    <InsigniaImg id={worn.id} className={className} />
  ) : (
    <span className={cn("size-6 shrink-0", className)} />
  )
}
