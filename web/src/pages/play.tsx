import {
  CheckCircleIcon,
  CheckIcon,
  CrosshairIcon,
  DesktopIcon,
  DownloadSimpleIcon,
  InfoIcon,
  PlayIcon,
  WarningIcon,
} from "@phosphor-icons/react"
import { useState } from "react"
import { Link } from "react-router"
import { useAccount } from "@/lib/account"
import { useSite } from "@/hooks/use-site"
import { openSignIn } from "@/hooks/use-sign-in-dialog"
import { SectionLabel } from "@/components/battles"
import { Downloads } from "@/components/downloads"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { type LaunchState, useLaunch } from "@/hooks/use-launch"
import { usePageTitle } from "@/hooks/use-page-title"
import { FIND_MATCH_LINK, GITHUB_URL, OPEN_LINK } from "@/lib/config"
import {
  assetFor,
  type Build,
  type Device,
  formatSize,
  guessDevice,
  guessPlatform,
  latest,
  type Platform,
  PLATFORM_NAMES,
  platformList,
  platformsOf,
} from "@/lib/releases"

/** /play: download first for a new device; launch first after a successful handoff. */
export default function PlayPage() {
  usePageTitle("Play")
  const { user } = useAccount()
  const { health } = useSite()
  const signedIn = !!user && health?.accounts !== "off"
  const [device] = useState(guessDevice)
  const [platform] = useState(() => guessPlatform())

  return (
    <>
      <section className="topo border-b">
        <div className="mx-auto max-w-6xl px-4 pt-14 pb-20 sm:px-6">
          <SectionLabel>Play</SectionLabel>
          <h1 className="mt-2 font-display text-5xl leading-[0.95] font-extrabold uppercase sm:text-6xl">
            {signedIn ? (
              <>
                Back for <span className="text-primary">another battle.</span>
              </>
            ) : (
              <>
                Report for duty. <span className="text-primary">It's free.</span>
              </>
            )}
          </h1>
          <p className="mt-4 max-w-2xl text-sm text-muted-foreground">
            {signedIn
              ? `Ready, ${user.callsign}? Open the game for missions and multiplayer, or browse the live battles to choose a host.`
              : "Download Frontline for the full game: solo missions, co-op with friends and battles online. No account or purchase needed."}
          </p>
          <div className="mt-8 grid items-stretch gap-4 lg:grid-cols-[1.5fr_1fr]">
            <DesktopCard device={device} />
            <aside className="border-t py-6 lg:border-t-0 lg:border-l lg:pl-8">
              <h2 className="font-display text-2xl font-bold uppercase">
                {signedIn ? "Choose your next move" : "From download to first orders"}
              </h2>
              {signedIn ? (
                <div className="mt-5 space-y-5 text-sm">
                  <p className="text-muted-foreground">
                    Missions and hosting start in the game. The website helps you find a battle and manage your
                    commander.
                  </p>
                  <Link to="/battles" className="block border-b pb-3 hover:text-primary">
                    Browse live battles →
                  </Link>
                  <Link to="/profile" className="block border-b pb-3 hover:text-primary">
                    Your profile & insignia →
                  </Link>
                </div>
              ) : (
                <ol className="mt-5 space-y-5 text-sm">
                  <li>
                    <span className="mr-3 font-mono text-primary">01</span>Download for your computer.
                  </li>
                  <li>
                    <span className="mr-3 font-mono text-primary">02</span>Install or unpack it, then start Frontline.
                  </li>
                  <li>
                    <span className="mr-3 font-mono text-primary">03</span>Pick a mission or join a battle.
                  </li>
                </ol>
              )}
              <p className="mt-8 border-t pt-4 text-xs leading-relaxed text-muted-foreground">
                Browser play is in development. The desktop version has the full game now.
              </p>
            </aside>
          </div>
        </div>
      </section>
      {!signedIn && health?.accounts !== "off" && (
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 px-4 py-8 sm:px-6">
          <div>
            <h2 className="font-display text-xl font-bold uppercase">
              An account is optional. Your progress is personal.
            </h2>
            <p className="mt-2 text-sm text-muted-foreground">
              Sign in to keep your callsign, earn ranks and choose your insignia.
            </p>
          </div>
          <Button variant="outline" className="min-h-11" onClick={openSignIn}>
            Sign in to track progress
          </Button>
        </div>
      )}
      <Downloads platform={platform} />
    </>
  )
}

const DESKTOP = [
  "Battles online: Find Match, or join one from the list",
  "Co-op against the AI, with friends",
  "Every mission, alone or together",
  "Keeps itself up to date",
]

