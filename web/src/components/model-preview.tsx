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
import type { Entry } from "@/lib/manual"

/** What the viewer needs of a manual entry: its key, its name, and a sortie to fly if it has one. */
type Model = Pick<Entry, "id" | "name" | "support">

/**
 * The Field Manual's model stage from the game itself (its browser build at
 * /game/, opened on one entry with ?manual=<key>), turned over with the
 * buttons or by dragging. It stays loaded while the visitor picks one entry
 * after another: each is sent to it, and it says when it's showing it.
 */
export function ModelPreview({ entry, available }: { entry: Model; available: boolean | null }) {
  const frame = useRef<HTMLIFrameElement>(null)
  const statusObserver = useRef<MutationObserver | null>(null)
  const [startupError, setStartupError] = useState<string | null>(null)
  const [initialId] = useState(entry.id)
  const [loaded, setLoaded] = useState(false)
  const [shownId, setShownId] = useState<string | null>(null)
  const [demoId, setDemoId] = useState<string | null>(null)
  const [demoReady, setDemoReady] = useState(false)
  const [demoEnded, setDemoEnded] = useState(false)
  const demo = demoId === entry.id
  const ready = !startupError && (demo ? demoReady : shownId === entry.id)
  const [failedId, setFailedId] = useState<string | null>(null)
  const failed = !!startupError || (failedId === entry.id && !ready)
  const [attempt, setAttempt] = useState(0)
  useEffect(() => () => statusObserver.current?.disconnect(), [])
  const readViewerStatus = () => {
    statusObserver.current?.disconnect()
    const doc = frame.current?.contentDocument
    if (!doc?.body) return
    // Godot's same-origin export reports startup failures inside its hidden loading overlay.
    const read = () => {
      const error = doc.getElementById("status-notice")?.textContent?.trim()
      if (error) setStartupError(error)
    }
    read()
    statusObserver.current = new MutationObserver(read)
    statusObserver.current.observe(doc.body, { childList: true, characterData: true, subtree: true })
  }
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
      { type: "frontline-model", action: "select", key: entry.id },
      window.location.origin
    )
  }, [loaded, entry.id])
  useEffect(() => {
    if (!available || ready) return
    const timer = window.setTimeout(() => setFailedId(entry.id), 90_000)
    return () => window.clearTimeout(timer)
    // A retry mounts a new frame, so its readiness timeout must restart too.
    // oxlint-disable-next-line react/exhaustive-effect-dependencies
  }, [available, ready, entry.id, attempt])
  const control = (action: string) =>
    frame.current?.contentWindow?.postMessage({ type: "frontline-model", action }, window.location.origin)
  const playDemo = () => {
    if (!entry.support) return
    setDemoId(entry.id)
    setDemoReady(false)
    setDemoEnded(false)
    frame.current?.contentWindow?.postMessage(
      { type: "frontline-model", action: "demo", key: entry.support.id },
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
            onLoad={readViewerStatus}
            title={`3D model of ${entry.name}`}
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
              {startupError
                ? "3D preview couldn't start"
                : failed
                  ? "The model is taking longer than expected."
                  : available === null
                    ? "Checking 3D preview…"
                    : available
                      ? demo
                        ? "Preparing the training range…"
                        : "Preparing the model…"
                      : "3D preview unavailable"}
            </p>
            {(available || failed) && (
              <p className="max-w-xs text-xs leading-relaxed text-muted-foreground">
                {startupError
                  ? /webgl/i.test(startupError)
                    ? "This preview needs WebGL 2. Enable graphics acceleration in your browser, or try another browser. You can still read its details below."
                    : "The 3D viewer couldn't load. Check your connection and retry. You can still read its details below."
                  : demo
                    ? "Resetting the aircraft and range targets."
                    : "The first model downloads the game's 3D viewer. A WebGL 2 browser is required."}
              </p>
            )}
            {failed && (
              <Button
                variant="outline"
                onClick={() => {
                  setFailedId(null)
                  setStartupError(null)
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
      {startupError && (
        <details className="border-t py-3 text-xs text-muted-foreground">
          <summary className="cursor-pointer">Technical details</summary>
          <p className="mt-2 break-words whitespace-pre-wrap">{startupError}</p>
        </details>
      )}
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
                    { type: "frontline-model", action: "select", key: entry.id },
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
              {entry.support && (
                <Button variant="outline" disabled={!ready} onClick={playDemo}>
                  {entry.support.shape === "strafe" ? "Watch gun run" : "Watch air support"}
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
