import { InsigniaSection } from "@/components/insignia"
import { usePageTitle } from "@/hooks/use-page-title"
import { useSite } from "@/hooks/use-site"

/** /ranks: how ranks are earned, and every insignia there is to unlock and wear. */
export default function RanksPage() {
  usePageTitle("Ranks")
  const { health } = useSite()
  return (
    <div className="topo">
      <InsigniaSection accounts={health?.accounts} />
    </div>
  )
}
