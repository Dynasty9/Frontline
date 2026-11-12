import { useQuery } from "@tanstack/react-query"

/**
 * Whether the game's browser build is on this site with the Field Manual's
 * model stage in it (/game/viewer.json says `manual: 3`): null while that's
 * being checked, with what it downloads the first time. Without it, the manual
 * still shows every entry's details.
 */
export function useViewer() {
  const viewer = useQuery({
    queryKey: ["viewer-build"],
    queryFn: async ({ signal }) => {
      const response = await fetch("/game/viewer.json", { signal })
      return response.ok ? (response.json() as Promise<{ manual?: number; bytes?: number }>) : null
    },
    retry: false,
    staleTime: Infinity,
  })
  return {
    available: viewer.isPending ? null : viewer.data?.manual === 3,
    /** what a first visit downloads, compressed (newer manifests say) */
    bytes: typeof viewer.data?.bytes === "number" ? viewer.data.bytes : undefined,
  }
}
