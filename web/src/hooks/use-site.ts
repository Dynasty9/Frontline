import { useOutletContext } from "react-router"
import type { Health } from "@/lib/matchmaker"

/** What every page can use: the matchmaker's /health, polled once for the whole site (src/pages/layout.tsx). */
export type Site = { health: Health | undefined }

export const useSite = () => useOutletContext<Site>()
