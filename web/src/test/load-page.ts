import { matchRoutes } from "react-router"
import { routes } from "@/router"

/**
 * A Storybook loader for the page stories (src/test/router.tsx): the code for
 * the page at `path` fetched before the story renders. Pages are fetched on
 * demand (src/router.tsx), and the dev server builds each on its first visit,
 * which can take longer than a play function waits for something to appear.
 */
export async function loadPage({ args }: { args: { path?: string } }) {
  const pathname = new URL(args.path ?? "/", "http://site.test").pathname
  for (const m of matchRoutes(routes, pathname) ?? []) {
    if (typeof m.route.lazy === "function") await m.route.lazy()
  }
  return {}
}
