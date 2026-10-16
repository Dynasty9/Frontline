import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import App from "@/App"
import { latest } from "@/lib/releases"
import { health, healthQuiet, lobbies, lobbyOpen } from "@/test/fixtures"
import { mockMatchmaker } from "@/test/network"

// The whole front page, polling a stand-in matchmaker.
const meta = {
  title: "Site/Page",
  component: App,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof App>

export default meta
type Story = StoryObj<typeof meta>

export const Live: Story = {
  beforeEach: mockMatchmaker({ lobbies, health }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText(lobbyOpen.name)).toBeVisible()
    await expect(await canvas.findByText(/battles live/)).toBeVisible()
    // the hero's button and the Windows card both offer the baked-in release
    const downloads = canvas.getAllByRole("link", { name: "Download for Windows" })
    for (const d of downloads) await expect(d).toHaveAttribute("href", latest.assets.windows.url)
  },
}

export const NobodyHosting: Story = {
  beforeEach: mockMatchmaker({ lobbies: [], health: healthQuiet }),
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByText("Nobody is hosting right now")).toBeVisible()
  },
}

/** The matchmaker down: the page still says what to do, and the downloads still work. */
export const MatchmakerDown: Story = {
  beforeEach: mockMatchmaker({}),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText("Can't reach the matchmaker")).toBeVisible()
    await expect(canvas.getAllByRole("link", { name: "Download for Linux" })[0]).toHaveAttribute(
      "href",
      latest.assets.linux.url
    )
  },
}
