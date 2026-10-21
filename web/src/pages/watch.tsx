import { useQuery } from "@tanstack/react-query"
import { useCallback, useState } from "react"
import { Link, useParams } from "react-router"
import { Button } from "@/components/ui/button"
import { usePoll } from "@/hooks/use-poll"
import { usePageTitle } from "@/hooks/use-page-title"
import { fetchReplay, replaySource } from "@/lib/replays"

export default function WatchPage() {
  const { id = "" } = useParams()
  const load = useCallback((signal: AbortSignal) => fetchReplay(id, signal), [id])
  const { data, error } = usePoll(load, 10_000)
  const [startedId, setStartedId] = useState<string | null>(null)
  const started = startedId === id
  usePageTitle(data?.name || "Watch battle")
  const build = useQuery({
    queryKey: ["viewer-build"],
    queryFn: async ({ signal }) => {
      const response = await fetch("/game/viewer.json", { signal })
      if (!response.ok) return null
      return response.json() as Promise<{ format: number; protocol: number }>
    },
    retry: false,
  })
  const available = build.isPending ? null : build.data?.format === 1 && build.data?.protocol === data?.protocol
  return (
    <section className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
      <Link to="/battles" className="text-sm text-muted-foreground underline underline-offset-4">
        Back to battles
      </Link>
      <p className="mt-6 font-mono text-xs text-primary uppercase">
        {data?.status === "live" ? "Live broadcast · 60-second delay" : "Battle replay"}
      </p>
      <h1 className="mt-2 font-display text-4xl font-bold uppercase">{data?.name || "Watch the battle"}</h1>
      {error && (
        <p role="alert" className="mt-6">
          {error.message}
        </p>
      )}
      {data && (
        <>
          <p className="mt-3 text-muted-foreground">
            Hosted by {data.host}. This is the game itself: move the camera, follow the action, and use the timeline to
            revisit a moment.
          </p>
          <div className="mt-6 border bg-background">
            {started ? (
              <iframe
                key={id}
                title={`Frontline battle: ${data.name}`}
                // The bundled Godot runtime needs same-origin asset access; replay files contain data only.
                // oxlint-disable-next-line react/iframe-missing-sandbox
                sandbox="allow-scripts allow-same-origin allow-pointer-lock"
                className="h-[75svh] min-h-96 w-full"
                src={`/game/index.html?replay=${encodeURIComponent(replaySource(id))}`}
                allow="fullscreen; autoplay"
                allowFullScreen
              />
            ) : (
              <div className="flex min-h-80 flex-col items-center justify-center gap-5 p-8 text-center">
                <p>
                  {!data.chunks.length
                    ? "The broadcast is gathering its first minute. It will be ready shortly."
                    : available === null
                      ? "Checking the viewer…"
                      : available
                        ? "Take a seat at the command table."
                        : "A compatible browser viewer is not available on this site yet."}
                </p>
                <Button
                  className="min-h-11"
                  disabled={!available || !data.chunks.length}
                  onClick={() => setStartedId(id)}
                >
                  Open battlefield
                </Button>
                <p className="max-w-lg text-sm text-muted-foreground">
                  The 3D viewer downloads game assets and works best on a desktop browser with WebGL 2.
                </p>
              </div>
            )}
          </div>
          <p className="mt-4 text-sm text-muted-foreground">
            {data.status === "interrupted"
              ? "The host stopped broadcasting. The recorded part is still available. "
              : ""}
            Recorded by the host. The result has not been independently verified.
          </p>
        </>
      )}
    </section>
  )
}
