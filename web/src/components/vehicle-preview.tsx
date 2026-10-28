import { useEffect, useRef, useState } from "react"
import {
  ArrowCounterClockwiseIcon,
  ArrowClockwiseIcon,
  MinusIcon,
  PlusIcon,
  ArrowsCounterClockwiseIcon,
} from "@phosphor-icons/react"
import { HudCorners } from "@/components/footage"
import { Button } from "@/components/ui/button"
import type { Vehicle } from "@/lib/vehicles"

export function VehiclePreview({ vehicle, available }: { vehicle: Vehicle; available: boolean | null }) {
  const frame = useRef<HTMLIFrameElement>(null)
  const [ready, setReady] = useState(false)
  const [failed, setFailed] = useState(false)
  const [attempt, setAttempt] = useState(0)
  useEffect(() => {
    if (!available) return
    const timer = window.setTimeout(() => setFailed(true), 90_000)
    const onMessage = (event: MessageEvent) => {
      if (
        event.origin !== window.location.origin ||
        event.source !== frame.current?.contentWindow ||
        event.data?.type !== "frontline-model-ready" ||
        event.data.key !== vehicle.id
      )
        return
      window.clearTimeout(timer)
      setReady(true)
      setFailed(false)
    }
    window.addEventListener("message", onMessage)
    return () => {
      window.clearTimeout(timer)
      window.removeEventListener("message", onMessage)
    }
    // A retry mounts a new frame, so its readiness timeout must restart too.
    // oxlint-disable-next-line react/exhaustive-effect-dependencies
  }, [available, vehicle.id, attempt])
  const control = (action: string) =>
    frame.current?.contentWindow?.postMessage({ type: "frontline-model", action }, window.location.origin)
  return (
    <div>
      <div className="relative aspect-[4/3] overflow-hidden bg-[#08090a] sm:aspect-[16/10]">
        {available && (
          <iframe
            key={attempt}
            ref={frame}
            title={`3D model of ${vehicle.name}`}
            // The bundled model stage needs same-origin access to its own assets.
            // oxlint-disable-next-line react/iframe-missing-sandbox
            sandbox="allow-scripts allow-same-origin"
            className={`absolute inset-0 size-full ${ready ? "opacity-100" : "opacity-0"}`}
            src={`/game/index.html?manual=${encodeURIComponent(vehicle.id)}`}
            tabIndex={-1}
          />
        )}
        {!ready && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 p-8 text-center">
            <span aria-hidden="true" className="h-10 w-px bg-primary" />
            <p className="font-mono text-xs tracking-widest text-muted-foreground uppercase" role="alert">
              {failed
                ? "The model is taking longer than expected."
                : available === null
                  ? "Checking 3D preview…"
                  : available
                    ? "Preparing your vehicle…"
                    : "3D preview unavailable"}
            </p>
            {(available || failed) && (
              <p className="max-w-xs text-xs leading-relaxed text-muted-foreground">
                The first model downloads the 3D assets. A WebGL 2 browser is required.
              </p>
            )}
            {failed && (
              <Button
                variant="outline"
                onClick={() => {
                  setFailed(false)
                  setReady(false)
                  setAttempt(attempt + 1)
                }}
              >
                Retry preview
              </Button>
            )}
          </div>
        )}
        <HudCorners inset="0.75rem" />
        <div className="pointer-events-none absolute top-4 left-5 font-mono text-[10px] tracking-[0.18em] text-primary uppercase">
          Model inspection
        </div>
      </div>
      <div className="flex flex-wrap items-center justify-between gap-3 border-y px-4 py-3">
        <span className="font-mono text-[10px] tracking-wider text-muted-foreground uppercase">
          Drag to rotate · Scroll to zoom
        </span>
        <div className="flex gap-1">
          {(
            [
              ["left", "Rotate left", ArrowCounterClockwiseIcon],
              ["right", "Rotate right", ArrowClockwiseIcon],
              ["zoom-in", "Zoom in", PlusIcon],
              ["zoom-out", "Zoom out", MinusIcon],
              ["reset", "Reset view", ArrowsCounterClockwiseIcon],
            ] as const
          ).map(([action, label, Icon]) => (
            <Button
              key={action}
              variant="ghost"
              size="icon"
              className="size-11"
              aria-label={label}
              disabled={!ready}
              onClick={() => control(action)}
            >
              <Icon className="size-4" />
            </Button>
          ))}
        </div>
      </div>
    </div>
  )
}
