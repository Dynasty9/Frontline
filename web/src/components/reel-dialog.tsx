import { XIcon } from "@phosphor-icons/react"
import { Dialog as DialogPrimitive } from "radix-ui"
import { HudCorners } from "@/components/footage"
import {
  Dialog,
  DialogClose,
  DialogDescription,
  DialogOverlay,
  DialogPortal,
  DialogTitle,
} from "@/components/ui/dialog"
import { media } from "@/lib/media"

type Props = {
  open: boolean
  onClose: () => void
}

/**
 * The full reel, with the game's own sound, over a darkened page. Escape or a
 * click outside closes it, and closing unmounts the video, so the sound stops.
 * Its captions describe what you'd hear (there's no speech).
 */
export function ReelDialog({ open, onClose }: Props) {
  return (
    <Dialog open={open} onOpenChange={(o) => !o && onClose()}>
      <DialogPortal>
        <DialogOverlay className="bg-black/85!" />
        <DialogPrimitive.Content className="fixed top-1/2 left-1/2 z-50 w-[min(92vw,1280px)] -translate-x-1/2 -translate-y-1/2 outline-none data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0">
          <DialogTitle className="sr-only">Frontline gameplay footage</DialogTitle>
          <DialogDescription className="sr-only">
            Thirty seconds recorded in the game, with its own sound.
          </DialogDescription>
          <div className="relative">
            <video
              src={media("reel", "mp4")}
              poster={media("reel", "jpg")}
              controls
              autoPlay
              playsInline
              className="aspect-video w-full bg-black ring-1 ring-white/15"
            >
              <track kind="captions" src={media("reel", "vtt")} srcLang="en" label="Sound descriptions" />
            </video>
            <HudCorners />
            <DialogClose asChild>
              <button
                type="button"
                className="absolute -top-11 right-0 inline-flex items-center gap-1.5 px-2 py-1.5 text-xs font-bold tracking-[0.2em] text-cream/80 uppercase hover:text-foreground"
              >
                Close
                <XIcon weight="bold" className="size-4" />
              </button>
            </DialogClose>
          </div>
        </DialogPrimitive.Content>
      </DialogPortal>
    </Dialog>
  )
}
