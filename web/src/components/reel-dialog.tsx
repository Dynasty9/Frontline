import { useState } from "react"
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
  const [film, setFilm] = useState<"reel" | "vehicles">("reel")
  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (!next) {
          setFilm("reel")
          onClose()
        }
      }}
    >
      <DialogPortal>
        <DialogOverlay className="bg-black/85!" />
        <DialogPrimitive.Content className="fixed top-1/2 left-1/2 z-50 w-[min(92vw,1280px,calc((100dvh-6rem)*16/9))] -translate-x-1/2 -translate-y-1/2 outline-none data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0">
          <DialogTitle className="sr-only">Frontline gameplay footage</DialogTitle>
          <DialogDescription className="sr-only">
            Choose battle highlights with game audio and captions, or browse the silent vehicle roll call.
          </DialogDescription>
          <div className="relative">
            <fieldset aria-label="Choose footage" className="absolute -top-11 left-0 flex gap-1">
              {(["reel", "vehicles"] as const).map((name) => (
                <button
                  key={name}
                  type="button"
                  aria-pressed={film === name}
                  onClick={() => setFilm(name)}
                  className="px-2 py-1.5 text-xs font-bold text-cream/70 hover:text-foreground aria-pressed:bg-cream/15 aria-pressed:text-cream"
                >
                  {name === "reel" ? "Battle highlights" : "Vehicle roll call"}
                </button>
              ))}
            </fieldset>
            {/* oxlint-disable-next-line jsx-a11y/media-has-caption -- The highlights have captions below. The vehicle roll call is silent. */}
            <video
              key={film}
              aria-label={film === "reel" ? "Battle highlights" : "Vehicle roll call"}
              muted={film === "vehicles"}
              loop={film === "vehicles"}
              src={media(film, "mp4")}
              poster={media(film, "jpg")}
              controls
              autoPlay
              playsInline
              className="aspect-video w-full bg-black ring-1 ring-white/15"
            >
              {film === "reel" && (
                <track kind="captions" src={media("reel", "vtt")} srcLang="en" label="Sound descriptions" />
              )}
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
