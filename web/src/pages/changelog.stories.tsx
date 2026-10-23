import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { releases } from "@/lib/changelog"
import { health } from "@/test/fixtures"
import { mockMatchmaker } from "@/test/network"
import { loadPage } from "@/test/load-page"
import { SiteAt } from "@/test/router"

// /changelog: every release in the site's changelog, newest first.
const meta = {
  title: "Pages/Changelog",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: "/changelog" },
  beforeEach: mockMatchmaker({ health }),
} satisfies Meta<typeof SiteAt>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await canvas.findByRole("heading", { level: 1, name: "What's changed" })
    const cards = canvas.getAllByRole("heading", { level: 2 })
    await expect(cards.map((h) => h.textContent)).toEqual(releases.map((r) => r.name))
    // only the newest is marked as the latest
    await expect(canvas.getAllByText("Latest")).toHaveLength(1)
  },
}

/** The address the game's What's new opens (/changelog/#vX.Y.Z) still works. */
export const FromTheGame: Story = {
  args: { path: `/changelog/#${releases[0]?.tag ?? ""}` },
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByRole("heading", { level: 1, name: "What's changed" })).toBeVisible()
  },
}

/** An address the site has no page for. */
export const NotFound: Story = {
  args: { path: "/no/such/page" },
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByRole("heading", { level: 1, name: /Off the map/ })).toBeVisible()
  },
}
