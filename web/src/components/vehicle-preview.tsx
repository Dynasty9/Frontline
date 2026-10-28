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
  const [initialId] = useState(vehicle.id)
  const [loaded, setLoaded] = useState(false)
  const [shownId, setShownId] = useState<string | null>(null)
  const [demoId, setDemoId] = useState<string | null>(null)
  const [demoReady, setDemoReady] = useState(false)
  const [demoEnded, setDemoEnded] = useState(false)
  const demo = demoId === vehicle.id
  const ready = demo ? demoReady : shownId === vehicle.id
  const [failedId, setFailedId] = useState<string | null>(null)
  const failed = failedId === vehicle.id && !ready
  const [attempt, setAttempt] = useState(0)
  useEffect(() => {
    if (!available) return
    const onMessage = (event: MessageEvent) => {
      if (event.origin !== window.location.origin || event.source !== frame.current?.contentWindow) return
      if (event.data?.type === "frontline-model-loaded") setLoaded(true)
      if (event.data?.type === "frontline-model-ready" && typeof event.data.key === "string") {
        setShownId(event.data.key)
        setFailedId(null)
        setDemoId(null)
      }
      if (event.data?.type === "frontline-demo-ready") setDemoReady(true)
      if (event.data?.type === "frontline-demo-ended") setDemoEnded(true)
    }
    window.addEventListener("message", onMessage)
    return () => {
      window.removeEventListener("message", onMessage)
    }
  }, [available])
  useEffect(() => {
    if (!loaded) return
    frame.current?.contentWindow?.postMessage(
      { type: "frontline-model", action: "select", key: vehicle.id },
      window.location.origin
    )
  }, [loaded, vehicle.id])
  useEffect(() => {
    if (!available || ready) return
    const timer = window.setTimeout(() => setFailedId(vehicle.id), 90_000)
    return () => window.clearTimeout(timer)
    // A retry mounts a new frame, so its readiness timeout must restart too.
    // oxlint-disable-next-line react/exhaustive-effect-dependencies
  }, [available, ready, vehicle.id, attempt])
  const control = (action: string) =>
    frame.current?.contentWindow?.postMessage({ type: "frontline-model", action }, window.location.origin)
  const playDemo = () => {
    if (!vehicle.support) return
    setDemoId(vehicle.id)
    setDemoReady(false)
    setDemoEnded(false)
    frame.current?.contentWindow?.postMessage(
      { type: "frontline-model", action: "demo", key: vehicle.support.id },
      window.location.origin
    )
  }
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
            allow="autoplay"
            className={`absolute inset-0 size-full ${ready ? "opacity-100" : "opacity-0"}`}
            src={`/game/index.html?manual=${encodeURIComponent(initialId)}`}
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
                    ? demo
                      ? "Preparing the training range…"
                      : "Preparing your vehicle…"
                    : "3D preview unavailable"}
            </p>
            {(available || failed) && (
              <p className="max-w-xs text-xs leading-relaxed text-muted-foreground">
                {demo
                  ? "Resetting the aircraft and range targets."
                  : "The first model downloads the 3D assets. A WebGL 2 browser is required."}
              </p>
            )}
            {failed && (
              <Button
                variant="outline"
                onClick={() => {
                  setFailedId(null)
                  setLoaded(false)
                  setShownId(null)
                  setDemoId(null)
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
          {demo ? "Live training range" : "Model inspection"}
        </div>
        {demo && ready && (
          <output className="absolute bottom-4 left-5 rounded-sm bg-background/85 px-3 py-2 font-mono text-[10px] tracking-wider uppercase">
            {demoEnded ? "Sortie complete" : "Air support inbound"}
          </output>
        )}
      </div>
      <div className="flex flex-wrap items-center justify-between gap-3 border-y px-4 py-3">
        <span className="font-mono text-[10px] tracking-wider text-muted-foreground uppercase">
          {demo ? "In-game flight, weapons & impacts" : "Drag to rotate · Scroll to zoom"}
        </span>
        <div className="flex gap-1">
          {demo ? (
            <>
              <Button
                variant="ghost"
                onClick={() => {
                  setDemoId(null)
                  setShownId(null)
                  frame.current?.contentWindow?.postMessage(
                    { type: "frontline-model", action: "select", key: vehicle.id },
                    window.location.origin
                  )
                }}
              >
                Back to model
              </Button>
              <Button variant="outline" disabled={!ready} onClick={playDemo}>
                Replay sortie
              </Button>
            </>
          ) : (
            <>
              {vehicle.support && (
                <Button variant="outline" disabled={!ready} onClick={playDemo}>
                  {vehicle.support.shape === "strafe" ? "Watch gun run" : "Watch air support"}
                </Button>
              )}
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
            </>
          )}
        </div>
      </div>
    </div>
  )
}
