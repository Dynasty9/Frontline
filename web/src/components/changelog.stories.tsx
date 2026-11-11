import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, screen, userEvent, waitFor, within } from "storybook/test"
import { KindBadge, ReleaseCard, WhatsNew } from "@/components/changelog"
import { releases } from "@/lib/changelog"
import { release } from "@/test/fixtures"
import gif from "@/test/animation.gif"
import webm from "@/test/animation.webm"

const meta = {
  title: "Site/Changelog",
  component: ReleaseCard,
  args: { release, latest: true },
} satisfies Meta<typeof ReleaseCard>

export default meta
type Story = StoryObj<typeof meta>

/** One release, its changes grouped new, improved, fixed. Click a picture to see it full size. */
export const Release: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole("heading", { name: release.name })).toBeVisible()
    await userEvent.click(canvasElement.querySelector("summary")!)
    const [first] = release.entries[0].screenshots
    await userEvent.click(canvas.getByRole("button", { name: `Enlarge: ${first.caption}` }))
    // the dialog is portalled to the end of <body>, outside the story's canvas
    const dialog = await waitFor(() => screen.getByRole("dialog"))
    // it fades in: keep looking until it has (checked at once, it can still be at opacity 0)
    await waitFor(() => expect(within(dialog).getByRole("img", { name: first.caption })).toBeVisible())
    await userEvent.keyboard("{Escape}")
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull())
  },
}

export const OlderRelease: Story = {
  args: { latest: false },
}

export const WithVideo: Story = {
  args: {
    release: {
      ...release,
      entries: [
        {
          ...release.entries[0],
          videos: [{ url: "/media/fires.mp4", poster: "/media/fires.jpg", caption: "Fire spreads across the grass." }],
        },
      ],
    },
  },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await userEvent.click(canvasElement.querySelector("summary")!)
    const video = canvas.getByLabelText("Fire spreads across the grass.") as HTMLVideoElement
    await expect(video).toBeVisible()
    await expect(video).toHaveAttribute("controls")
    await expect(video).toHaveAttribute("preload", "none")
    await expect(video).toHaveAttribute("poster", "/media/fires.jpg")
    await expect(video).not.toHaveAttribute("autoplay")
    await expect(video.muted).toBe(true)
    await expect(video.loop).toBe(true)
    video.scrollIntoView()
    await waitFor(() => expect(video.currentTime).toBeGreaterThan(0), { timeout: 5000 })
    // Move it fully off screen so leaving the viewport stops playback.
    video.style.transform = "translateY(200vh)"
    await waitFor(() => expect(video.paused).toBe(true))
    video.style.transform = ""
    video.scrollIntoView()
    await waitFor(() => expect(video.paused).toBe(false))
    video.pause()
    await expect(video.paused).toBe(true)
  },
}

export const WithWebM: Story = {
  ...WithVideo,
  args: {
    release: {
      ...release,
      entries: [
        {
          ...release.entries[0],
          videos: [{ url: webm, poster: "/media/fires.jpg", caption: "Fire spreads across the grass." }],
        },
      ],
    },
  },
}

export const WithGif: Story = {
  args: {
    release: {
      ...release,
      entries: [
        { ...release.entries[0], videos: [{ url: gif, poster: "/media/fires.jpg", caption: "Animated GIF example." }] },
      ],
    },
  },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await userEvent.click(canvasElement.querySelector("summary")!)
    const img = canvas.getByRole("img", { name: "Animated GIF example." }) as HTMLImageElement
    img.scrollIntoView()
    await waitFor(() => expect(img).toHaveAttribute("src", gif))
    await waitFor(() => expect(img.naturalWidth).toBe(120), { timeout: 5000 })
    await userEvent.click(canvas.getByRole("button", { name: "Pause animation: Animated GIF example." }))
    await expect(img).toHaveAttribute("src", "/media/fires.jpg")
    await userEvent.click(canvas.getByRole("button", { name: "Play animation: Animated GIF example." }))
    await expect(img).toHaveAttribute("src", gif)
    // Visibility is tracked on the figure, so move the whole figure out of view.
    img.closest("figure")!.style.transform = "translateY(200vh)"
    await waitFor(() => expect(img).toHaveAttribute("src", "/media/fires.jpg"))
    img.closest("figure")!.style.transform = ""
  },
}

/** The newest release in the site's own changelog (src/changelog.json). */
export const LatestRelease: Story = {
  args: { release: releases[0] },
}

/** The front page's look at the latest release. */
export const WhatsNewSection: Story = {
  render: () => <WhatsNew />,
  parameters: { layout: "fullscreen" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole("heading", { level: 2 })).toHaveTextContent(releases[0].name)
    await expect(canvas.getByRole("link", { name: /The full changelog/ })).toHaveAttribute("href", "/changelog/")
  },
}

export const KindBadges: Story = {
  render: () => (
    <div className="flex gap-2">
      <KindBadge kind="new" />
      <KindBadge kind="improved" />
      <KindBadge kind="fixed" />
    </div>
  ),
}

