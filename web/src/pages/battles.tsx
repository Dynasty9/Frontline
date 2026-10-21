import { useState } from "react"
import { useSearchParams } from "react-router"
import { Battles } from "@/components/battles"
import { usePageTitle } from "@/hooks/use-page-title"
import { usePoll } from "@/hooks/use-poll"
import { fetchLobbies } from "@/lib/matchmaker"

/** /battles: every battle being hosted, and the invite a friend's link points at (?join=ID). */
export default function BattlesPage() {
  usePageTitle("Live battles")
  const lobbies = usePoll(fetchLobbies, 5_000)
  const [launched, setLaunched] = useState(false)
  const [search, setSearch] = useSearchParams()
  const invite = search.get("join")

  return (
    <div className="topo min-h-[70svh]">
      <Battles
        page
        lobbies={lobbies.data}
        error={lobbies.error}
        updatedAt={lobbies.updatedAt}
        launched={launched}
        onLaunch={() => setLaunched(true)}
        onDismissLaunch={() => setLaunched(false)}
        invite={invite}
        onDismissInvite={() => setSearch({}, { replace: true })}
      />
    </div>
  )
}
