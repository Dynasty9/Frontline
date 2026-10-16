import { ArrowSquareOutIcon, DownloadSimpleIcon, LinuxLogoIcon, WindowsLogoIcon } from "@phosphor-icons/react"
import { SectionLabel } from "@/components/battles"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { GITHUB_URL } from "@/lib/config"
import { type Build, formatSize, latest, type Platform, PLATFORM_NAMES } from "@/lib/releases"

const ICONS = { windows: WindowsLogoIcon, linux: LinuxLogoIcon }
const PLATFORMS: Platform[] = ["windows", "linux"]

export function Downloads({ platform }: { platform: Platform }) {
  return (
    <section id="download" className="scroll-mt-16 border-y bg-card/40">
      <div className="mx-auto max-w-6xl px-4 py-24 sm:px-6">
        <SectionLabel>Download</SectionLabel>
        <h2 className="mt-3 font-display text-5xl leading-[0.95] font-extrabold uppercase sm:text-6xl">
          Get the game. <span className="text-primary">It's free.</span>
        </h2>
        <p className="mt-4 max-w-2xl text-sm text-muted-foreground">
          Free and open source. Unzip it anywhere and run Frontline; there's nothing to install. The first time it starts,
          it also sets up the Join links on this page, and from then on it updates itself whenever a new version comes out.
        </p>

        <div className="mt-8 grid gap-4 md:grid-cols-2">
          {PLATFORMS.map((p) => (
            <PlatformCard key={p} platform={p} build={latest} primary={p === platform} />
          ))}
        </div>

        <div className="mt-6 flex flex-wrap gap-x-6 gap-y-2 text-sm text-muted-foreground">
          <ExtLink href={latest.url}>What's new in {latest.tag}</ExtLink>
          <ExtLink href={`${GITHUB_URL}/releases`}>All releases</ExtLink>
          <ExtLink href={`${GITHUB_URL}/actions/workflows/release.yml`}>Build artifacts (needs a GitHub account)</ExtLink>
          <ExtLink href={`${GITHUB_URL}#quick-start`}>Run from source</ExtLink>
        </div>
      </div>
    </section>
  )
}

function PlatformCard({ platform, build, primary }: { platform: Platform; build: Build; primary: boolean }) {
  const Icon = ICONS[platform]
  const asset = build.assets[platform]
  return (
    <Card className="gap-4 text-sm">
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-lg font-semibold">
          <Icon weight="fill" className="size-5 text-primary" />
          {PLATFORM_NAMES[platform]}
          {primary && (
            <Badge variant="outline" className="ml-1 text-muted-foreground">
              Your system
            </Badge>
          )}
        </CardTitle>
        <CardDescription>
          {platform === "windows"
            ? "Windows 10 or 11, 64-bit. The game isn't code-signed yet, so Windows may warn you the first time: choose More info, then Run anyway."
            : "64-bit x86. If your unzip tool loses the permissions, make Frontline.x86_64 executable."}
        </CardDescription>
      </CardHeader>
      <CardContent>
        <p className="text-muted-foreground">
          <span className="text-foreground">{build.name}</span>
          {" · "}
          {new Date(build.published).toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" })}
          {" · "}
          {formatSize(asset.size)}
        </p>
      </CardContent>
      <CardFooter className="mt-auto bg-transparent">
        <Button asChild variant={primary ? "default" : "outline"} className="font-semibold">
          <a href={asset.url}>
            <DownloadSimpleIcon weight="bold" />
            Download for {PLATFORM_NAMES[platform]}
          </a>
        </Button>
      </CardFooter>
    </Card>
  )
}

function ExtLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <a href={href} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 hover:text-foreground">
      {children}
      <ArrowSquareOutIcon className="size-3.5" />
    </a>
  )
}
