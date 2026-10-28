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
    const video = canvas.getByLabelText("Fire spreads across the grass.") as HTMLVideoElement
    await expect(video).toBeVisible()
    await expect(video).toHaveAttribute("controls")
    await expect(video).toHaveAttribute("preload", "none")
    await expect(video).toHaveAttribute("poster", "/media/fires.jpg")
    await expect(video).not.toHaveAttribute("autoplay")
    await expect(video.muted).toBe(true)
    await expect(video.loop).toBe(true)
    video.scrollIntoView()
    await waitFor(() => expect(video.currentTime).toBeGreaterThan(0))
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
    const img = canvas.getByRole("img", { name: "Animated GIF example." }) as HTMLImageElement
    img.scrollIntoView()
    await waitFor(() => expect(img).toHaveAttribute("src", gif))
    await waitFor(() => expect(img.naturalWidth).toBe(120))
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
