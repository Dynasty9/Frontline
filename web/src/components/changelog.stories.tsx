import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, screen, userEvent, waitFor, within } from "storybook/test"
import { KindBadge, ReleaseCard, WhatsNew } from "@/components/changelog"
import { releases } from "@/lib/changelog"
import { release } from "@/test/fixtures"

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
