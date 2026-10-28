import { ArrowRightIcon, ArrowSquareOutIcon } from "@phosphor-icons/react"
import { marked } from "marked"
import { useEffect, useMemo, useState } from "react"
import { SectionLabel } from "@/components/battles"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogTitle } from "@/components/ui/dialog"
import {
  type Entry,
  formatDate,
  type Kind,
  KIND_LABELS,
  KINDS,
  type Release,
  releases,
  screenshotsOf,
} from "@/lib/changelog"
import { useInView } from "@/hooks/use-in-view"
import { useReducedMotion } from "@/hooks/use-reduced-motion"
import { saveData } from "@/lib/media"
import { cn } from "@/lib/utils"

const KIND_STYLE: Record<Kind, string> = {
  new: "border-good/40 text-good",
  improved: "border-primary/40 text-primary",
  fixed: "border-sky-300/40 text-sky-300",
}

export function KindBadge({ kind }: { kind: Kind }) {
  return (
    <Badge variant="outline" className={cn("tracking-wider uppercase", KIND_STYLE[kind])}>
      {KIND_LABELS[kind]}
    </Badge>
  )
}

/** An entry's details: short markdown written for players, from the repo itself. */
function Details({ body }: { body: string }) {
  const html = useMemo(() => marked.parse(body, { async: false }), [body])
  if (!body) return null
  return (
    <div className="md mt-3 text-sm leading-relaxed text-muted-foreground" dangerouslySetInnerHTML={{ __html: html }} />
  )
}

type Shot = { url: string; caption: string }

/** Screenshots in a grid; click one to see it full size. */
function Screens({ shots, large = false }: { shots: Shot[]; large?: boolean }) {
  const [open, setOpen] = useState<Shot | null>(null)
  if (shots.length === 0) return null
  return (
    <>
      <div
        className={cn(
          "mt-4 grid gap-3",
          shots.length > 1 && "sm:grid-cols-2",
          large && shots.length === 1 && "max-w-3xl"
        )}
      >
        {shots.map((s) => (
          <figure key={s.url}>
            <button
              type="button"
              onClick={() => setOpen(s)}
              className="group block w-full overflow-hidden ring-1 ring-white/10"
              aria-label={`Enlarge: ${s.caption}`}
            >
              <img
                src={s.url}
                alt={s.caption}
                loading="lazy"
                className="aspect-video w-full object-cover transition-transform duration-300 group-hover:scale-[1.02]"
              />
            </button>
            {s.caption && <figcaption className="mt-1.5 text-xs text-muted-foreground">{s.caption}</figcaption>}
          </figure>
        ))}
      </div>
      <Dialog open={!!open} onOpenChange={(o) => !o && setOpen(null)}>
        <DialogContent className="max-w-[min(96vw,1600px)] gap-2 p-2 sm:max-w-[min(96vw,1600px)]">
          <DialogTitle className="sr-only">{open?.caption || "Screenshot"}</DialogTitle>
          {open && <img src={open.url} alt={open.caption} className="max-h-[85vh] w-full object-contain" />}
          <DialogDescription className="px-1 pb-1 text-sm">{open?.caption}</DialogDescription>
        </DialogContent>
      </Dialog>
    </>
  )
}

function Video({ video }: { video: NonNullable<Entry["videos"]>[number] }) {
  const [ref, inView] = useInView<HTMLVideoElement>({ threshold: 0.2 })
  const reduced = useReducedMotion()

  useEffect(() => {
    const el = ref.current
    if (!el) return
    if (inView && !reduced && !saveData()) el.play().catch(() => {})
    else el.pause()
  }, [inView, reduced, ref])

  return (
    <figure className="mt-4">
      <video
        ref={ref}
        loop
        src={video.url}
        poster={video.poster}
        controls
        playsInline
        muted
        preload="none"
        aria-label={video.caption}
        className="aspect-video w-full object-contain ring-1 ring-white/10"
      >
        <a href={video.url}>Watch: {video.caption}</a>
      </video>
      <figcaption className="mt-1.5 text-xs text-muted-foreground">{video.caption}</figcaption>
    </figure>
  )
}

