// Every release's changelog, baked in at build time. The release workflow
// regenerates src/changelog.json from changelog/ (.github/scripts/changelog.py)
// each time it publishes a version, in the release's pull request, and Railway
// redeploys the site when that merges.
import data from "@/changelog.json"

export type Kind = "new" | "improved" | "fixed"

export type Entry = {
  slug: string
  title: string
  kind: Kind
  summary: string
  body: string
  layoutComparison?: { before: string; after: string; caption: string } | null
  screenshots: { url: string; caption: string }[]
  videos?: { url: string; poster: string; caption: string }[]
}

export type Release = {
  version: string
  tag: string
  name: string
  date: string
  summary: string
  url: string
  pull_requests: number[]
  entries: Entry[]
}

export const releases = data.releases as Release[]

export const KIND_LABELS: Record<Kind, string> = { new: "New", improved: "Improved", fixed: "Fixed" }
export const KINDS: Kind[] = ["new", "improved", "fixed"]

export function formatDate(iso: string) {
  const d = new Date(`${iso}T12:00:00Z`)
  return Number.isNaN(d.getTime())
    ? iso
    : d.toLocaleDateString(undefined, { day: "numeric", month: "long", year: "numeric" })
}

/** A release's screenshots, in entry order. */
export function screenshotsOf(r: Release) {
  return r.entries.flatMap((e) => e.screenshots.map((s) => ({ ...s, entry: e.title })))
}
