import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import App from "@/App"
import { ghReleases, health, healthQuiet, lobbies, lobbyOpen, stableBuild } from "@/test/fixtures"
import { mockNetwork } from "@/test/network"

// The whole front page, fetching from a stand-in matchmaker and GitHub.
const meta = {
  title: "Site/Page",
  component: App,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof App>

export default meta
type Story = StoryObj<typeof meta>

export const Live: Story = {
  beforeEach: mockNetwork({ lobbies, health, releases: ghReleases }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText(lobbyOpen.name)).toBeVisible()
    await expect(await canvas.findByText(/battles live/)).toBeVisible()
    // the newest release with its zips uploaded, not the draft or the one still uploading
    const downloads = await canvas.findAllByRole("link", { name: "Download for Windows" })
    for (const d of downloads) await expect(d).toHaveAttribute("href", stableBuild.assets.windows?.url)
  },
}

export const NobodyHosting: Story = {
  beforeEach: mockNetwork({ lobbies: [], health: healthQuiet, releases: ghReleases }),
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByText("Nobody is hosting right now")).toBeVisible()
  },
}

/** The matchmaker and GitHub both down: the page still says what to do. */
export const Offline: Story = {
  beforeEach: mockNetwork({}),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText("Can't reach the matchmaker")).toBeVisible()
    await expect(await canvas.findByText(/Couldn't reach GitHub/)).toBeVisible()
  },
}