/** Launch, find a match or download, for what the visitor is on and what `build` has a download for. */
export function DesktopCard({ device, build = latest }: { device: Device; build?: Build }) {
  const launch = useLaunch()
  // a computer the release has a build for (a Mac only once there's a Mac build)
  const platform: Platform | null = device !== "mobile" && build.assets[device] ? device : null

  return (
    <Card className="gap-0 py-0 text-sm">
      <div className="p-5 sm:p-6">
        <div className="flex flex-wrap items-center gap-2">
          <DesktopIcon weight="fill" className="size-5 text-primary" />
          <h2 className="text-lg font-semibold">Desktop game</h2>
          <Badge variant="outline" className="text-muted-foreground">
            {platformsOf(build)
              .map((p) => PLATFORM_NAMES[p])
              .join(" · ")}
          </Badge>
        </div>
        <ul className="mt-4 grid gap-2 sm:grid-cols-2">
          {DESKTOP.map((d) => (
            <li key={d} className="flex items-start gap-2 text-muted-foreground">
              <CheckIcon weight="bold" className="mt-0.5 size-4 shrink-0 text-good" />
              {d}
            </li>
          ))}
        </ul>
      </div>

      <div className="mt-auto space-y-4 border-t p-5 sm:p-6">
        {platform ? (
          <>
            <div className="flex flex-wrap gap-2">
              {!launch.installed && <DownloadAction platform={platform} build={build} primary />}
              <Button
                size="lg"
                variant={launch.installed ? "default" : "outline"}
                asChild
                className="h-11 px-5 text-sm font-bold tracking-wider uppercase"
              >
                <a href={OPEN_LINK} onClick={launch.onClick}>
                  <PlayIcon weight="fill" />
                  Launch Frontline
                </a>
              </Button>
              <Button
                size="lg"
                variant="outline"
                asChild
                className="h-11 px-5 text-sm font-bold tracking-wider uppercase"
              >
                <a href={FIND_MATCH_LINK} onClick={launch.onClick}>
                  <CrosshairIcon weight="bold" />
                  Find a match
                </a>
              </Button>
              {launch.installed && <DownloadAction platform={platform} build={build} />}
            </div>
            <LaunchNote state={launch.state} installed={launch.installed} />
          </>
        ) : device === "macos" ? (
          <Note icon={InfoIcon}>
            This release has no Mac version; the next one will. Until then you can{" "}
            <a href={`${GITHUB_URL}#quick-start`} className="text-foreground underline underline-offset-4">
              run it from source
            </a>{" "}
            with Godot, or play on {platformList(build)}.
          </Note>
        ) : (
          <Note icon={InfoIcon}>
            Frontline is played with a keyboard and mouse, on {platformList(build)}. Come back on a computer to play:
            the downloads are below.
          </Note>
        )}
      </div>
    </Card>
  )
}

/** What the Launch and Find a match buttons did, and what to do if they did nothing. */
function LaunchNote({ state, installed }: { state: LaunchState; installed: boolean }) {
  // an <output>: read out as it changes, without taking the focus
  return (
    <output className="block min-h-10 text-xs leading-relaxed">
      {state === "waiting" ? (
        <span className="text-muted-foreground">Opening Frontline…</span>
      ) : state === "opened" ? (
        <span className="flex items-start gap-2 text-good">
          <CheckCircleIcon weight="fill" className="mt-px size-4 shrink-0" />
          Over to the game. If your browser asks, let it open Frontline.
        </span>
      ) : state === "missing" ? (
        <span className="flex items-start gap-2 text-warn">
          <WarningIcon weight="fill" className="mt-px size-4 shrink-0" />
          <span>
            Nothing opened? Frontline isn't on this computer yet, or it hasn't been started here. Download it, install
            or unpack it and start it once: after that, these buttons open it.
          </span>
        </span>
      ) : installed ? (
        <span className="text-muted-foreground">Launch opens Frontline on this computer.</span>
      ) : (
        <span className="text-muted-foreground">
          First time? Download it, install or unpack it anywhere and start Frontline once. From then on, Launch and the
          Join buttons on this site open it.
        </span>
      )}
    </output>
  )
}

function DownloadAction({ platform, build, primary = false }: { platform: Platform; build: Build; primary?: boolean }) {
  return (
    <Button size="lg" variant={primary ? "default" : "outline"} asChild className="h-11 px-5 text-sm">
      <a href={assetFor(platform, build).url}>
        <DownloadSimpleIcon weight="bold" />
        Download for {PLATFORM_NAMES[platform]}
        <span className={primary ? "opacity-75" : "text-muted-foreground"}>
          · {formatSize(assetFor(platform, build).size)}
        </span>
      </a>
    </Button>
  )
}

function Note({ icon: Icon, children }: { icon: typeof InfoIcon; children: React.ReactNode }) {
  return (
    <p className="flex items-start gap-2 text-sm leading-relaxed text-muted-foreground">
      <Icon weight="fill" className="mt-0.5 size-4 shrink-0 text-primary" />
      <span>{children}</span>
    </p>
  )
}
