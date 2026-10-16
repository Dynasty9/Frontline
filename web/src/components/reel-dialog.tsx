import { XIcon } from "@phosphor-icons/react"
import { useEffect, useRef } from "react"
import { HudCorners } from "@/components/footage"
import { media } from "@/lib/media"

type Props = {
  open: boolean
  onClose: () => void
}

/** The full reel, with the game's own sound, in a modal (Escape or a click outside closes it). */
export function ReelDialog({ open, onClose }: Props) {
  const dlg = useRef<HTMLDialogElement>(null)
  const video = useRef<HTMLVideoElement>(null)

  useEffect(() => {
    const d = dlg.current
    const v = video.current
    if (!d || !v) return
    if (open) {
      if (!d.open) d.showModal()
      v.currentTime = 0
      v.play().catch(() => {})
    } else {
      v.pause()
      if (d.open) d.close()
    }
  }, [open])

  return (
    <dialog
      ref={dlg}
      onClose={onClose}
      onClick={(e) => {
        if (e.target === dlg.current) onClose()
      }}
      aria-label="Frontline gameplay footage"
      className="m-auto w-[min(92vw,1280px)] overflow-visible bg-transparent p-0 text-foreground backdrop:bg-black/85 backdrop:backdrop-blur-sm"
    >
      <div className="relative">
        <video
          ref={video}
          src={media("reel", "mp4")}
          poster={media("reel", "jpg")}
          controls
          playsInline
          preload="none"
          className="aspect-video w-full bg-black ring-1 ring-white/15"
        />
        <HudCorners />
        <button
          type="button"
          onClick={onClose}
          className="absolute -top-11 right-0 inline-flex items-center gap-1.5 px-2 py-1.5 text-xs font-bold tracking-[0.2em] text-cream/80 uppercase hover:text-foreground"
        >
          Close
          <XIcon weight="bold" className="size-4" />
        </button>
      </div>
    </dialog>
  )
}
