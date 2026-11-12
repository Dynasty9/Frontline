import { Navigate, useParams, useSearchParams } from "react-router"
import { SectionLabel } from "@/components/battles"
import { Catalogue } from "@/components/catalogue"
import { ManualNav } from "@/components/manual-nav"
import { usePageTitle } from "@/hooks/use-page-title"
import { section } from "@/lib/manual"
import NotFound from "@/pages/not-found"

/** A chapter of the Field Manual: infantry, vehicles, buildings, fire support or research, each entry with its model and figures. */
export default function ManualSectionPage() {
  const { section: key, entry: id } = useParams()
  const [search] = useSearchParams()
  const s = section(key)
  const entry = id ? s?.entries.find((e) => e.id === id) : undefined
  usePageTitle(!s || (id && !entry) ? "Not found" : entry ? `${entry.name} · ${s.title}` : `${s.title} · Field Manual`)
  // an entry's old address, /manual/vehicles?entry=tank, is its own now
  const old = search.get("entry")
  if (s && !id && old && s.entries.some((e) => e.id === old))
    return <Navigate to={`/manual/${s.key}/${encodeURIComponent(old)}`} replace />
  if (!s || (id && !entry)) return <NotFound />
  return (
    <div>
      <ManualNav />
      <section className="mx-auto max-w-6xl px-4 pt-12 pb-24 sm:px-6">
        <SectionLabel>Field Manual / {s.title}</SectionLabel>
        <div className="mt-4 flex flex-wrap items-end justify-between gap-6">
          <h1 className="max-w-2xl font-display text-5xl leading-[0.95] font-extrabold uppercase sm:text-7xl">
            {s.headline[0]} <br />
            <span className="text-primary">{s.headline[1]}</span>
          </h1>
          <p className="max-w-xs text-sm leading-relaxed text-muted-foreground">{s.summary}</p>
        </div>
        <Catalogue section={s} entry={entry?.id} />
      </section>
    </div>
  )
}