/** The overview stays concise; detailed notes and source images remain available. */
export const ProgressiveDetails: Story = {
  play: async ({ canvasElement }) => {
    const entry = release.entries[0]
    const disclosure = canvasElement.querySelector("summary")!
    await expect(disclosure).toHaveTextContent(entry.title)
    const details = disclosure.closest("details")!
    await expect(details).not.toHaveAttribute("open")
    await expect(details.querySelector("video")).toBeNull()
    await userEvent.click(disclosure)
    await expect(details).toHaveAttribute("open")
    if (entry.screenshots[1]) {
      await userEvent.click(within(details).getByRole("button", { name: `Image 2: ${entry.screenshots[1].caption}` }))
      await expect(
        within(details).getByRole("button", { name: `Enlarge: ${entry.screenshots[1].caption}` })
      ).toBeVisible()
    }
    await userEvent.click(disclosure)
    await expect(details).not.toHaveAttribute("open")
  },
}

export const Phone: Story = {
  globals: { viewport: { value: "mobile1", isRotated: false } },
  play: async ({ canvasElement }) => {
    await expect(canvasElement.scrollWidth).toBeLessThanOrEqual(document.documentElement.clientWidth)
  },
}

/** Layout review is separate from feature evidence and starts collapsed. */
export const LayoutComparison: Story = {
  args: {
    release: {
      ...release,
      entries: [
        {
          ...release.entries[0],
          layoutComparison: {
            before: "/shots/river_bridge.jpg",
            after: "/shots/battle.jpg",
            caption: "Changelog layout comparison, not gameplay. Matched viewport size.",
          },
        },
      ],
    },
  },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await userEvent.click(canvasElement.querySelector("summary")!)
    const summary = [...canvasElement.querySelectorAll("summary")].find((element) =>
      element.textContent?.startsWith("Compare changelog layouts")
    )!
    const details = summary.closest("details")!
    await expect(details).not.toHaveAttribute("open")
    await userEvent.click(summary)
    await expect(details).toHaveAttribute("open")
    await expect(canvas.getByText("Changelog layout comparison, not gameplay. Matched viewport size.")).toBeVisible()
    const after = within(details).getByRole("button", {
      name: `Enlarge: After: new changelog layout — ${release.entries[0].title}`,
    })
    await expect(after).toBeVisible()
    await userEvent.click(after)
    await waitFor(() => expect(screen.getByRole("dialog")).toBeVisible())
    await userEvent.keyboard("{Escape}")
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull())
    await userEvent.click(summary)
    await expect(details).not.toHaveAttribute("open")
  },
}

export const LayoutComparisonPhone: Story = {
  ...LayoutComparison,
  globals: { viewport: { value: "mobile1", isRotated: false } },
}

/** Walk the release without accumulating open entries, then return to the overview. */
export const BrowseChanges: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const rows = canvasElement.querySelectorAll<HTMLDetailsElement>("details[name]")
    await userEvent.click(canvas.getByRole("button", { name: "Browse changes" }))
    await expect(canvas.getByRole("button", { name: "Previous change" })).toBeDisabled()
    await expect(canvas.getByText("Change 1 of 3")).toBeVisible()
    await expect(canvas.getByText("The full details").closest("details")!).not.toHaveAttribute("open")
    await userEvent.click(canvas.getByText("The full details"))
    await expect(canvas.getByText("Under fire", { exact: true })).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Next change" }))
    await waitFor(() => expect(rows[0]).not.toHaveAttribute("open"))
    await expect(rows[1]).toHaveAttribute("open")
    await expect(rows[1].querySelector("summary")!).toHaveFocus()
    await expect(canvas.getByText("Change 2 of 3")).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Next change" }))
    await expect(canvas.getByRole("button", { name: "Next change" })).toBeDisabled()
    await userEvent.click(canvas.getByRole("button", { name: "Previous change" }))
    await expect(canvas.getByText("Change 2 of 3")).toBeVisible()
    await userEvent.click(rows[1].querySelector("summary")!)
    await waitFor(() => expect(canvas.queryByRole("navigation", { name: "Browse changes" })).toBeNull())
  },
}

export const Gallery: Story = {
  args: {
    release: {
      ...release,
      entries: [
        { ...release.entries[0], videos: [{ url: webm, poster: "/media/fires.jpg", caption: "Fire footage" }] },
      ],
    },
  },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await userEvent.click(canvasElement.querySelector("summary")!)
    await expect(canvas.getByLabelText("Fire footage")).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: `Image 2: ${release.entries[0].screenshots[0].caption}` }))
    await expect(canvas.queryByLabelText("Fire footage")).toBeNull()
    await expect(
      canvas.getByRole("button", { name: `Enlarge: ${release.entries[0].screenshots[0].caption}` })
    ).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Video 1: Fire footage" }))
    await expect(canvas.getByLabelText("Fire footage")).toBeVisible()
    await expect(canvasElement.querySelectorAll("video")).toHaveLength(1)
  },
}

export const BrowseChangesPhone: Story = {
  ...BrowseChanges,
  globals: { viewport: { value: "mobile1", isRotated: false } },
}
