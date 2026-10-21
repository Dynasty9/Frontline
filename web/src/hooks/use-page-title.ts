import { useEffect } from "react"

/** The tab's title for this page: "Live battles · Frontline", or just "Frontline" for the front page. */
export function usePageTitle(title?: string) {
  useEffect(() => {
    document.title = title ? `${title} · Frontline` : "Frontline"
  }, [title])
}
