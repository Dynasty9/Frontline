import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, waitFor, within } from "storybook/test"
import { latest } from "@/lib/releases"
import { health, healthQuiet, lobbies, lobbyOpen } from "@/test/fixtures"
import { mockMatchmaker } from "@/test/network"
import { loadPage } from "@/test/load-page"
import { SiteAt } from "@/test/router"

// The whole front page, polling a stand-in matchmaker.
const meta = {
  title: "Pages/Home",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: "/" },
} satisfies Meta<typeof SiteAt>

export default meta
type Story = StoryObj<typeof meta>

export const Live: Story = {
  beforeEach: mockMatchmaker({ lobbies, health }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText(lobbyOpen.name)).toBeVisible()
    await expect(await canvas.findByText(`${health.lobbies} battles live · ${health.players} players`)).toBeVisible()
    // Play goes to the play page; the hero's download and the Windows card both offer the baked-in release
    await expect(canvas.getAllByRole("link", { name: "Play now" })[0]).toHaveAttribute("href", "/play")
    const downloads = canvas.getAllByRole("link", { name: "Download for Windows" })
    for (const d of downloads) await expect(d).toHaveAttribute("href", latest.assets.windows.url)
    // the header says how many battles are on
    await expect(canvas.getByRole("link", { name: `Battles ${health.lobbies} battles live` })).toHaveAttribute(
      "href",
      "/battles"
    )
  },
}

/** More battles than the front page lists: the rest are a link away. */
export const ManyBattles: Story = {
  beforeEach: mockMatchmaker({
    lobbies: [...lobbies, ...lobbies.map((l) => ({ ...l, id: `${l.id}-2`, name: `${l.name} II` }))],
    health,
  }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const more = await canvas.findByRole("link", { name: /5 more battles/ })
    await expect(more).toHaveAttribute("href", "/battles")
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

/** A friend's invite, from the game (/?join=ID): it's shown on the battles page. */
export const Invite: Story = {
  args: { path: `/?join=${lobbyOpen.id}` },
  // where it's sent: the battles page
  loaders: [() => import("@/pages/battles").then(() => ({}))],
  beforeEach: mockMatchmaker({ lobbies, health }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await waitFor(() => expect(canvas.getByText("Raven invited you to Bridgehead at dawn")).toBeVisible())
    await expect(canvas.getByRole("heading", { level: 1, name: /Live battles/ })).toBeVisible()
  },
}
