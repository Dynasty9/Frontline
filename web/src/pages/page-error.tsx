import { ArrowClockwiseIcon } from "@phosphor-icons/react"
import { isRouteErrorResponse, useRouteError } from "react-router"
import { SectionLabel } from "@/components/battles"
import { Button } from "@/components/ui/button"
import { usePageTitle } from "@/hooks/use-page-title"
import NotFound from "@/pages/not-found"

/**
 * A page that broke, or wouldn't load. The likeliest cause is a new version
 * of the site going up since this tab opened it: the page it asks for has
 * been replaced, and a reload fetches the new one.
 */
export default function PageError() {
  const error = useRouteError()
  usePageTitle("Something went wrong")
  if (isRouteErrorResponse(error) && error.status === 404) return <NotFound />
  return (
    <div className="topo">
      <div className="mx-auto flex min-h-[60svh] max-w-6xl flex-col items-start justify-center px-4 py-24 sm:px-6">
        <SectionLabel>Signal lost</SectionLabel>
        <h1 className="mt-3 text-4xl font-semibold">This page didn't load</h1>
        <p className="mt-3 max-w-xl text-sm text-muted-foreground">
          The site may have been updated since you opened it. Reloading usually sorts it out.
        </p>
        <Button className="mt-8 font-semibold" onClick={() => window.location.reload()}>
          <ArrowClockwiseIcon weight="bold" />
          Reload
        </Button>
      </div>
    </div>
  )
}
