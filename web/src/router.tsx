import type { ComponentType } from "react"
import { Navigate, type RouteObject } from "react-router"
import Home from "@/pages/home"
import { Layout } from "@/pages/layout"
import NotFound from "@/pages/not-found"
import PageError from "@/pages/page-error"

// The site's pages. The front page comes with the first load; the others are
// fetched when they're first visited, so the front page doesn't wait on them.
// Railway serves index.html for any address that isn't a file, and the
// router takes it from there.

const page = (load: () => Promise<{ default: ComponentType }>) => async () => ({ Component: (await load()).default })

export const routes: RouteObject[] = [
  {
    path: "/",
    Component: Layout,
    // the first load of a page that's fetched on demand: just the page's colour while it comes
    HydrateFallback: () => null,
    children: [
      {
        // inside the layout, so a page that breaks keeps the header and footer
        ErrorBoundary: PageError,
        children: [
          { index: true, Component: Home },
          { path: "play", lazy: page(() => import("@/pages/play")) },
          { path: "battles", lazy: page(() => import("@/pages/battles")) },
          { path: "ranks", lazy: page(() => import("@/pages/ranks")) },
          { path: "leaderboards", lazy: page(() => import("@/pages/leaderboards")) },
          { path: "player/:callsign", lazy: page(() => import("@/pages/player")) },
          { path: "player/:callsign/battle/:id", lazy: page(() => import("@/pages/battle")) },
          { path: "profile", lazy: page(() => import("@/pages/profile")) },
          // the profile's old address
          { path: "account", element: <Navigate to="/profile" replace /> },
          { path: "changelog", lazy: page(() => import("@/pages/changelog")) },
          { path: "*", Component: NotFound },
        ],
      },
    ],
  },
]
