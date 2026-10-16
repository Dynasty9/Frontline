import { ArrowSquareOutIcon, DownloadSimpleIcon, LinuxLogoIcon, WindowsLogoIcon } from "@phosphor-icons/react"
import { SectionLabel } from "@/components/battles"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import { GITHUB_URL } from "@/lib/config"
import { type Build, formatSize, type Platform, PLATFORM_NAMES } from "@/lib/releases"

type Props = {
  stable: Build | null
  nightly: Build | null
  loading: boolean
  error: Error | null
  platform: Platform
}

const ICONS = { windows: WindowsLogoIcon, linux: LinuxLogoIcon }
const PLATFORMS: Platform[] = ["windows", "linux"]

export function Downloads({ stable, nightly, loading, error, platform }: Props) {
  // the newest tagged release if there is one, else the latest build of main
  const build = stable ?? nightly
  return (
    <section id="download" className="scroll-mt-16 border-y bg-card/40">
      <div className="mx-auto max-w-6xl px-4 py-20 sm:px-6">
        <SectionLabel>Download</SectionLabel>
        <h2 className="mt-2 text-3xl font-semibold">Get the game</h2>
        <p className="mt-2 max-w-2xl text-sm text-muted-foreground">
          Free and open source. Unzip it anywhere and run Frontline; there's nothing to install. The first time it starts,
          it also sets up the Join links on this page.
        </p>

        <div className="mt-8 grid gap-4 md:grid-cols-2">
          {PLATFORMS.map((p) => (
            <PlatformCard key={p} platform={p} build={build} loading={loading} primary={p === platform} />
          ))}
        </div>

        {!loading && !build && (
          <p className="mt-4 text-sm text-muted-foreground">
            {error ? "Couldn't reach GitHub to find the latest build. " : "No builds have been published yet. "}
            You can always{" "}
            <a href={`${GITHUB_URL}/releases`} className="text-foreground underline underline-offset-4">
              check the releases page
            </a>{" "}
            or run it from source: open <code className="font-mono text-xs">project.godot</code> in Godot 4.7 and press F5.
          </p>
        )}

        <div className="mt-6 flex flex-wrap gap-x-6 gap-y-2 text-sm text-muted-foreground">
          <ExtLink href={`${GITHUB_URL}/releases`}>All releases</ExtLink>
          {stable && nightly && <ExtLink href={nightly.url}>Latest build of main (nightly)</ExtLink>}
          <ExtLink href={`${GITHUB_URL}/actions/workflows/release.yml`}>Build artifacts (needs a GitHub account)</ExtLink>
          <ExtLink href={`${GITHUB_URL}#quick-start`}>Run from source</ExtLink>
        </div>
      </div>
    </section>
  )
}

function PlatformCard({ platform, build, loading, primary }: { platform: Platform; build: Build | null; loading: boolean; primary: boolean }) {
  const Icon = ICONS[platform]
  const asset = build?.assets[platform]
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
        {loading ? (
          <Skeleton className="h-4 w-48" />
        ) : asset && build ? (
          <p className="text-muted-foreground">
            <span className="text-foreground">{build.prerelease ? "Latest build of main" : build.name}</span>
            {" · "}
            {new Date(build.published).toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" })}
            {" · "}
            {formatSize(asset.size)}
          </p>
        ) : (
          <p className="text-muted-foreground">Not published yet.</p>
        )}
      </CardContent>
      <CardFooter className="mt-auto bg-transparent">
        {asset ? (
          <Button asChild variant={primary ? "default" : "outline"} className="font-semibold">
            <a href={asset.url}>
              <DownloadSimpleIcon weight="bold" />
              Download for {PLATFORM_NAMES[platform]}
            </a>
          </Button>
        ) : (
          <Button disabled variant="outline" className="font-semibold">
            <DownloadSimpleIcon weight="bold" />
            Download for {PLATFORM_NAMES[platform]}
          </Button>
        )}
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
