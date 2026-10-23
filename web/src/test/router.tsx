// The site as a story: every page through its real router, held in memory so
// the story's own address doesn't matter.

import { useState } from "react"
import { createMemoryRouter } from "react-router"
import { RouterProvider } from "react-router/dom"
import { routes } from "@/router"

/** The whole site, opened at `path` ("/play", "/battles?join=ID"). */
export function SiteAt({ path }: { path: string }) {
  const [router] = useState(() => createMemoryRouter(routes, { initialEntries: [path] }))
  return <RouterProvider router={router} />
}
