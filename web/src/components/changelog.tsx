import { ArrowLeftIcon, ArrowRightIcon, ArrowSquareOutIcon, CaretDownIcon } from "@phosphor-icons/react"
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

/** Only the selected item mounts a player; thumbnails never download the other clips. */
function EntryGallery({ entry }: { entry: Entry }) {
  const media = [
    ...(entry.videos ?? []).map((video) => ({ ...video, video: true, thumbnail: video.poster })),
    ...entry.screenshots.map((shot) => ({ ...shot, video: false, thumbnail: shot.url, poster: "" })),
  ]
  const [selected, setSelected] = useState(0)
  const item = media[selected]
  if (!item) return null
  return (
    <div aria-label="Change gallery" className="min-w-0">
      <div key={item.url} className="[&>figure]:mt-0">
        {item.video ? <Clip video={item} /> : <Screens shots={[item]} large />}
      </div>
      {media.length > 1 && (
        <div className="mt-4">
          <p className="mb-2 font-mono text-xs text-muted-foreground" aria-live="polite">
            {selected + 1} / {media.length} · {item.video ? "Video" : "Image"}
          </p>
          <div className="flex gap-2 overflow-x-auto pb-2" aria-label="Choose an image or video">
            {media.map((m, i) => (
              <button
                key={m.url}
                type="button"
                aria-label={`${m.video ? "Video" : "Image"} ${i + 1}: ${m.caption}`}
                aria-pressed={selected === i}
                onClick={() => setSelected(i)}
                className="relative w-24 shrink-0 border-2 border-transparent p-0.5 opacity-60 hover:opacity-100 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary aria-pressed:border-primary aria-pressed:opacity-100"
              >
                <img src={m.thumbnail} alt="" loading="lazy" className="aspect-video w-full object-cover" />
                {m.video && (
                  <span className="absolute right-1 bottom-1 bg-background/90 px-1 font-mono text-[10px] text-foreground">
                    VIDEO
                  </span>
                )}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

function EntryBlock({
  entry,
  releaseTag,
  index,
  total,
  move,
}: {
  entry: Entry
  releaseTag: string
  index: number
  total: number
  move: (index: number) => void
}) {
  const [open, setOpen] = useState(false)
  const preview = entry.videos?.[0]?.poster ?? entry.screenshots[0]?.url
  return (
    <details
      id={`${releaseTag}-${entry.slug}`}
      name={`changes-${releaseTag}`}
      className="group/entry scroll-mt-24 border-t"
      onToggle={(event) => setOpen(event.currentTarget.open)}
    >
      <summary className="flex cursor-pointer list-none items-center gap-3 py-4 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-primary sm:gap-4 [&::-webkit-details-marker]:hidden">
        {preview && (
          <img
            src={preview}
            alt=""
            loading="lazy"
            className="hidden aspect-video w-24 shrink-0 object-cover sm:block"
          />
        )}
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
            <h3 className="font-display text-xl leading-tight font-semibold sm:text-2xl">{entry.title}</h3>
            <KindBadge kind={entry.kind} />
          </div>
          <p className="mt-1 line-clamp-1 text-sm leading-relaxed text-muted-foreground group-open/entry:line-clamp-none">
            {entry.summary}
          </p>
        </div>
        <CaretDownIcon
          aria-hidden="true"
          className="size-4 shrink-0 text-primary transition-transform group-open/entry:rotate-180 motion-reduce:transition-none"
        />
      </summary>
      {open && (
        <div className="pb-6">
          <nav
            aria-label="Browse changes"
            className="mb-4 flex flex-wrap items-center justify-between gap-2 border-y py-2"
          >
            <span className="font-mono text-xs text-muted-foreground">
              Change {index + 1} of {total}
            </span>
            <div className="flex gap-1">
              <Button variant="ghost" size="sm" disabled={index === 0} onClick={() => move(index - 1)}>
                <ArrowLeftIcon />
                Previous change
              </Button>
              <Button variant="outline" size="sm" disabled={index === total - 1} onClick={() => move(index + 1)}>
                Next change
                <ArrowRightIcon />
              </Button>
            </div>
          </nav>
          <EntryGallery entry={entry} />
          {entry.body && (
            <details className="group mt-4 border-t pt-3">
              <summary className="flex cursor-pointer list-none items-center gap-2 py-2 text-sm text-primary [&::-webkit-details-marker]:hidden">
                <CaretDownIcon className="group-open:rotate-180" />
                The full details
              </summary>
              <div className="max-w-prose">
                <Details body={entry.body} />
              </div>
            </details>
          )}
          <Button variant="link" size="sm" asChild className="mt-3 px-0 text-muted-foreground">
            <a href={`#${releaseTag}-${entry.slug}`}>
              Link to this change <ArrowRightIcon />
            </a>
          </Button>
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
        </div>
      )}
    </details>
  )
}

/** The site's shared shadcn Card primitives, styled with Signal's rules instead of nested frames. */
export function ReleaseCard({ release, latest = false }: { release: Release; latest?: boolean }) {
  const entries = KINDS.flatMap((k) => release.entries.filter((e) => e.kind === k))
  const move = (index: number) => {
    const target = document.getElementById(`${release.tag}-${entries[index].slug}`)
    if (!(target instanceof HTMLDetailsElement)) return
    target.open = true
    target.querySelector("summary")?.focus({ preventScroll: true })
    target.scrollIntoView({ behavior: "instant", block: "start" })
  }
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
          <div
            className="mb-4 flex flex-wrap items-center gap-x-5 gap-y-2 font-mono text-xs text-muted-foreground"
            aria-label="Changes in this release"
          >
            {KINDS.map((kind) => {
              const count = entries.filter((e) => e.kind === kind).length
              return (
                count > 0 && (
                  <span key={kind}>
                    {count} {KIND_LABELS[kind].toLowerCase()}
                  </span>
                )
              )
            })}
            {entries.length > 0 && (
              <Button variant="ghost" size="sm" onClick={() => move(0)} className="ml-auto text-primary">
                Browse changes <ArrowRightIcon />
              </Button>
            )}
          </div>
          {entries.map((e, index) => (
            <EntryBlock
              key={e.slug}
              entry={e}
              releaseTag={release.tag}
              index={index}
              total={entries.length}
              move={move}
            />
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
            {latest.entries.slice(0, 3).map((e) => (
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
