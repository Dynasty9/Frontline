import { Link } from "react-router"
import { Button } from "@/components/ui/button"
import { SectionLabel } from "@/components/battles"
import { usePoll } from "@/hooks/use-poll"
import { fetchReplays, replayClock } from "@/lib/replays"

export function Replays() {
  const { data, error, loading } = usePoll(fetchReplays, 10_000)
  return (
    <section className="mx-auto max-w-6xl px-4 py-12 sm:px-6" aria-labelledby="watch-battles">
      <SectionLabel>See the battle unfold</SectionLabel>
      <h2 id="watch-battles" className="mt-3 font-display text-3xl font-bold uppercase">
        Watch Frontline
      </h2>
      <p className="mt-3 max-w-2xl text-muted-foreground">
        Follow a live battle or explore a recording. Move the camera yourself, follow the action, and rewind to see how
        a plan played out.
      </p>
      <p className="mt-2 text-sm text-muted-foreground">
        Public broadcasts run at least 60 seconds behind play. Recordings are kept for seven days.
      </p>
      {loading && <output className="mt-6 block">Looking for broadcasts…</output>}
      {error && <output className="mt-6 block text-muted-foreground">{error.message}</output>}
      {data && !data.replays.length && (
        <p className="mt-6 text-muted-foreground">
          {data.enabled
            ? "No recordings yet. Public battles hosted with a viewer-ready version of Frontline will appear here."
            : "Battle broadcasts are not enabled on this server yet."}
        </p>
      )}
      <div className="mt-8 divide-y border-y">
        {data?.replays.map((replay) => (
          <article key={replay.id} className="flex flex-wrap items-center justify-between gap-4 py-5">
            <div>
              <p className="font-mono text-xs text-primary uppercase">
                {replay.status === "live"
                  ? "Live · delayed"
                  : replay.status === "interrupted"
                    ? "Partial recording"
                    : "Replay"}{" "}
                · {replayClock(replay.duration)}
              </p>
              <h3 className="mt-2 font-display text-xl font-bold">{replay.name || "Frontline battle"}</h3>
              <p className="text-sm text-muted-foreground">
                Hosted by {replay.host} · {new Date(replay.created).toLocaleDateString()}
              </p>
            </div>
            <Button asChild variant={replay.status === "live" ? "default" : "outline"} className="min-h-11">
              <Link to={`/watch/${replay.id}`}>
                Watch {replay.status === "live" ? "battle" : "replay"}
                <span className="sr-only">: {replay.name}</span>
              </Link>
            </Button>
          </article>
        ))}
      </div>
    </section>
  )
}