function EntryBlock({ entry }: { entry: Entry }) {
  return (
    <article className="border-t pt-6 first:border-t-0 first:pt-0" id={entry.slug}>
      <div className="flex flex-wrap items-center gap-2">
        <KindBadge kind={entry.kind} />
        <h3 className="text-lg font-semibold">{entry.title}</h3>
      </div>
      <p className="mt-2 text-sm leading-relaxed">{entry.summary}</p>
      <Screens shots={entry.screenshots} />
      {entry.videos?.map((video) => (
        <Video key={video.url} video={video} />
      ))}
      <Details body={entry.body} />
    </article>
  )
}

/** One release: its name and summary, then each change, grouped by kind. */
export function ReleaseCard({ release, latest = false }: { release: Release; latest?: boolean }) {
  const entries = KINDS.flatMap((k) => release.entries.filter((e) => e.kind === k))
  return (
    <section id={release.tag} className="scroll-mt-20 border bg-card/60 p-5 sm:p-8">
      <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
        <span className="font-mono text-sm text-primary">{release.tag}</span>
        {latest && (
          <Badge variant="outline" className="border-good/40 text-good">
            Latest
          </Badge>
        )}
        <span className="text-sm text-muted-foreground">{formatDate(release.date)}</span>
        <a
          href={release.url}
          className="ml-auto inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground"
        >
          Release on GitHub
          <ArrowSquareOutIcon className="size-3.5" />
        </a>
      </div>
      <h2 className="mt-2 text-3xl font-semibold tracking-tight">{release.name}</h2>
      {/* a release's own summary, unless it only repeats its one change's */}
      {release.summary && !release.entries.some((e) => e.summary === release.summary) && (
        <p className="mt-3 max-w-3xl text-base leading-relaxed text-muted-foreground">{release.summary}</p>
      )}
      <div className="mt-8 space-y-6">
        {entries.map((e) => (
          <EntryBlock key={e.slug} entry={e} />
        ))}
      </div>
    </section>
  )
}

/** The front page's look at the latest release, linking to the full changelog. */
export function WhatsNew() {
  const latest = releases[0]
  if (!latest) return null
  // a picture from the latest release that has one
  const pictured = releases.find((r) => screenshotsOf(r).length > 0)
  const shot = pictured ? screenshotsOf(pictured)[0] : undefined
  return (
    <section id="whats-new" className="mx-auto max-w-6xl scroll-mt-16 px-4 pt-4 pb-20 sm:px-6">
      <SectionLabel>What's new</SectionLabel>
      <div className="mt-2 grid items-start gap-8 lg:grid-cols-[1fr_1.1fr]">
        <div>
          <h2 className="text-3xl font-semibold">
            <span className="mr-3 font-mono text-xl text-primary">{latest.tag}</span>
            {latest.name}
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">{formatDate(latest.date)}</p>
          <p className="mt-4 text-base leading-relaxed text-muted-foreground">{latest.summary}</p>
          <ul className="mt-5 space-y-2">
            {latest.entries.map((e) => (
              <li key={e.slug} className="flex items-start gap-2 text-sm">
                <KindBadge kind={e.kind} />
                <a href={`/changelog/#${latest.tag}`} className="hover:text-primary">
                  {e.title}
                </a>
              </li>
            ))}
          </ul>
          <div className="mt-6 flex flex-wrap items-center gap-x-5 gap-y-2">
            <Button variant="outline" asChild>
              <a href="/changelog/">
                The full changelog
                <ArrowRightIcon />
              </a>
            </Button>
            {releases.slice(1, 3).map((r) => (
              <a
                key={r.tag}
                href={`/changelog/#${r.tag}`}
                className="text-sm text-muted-foreground hover:text-foreground"
              >
                <span className="font-mono text-xs">{r.tag}</span> {r.name}
              </a>
            ))}
          </div>
        </div>
        {shot && (
          <a href={`/changelog/#${pictured?.tag ?? latest.tag}`} className="block">
            <img
              src={shot.url}
              // the caption below names the link; screen readers needn't hear it twice
              alt=""
              loading="lazy"
              className="aspect-video w-full object-cover ring-1 ring-white/10"
            />
            <span className="mt-1.5 block text-xs text-muted-foreground">
              {/* from an earlier release when the latest has no pictures: say which */}
              {pictured && pictured !== latest && `${pictured.tag} ${pictured.name}: `}
              {shot.caption}
            </span>
          </a>
        )}
      </div>
    </section>
  )
}
