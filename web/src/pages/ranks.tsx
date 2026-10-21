import { Link } from "react-router"
import { SectionLabel } from "@/components/battles"
import { CommandersNav } from "@/components/commanders-nav"
import { InsigniaImg } from "@/components/insignia-img"
import { Button } from "@/components/ui/button"
import { usePageTitle } from "@/hooks/use-page-title"
import { useSite } from "@/hooks/use-site"
import { openSignIn } from "@/hooks/use-sign-in-dialog"
import { useAccount } from "@/lib/account"
import { INSIGNIA, RANKS } from "@/lib/insignia"

/** A public progression reference. Picking and wearing insignia belongs to /profile. */
export default function RanksPage() {
  usePageTitle("Rank guide")
  const { user } = useAccount()
  const { health } = useSite()
  const available = health?.accounts !== "off"
  return (
    <div className="topo">
      <CommandersNav />
      <div className="mx-auto max-w-6xl px-4 pt-14 pb-24 sm:px-6">
        <SectionLabel>Commanders / Rank guide</SectionLabel>
        <h1 className="mt-3 font-display text-5xl leading-none font-extrabold uppercase sm:text-6xl">
          Every battle.
          <br />
          <span className="text-primary">A step forward.</span>
        </h1>
        <div className="mt-8 grid gap-10 lg:grid-cols-[1fr_1.4fr]">
          <div>
            <h2 className="font-display text-2xl font-bold uppercase">How progression works</h2>
            <p className="mt-4 leading-relaxed text-muted-foreground">
              Play online battles signed in to earn experience. You earn one XP for every six seconds of battle, with a
              50% bonus for a win. Your rank unlocks insignia to wear beside your callsign.
            </p>
            <p className="mt-4 leading-relaxed text-muted-foreground">
              Ranks record experience, not a skill rating. You can play every mission and join battles without an
              account.
            </p>
            <div className="mt-8 border-y py-5">
              <h2 className="font-display text-xl font-bold uppercase">Make it yours</h2>
              <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                Choose your callsign, picture and unlocked insignia in your profile. This guide shows what you can work
                towards.
              </p>
              {available ? (
                user ? (
                  <Button asChild className="mt-5 min-h-11">
                    <Link to="/profile#your-insignia">Choose your insignia</Link>
                  </Button>
                ) : (
                  <Button onClick={openSignIn} className="mt-5">
                    Sign in to track progress
                  </Button>
                )
              ) : (
                <p className="mt-5 text-sm text-muted-foreground">
                  Accounts are currently unavailable. You can still play.
                </p>
              )}
            </div>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <caption className="sr-only">Ranks, experience required and insignia unlocked</caption>
              <thead>
                <tr className="border-b text-xs text-muted-foreground">
                  <th scope="col" className="py-3 pr-3">
                    Rank
                  </th>
                  <th scope="col" className="px-3 py-3 text-right">
                    Total XP
                  </th>
                  <th scope="col" className="py-3 pl-3">
                    Unlock
                  </th>
                </tr>
              </thead>
              <tbody>
                {RANKS.map((r) => {
                  const unlocks = INSIGNIA.filter((i) => i.unlock === r.rank)
                  return (
                    <tr key={r.rank} className="border-b">
                      <th scope="row" className="py-3 pr-3 font-medium">
                        <span className="mr-3 font-mono text-xs text-muted-foreground">
                          {String(r.rank).padStart(2, "0")}
                        </span>
                        {r.name}
                        {available && user?.rank === r.rank && <span className="ml-2 text-xs text-primary">You</span>}
                      </th>
                      <td className="px-3 py-3 text-right font-mono text-xs">{r.xp.toLocaleString()}</td>
                      <td className="py-3 pl-3">
                        {unlocks.length ? (
                          <div className="flex items-center gap-2">
                            <InsigniaImg id={unlocks[0].id} className="size-9 shrink-0" />
                            <span className="text-xs text-muted-foreground">
                              {unlocks.length > 1 ? `${unlocks.length} insignia` : unlocks[0].name}
                            </span>
                          </div>
                        ) : (
                          <span className="text-muted-foreground">—</span>
                        )}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  )
}
