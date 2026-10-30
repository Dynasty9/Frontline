import { ArrowRightIcon, ArrowSquareOutIcon, CaretDownIcon } from "@phosphor-icons/react"
import { marked } from "marked"
import { useEffect, useMemo, useState } from "react"
import { SectionLabel } from "@/components/battles"
import { Badge } from "@/components/ui/badge"
import { Button, buttonVariants } from "@/components/ui/button"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
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
        className={cn("mt-4 grid gap-3", shots.length > 1 && "sm:grid-cols-2", large && shots.length === 1 && "mt-0")}
      >
        {shots.map((s) => (
          <figure key={s.url}>
            <button
              type="button"
              onClick={() => setOpen(s)}
              className="group block w-full overflow-hidden bg-background focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-primary"
              aria-label={`Enlarge: ${s.caption}`}
            >
              <img
                src={s.url}
                alt={s.caption}
                loading="lazy"
                className={cn("w-full object-contain", large ? "max-h-[460px]" : "aspect-video")}
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

type MotionClip = NonNullable<Entry["videos"]>[number]

function Gif({ video }: { video: MotionClip }) {
  const [ref, inView] = useInView<HTMLElement>({ threshold: 0.2 })
  const reduced = useReducedMotion()
  const [playing, setPlaying] = useState<boolean | null>(null)
  const active = inView && (playing ?? (!reduced && !saveData()))
  return (
    <figure ref={ref} className="mt-4">
      <img
        src={active ? video.url : video.poster}
        alt={video.caption}
        loading="lazy"
        className="aspect-video w-full object-contain ring-1 ring-white/10"
      />
      <figcaption className="mt-1.5 flex items-center justify-between gap-3 text-xs text-muted-foreground">
        {video.caption}
        <Button
          variant="outline"
          size="sm"
          onClick={() => setPlaying(!active)}
          aria-label={`${active ? "Pause" : "Play"} animation: ${video.caption}`}
        >
          {active ? "Pause animation" : "Play animation"}
        </Button>
      </figcaption>
    </figure>
  )
}

function Video({ video }: { video: MotionClip }) {
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

function Clip({ video }: { video: MotionClip }) {
  return /\.gif(?:[?#]|$)/i.test(video.url) ? <Gif video={video} /> : <Video video={video} />
}

function EntryBlock({ entry, releaseTag, headline }: { entry: Entry; releaseTag: string; headline: boolean }) {
  const leadClip = entry.videos?.[0]
  const extraShots = leadClip ? entry.screenshots : entry.screenshots.slice(1)
  const extraClips = entry.videos?.slice(1) ?? []
  const hasMedia = !!leadClip || entry.screenshots.length > 0
  const hasDetails = !!entry.body || extraShots.length > 0 || extraClips.length > 0
  return (
    <article className="scroll-mt-24 border-t py-8 first:border-t-0 first:pt-0" id={`${releaseTag}-${entry.slug}`}>
      <div
        className={cn(
          "grid items-start gap-6",
          hasMedia && "md:grid-cols-[minmax(0,0.85fr)_minmax(0,1.35fr)] md:gap-8"
        )}
      >
        <div>
          <KindBadge kind={entry.kind} />
          <h3 className={cn("mt-3 font-display text-3xl leading-tight font-bold uppercase", headline && "sr-only")}>
            {entry.title}
          </h3>
          <p className="mt-3 max-w-prose text-base leading-relaxed text-muted-foreground">{entry.summary}</p>
        </div>
        {hasMedia && (
          <div className="min-w-0 [&>figure]:mt-0">
            {leadClip ? <Clip video={leadClip} /> : <Screens shots={entry.screenshots.slice(0, 1)} large />}
          </div>
        )}
      </div>
      {hasDetails && (
        <details className="group mt-5">
          <summary
            className={cn(
              buttonVariants({ variant: "ghost", size: "sm" }),
              "cursor-pointer list-none gap-2 px-0 text-primary hover:bg-transparent [&::-webkit-details-marker]:hidden"
            )}
          >
            <CaretDownIcon className="group-open:rotate-180" />
            Explore this change<span className="sr-only">: {entry.title}</span>
          </summary>
          <div className="mt-4 border-l border-primary/30 pl-5 sm:pl-6">
            <Details body={entry.body} />
            <Screens shots={extraShots} />
            {extraClips.map((video) => (
              <Clip key={video.url} video={video} />
            ))}
            <Button variant="link" size="sm" asChild className="mt-4 px-0 text-muted-foreground">
              <a href={`#${releaseTag}-${entry.slug}`}>
                Link to this change <ArrowRightIcon />
              </a>
            </Button>
          </div>
        </details>
      )}
      {entry.layoutComparison && (
        <details className="group mt-3 border-t border-dashed pt-3">
          <summary
            className={cn(
              buttonVariants({ variant: "ghost", size: "sm" }),
              "cursor-pointer list-none gap-2 px-0 text-muted-foreground hover:bg-transparent [&::-webkit-details-marker]:hidden"
            )}
          >
            <CaretDownIcon className="group-open:rotate-180" />
            Compare changelog layouts<span className="sr-only">: {entry.title}</span>
          </summary>
          <p className="mt-3 max-w-prose text-xs leading-relaxed text-muted-foreground">
            {entry.layoutComparison.caption}
          </p>
          <Screens
            shots={[
              { url: entry.layoutComparison.before, caption: `Before: old changelog layout — ${entry.title}` },
              { url: entry.layoutComparison.after, caption: `After: new changelog layout — ${entry.title}` },
            ]}
            large
          />
        </details>
      )}
    </article>
  )
}

/** The site's shared shadcn Card primitives, styled with Signal's rules instead of nested frames. */
export function ReleaseCard({ release, latest = false }: { release: Release; latest?: boolean }) {
  const entries = KINDS.flatMap((k) => release.entries.filter((e) => e.kind === k))
  return (
    <section id={release.tag} className="scroll-mt-24 border-t border-primary/30">
      <Card className="gap-0 overflow-visible bg-transparent py-0 ring-0">
        <CardHeader className="gap-4 px-0 pt-6 pb-8">
          <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
            <span className="font-mono text-xs tracking-wider text-primary">{release.tag}</span>
            {latest && (
              <Badge variant="outline" className="border-primary/40 text-primary">
                Latest
              </Badge>
            )}
            <span className="text-xs text-muted-foreground">{formatDate(release.date)}</span>
            <Button variant="ghost" size="sm" asChild className="ml-auto h-auto px-0 text-xs text-muted-foreground">
              <a href={release.url}>
                Release on GitHub <ArrowSquareOutIcon />
              </a>
            </Button>
          </div>
          <h2 className="max-w-2xl font-display text-4xl leading-none font-bold uppercase sm:text-5xl">
            {release.name}
          </h2>
          {release.summary && !release.entries.some((e) => e.summary === release.summary) && (
            <p className="max-w-2xl text-base leading-relaxed text-muted-foreground">{release.summary}</p>
          )}
        </CardHeader>
        <CardContent className="px-0">
          {entries.map((e) => (
            <EntryBlock key={e.slug} entry={e} releaseTag={release.tag} headline={e.title === release.name} />
          ))}
        </CardContent>
      </Card>
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
