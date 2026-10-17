import {
  BrowserIcon,
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
import { SectionLabel } from "@/components/battles"
import { Downloads } from "@/components/downloads"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { type LaunchState, useLaunch } from "@/hooks/use-launch"
import { usePageTitle } from "@/hooks/use-page-title"
import { FIND_MATCH_LINK, GITHUB_URL, OPEN_LINK } from "@/lib/config"
import { type Device, formatSize, guessDevice, latest, type Platform, PLATFORM_NAMES } from "@/lib/releases"

/** /play: the desktop game (launch it, or download it), and the browser version beside it. */
export default function PlayPage() {
  usePageTitle("Play")
  const [device] = useState(guessDevice)

  return (
    <>
      <section className="topo border-b">
        <div className="mx-auto max-w-6xl px-4 pt-14 pb-20 sm:px-6">
          <SectionLabel>Play</SectionLabel>
          <h1 className="mt-2 font-display text-5xl leading-[0.95] font-extrabold uppercase sm:text-6xl">
            Report for duty. <span className="text-primary">It's free.</span>
          </h1>
          <p className="mt-4 max-w-2xl text-sm text-muted-foreground">
            The desktop game is the whole of Frontline: battles online, co-op with friends and every mission. You don't
            need an account to play, but sign in and every battle you fight counts towards your rank.
          </p>
          <div className="mt-8 grid items-stretch gap-4 lg:grid-cols-[1.5fr_1fr]">
            <DesktopCard device={device} />
            <BrowserCard device={device} />
          </div>
        </div>
      </section>
      <Downloads platform={device === "linux" ? "linux" : "windows"} />
    </>
  )
}

const DESKTOP = [
  "Battles online: Find Match, or join one from the list",
  "Co-op against the AI, with friends",
  "Every mission, alone or together",
  "Keeps itself up to date",
]

function DesktopCard({ device }: { device: Device }) {
  const launch = useLaunch()
  const platform: Platform | null = device === "windows" || device === "linux" ? device : null

  return (
    <Card className="gap-0 py-0 text-sm">
      <div className="p-5 sm:p-6">
        <div className="flex flex-wrap items-center gap-2">
          <DesktopIcon weight="fill" className="size-5 text-primary" />
          <h2 className="text-lg font-semibold">Desktop game</h2>
          <Badge variant="outline" className="text-muted-foreground">
            Windows · Linux
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
              <Button size="lg" asChild className="shine h-11 px-5 text-sm font-bold tracking-wider uppercase">
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
              <Button size="lg" variant="outline" asChild className="h-11 px-5 text-sm">
                <a href={latest.assets[platform].url}>
                  <DownloadSimpleIcon weight="bold" />
                  Download for {PLATFORM_NAMES[platform]}
                  <span className="text-muted-foreground">· {formatSize(latest.assets[platform].size)}</span>
                </a>
              </Button>
            </div>
            <LaunchNote state={launch.state} installed={launch.installed} />
          </>
        ) : device === "mac" ? (
          <Note icon={InfoIcon}>
            There's no Mac version yet. You can{" "}
            <a href={`${GITHUB_URL}#quick-start`} className="text-foreground underline underline-offset-4">
              run it from source
            </a>{" "}
            with Godot, or play on a Windows or Linux computer.
          </Note>
        ) : (
          <Note icon={InfoIcon}>
            Frontline is played with a keyboard and mouse, on Windows or Linux. Come back on a computer to play: the
            downloads are below.
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
            Nothing opened? Frontline isn't on this computer yet, or it hasn't been started here. Download it, unzip it
            and start it once: after that, these buttons open it.
          </span>
        </span>
      ) : installed ? (
        <span className="text-muted-foreground">Launch opens Frontline on this computer.</span>
      ) : (
        <span className="text-muted-foreground">
          First time? Download it, unzip it anywhere and start Frontline once. From then on, Launch and the Join buttons
          on this site open it.
        </span>
      )}
    </output>
  )
}

function BrowserCard({ device }: { device: Device }) {
  return (
    <Card className="gap-0 py-0 text-sm">
      <div className="p-5 sm:p-6">
        <div className="flex flex-wrap items-center gap-2">
          <BrowserIcon weight="fill" className="size-5 text-primary" />
          <h2 className="text-lg font-semibold">In your browser</h2>
          <Badge variant="outline" className="border-primary/40 text-primary">
            Coming soon
          </Badge>
        </div>
        <p className="mt-4 leading-relaxed text-muted-foreground">
          Take on the AI and play the missions right here, with nothing to install. Battles online stay with the desktop
          game.
        </p>
      </div>
      <div className="mt-auto space-y-3 border-t p-5 sm:p-6">
        <Button size="lg" variant="outline" disabled className="h-11 w-full px-5 text-sm">
          Arrives with the next release
        </Button>
        {device === "mobile" && (
          <p className="text-xs text-muted-foreground">It needs a computer too: a keyboard, a mouse and WebGL 2.</p>
        )}
      </div>
    </Card>
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
