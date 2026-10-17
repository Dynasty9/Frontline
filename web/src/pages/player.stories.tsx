import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
import { health, player, ravenBattle, ravenBattles, ravenCareer, ravenPublic } from "@/test/fixtures"
import { loadPage } from "@/test/load-page"
import { mockMatchmaker, signedIn } from "@/test/network"
import { SiteAt } from "@/test/router"

// /player/:callsign: a commander's public page, as anyone sees it.
const meta = {
  title: "Pages/Player",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: "/player/raven" },
} satisfies Meta<typeof SiteAt>

export default meta
type Story = StoryObj<typeof meta>

const world = {
  health,
  players: [ravenPublic, { ...ravenPublic, callsign: "Kite", history: false, position: 9, avatar: null }],
  battles: { Raven: ravenBattles },
  careers: { Raven: ravenCareer },
  reports: { Raven: [ravenBattle] },
}

/** Their rank and record, their career and their battles, whatever case the address has. */
export const Public: Story = {
  beforeEach: mockMatchmaker(world),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 1, name: "Raven" })).toBeVisible()
    await expect(canvas.getByText(/Corporal I · rank 6 of 50/)).toBeVisible()
    await expect(canvas.getByRole("link", { name: "#4" })).toHaveAttribute("href", "/leaderboards")
    await expect(await canvas.findByText("Kills per man lost")).toBeVisible()
    const fought = within((await canvas.findByRole("heading", { name: "Battles" })).closest("section")!)
    const battle = await fought.findByRole("link", { name: "Co-op vs the AI" })
    await expect(battle).toHaveAttribute("href", `/player/Raven/battle/${ravenBattle.id}`)
    // the best of them, under the career
    await expect(canvas.getByText(/Best battle/)).toBeVisible()
    // not yours: nothing to edit
    await expect(canvas.queryByRole("link", { name: "Edit your profile" })).toBeNull()
  },
}

/** One of their battles, opened from their page. */
export const OpenABattle: Story = {
  beforeEach: mockMatchmaker(world),
  loaders: [() => import("@/pages/battle").then(() => ({}))],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const fought = within((await canvas.findByRole("heading", { name: "Battles" })).closest("section")!)
    await userEvent.click(await fought.findByRole("link", { name: "Co-op vs the AI" }))
    await waitFor(() => expect(canvas.getByRole("heading", { level: 2, name: "Raven's part" })).toBeVisible())
  },
}

/** A player who keeps their battles to themselves: the card, and a word to say so. */
export const KeptBack: Story = {
  args: { path: "/player/Kite" },
  beforeEach: mockMatchmaker(world),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText("Kite keeps their battles to themselves.")).toBeVisible()
    await expect(canvas.queryByRole("heading", { name: "Battles" })).toBeNull()
  },
}

/** Your own page: a way to edit it. */
export const Yours: Story = {
  beforeEach: [mockMatchmaker({ ...world, me: player }), signedIn(player)],
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByRole("link", { name: "Edit your profile" })).toHaveAttribute(
      "href",
      "/profile"
    )
  },
}

/** Nobody goes by that callsign. */
export const NoSuchPlayer: Story = {
  args: { path: "/player/Nobody" },
  beforeEach: mockMatchmaker(world),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 1, name: /No such commander/ })).toBeVisible()
    await expect(canvas.getByRole("searchbox", { name: "Find a commander" })).toBeVisible()
  },
}

export const Phone: Story = {
  beforeEach: mockMatchmaker(world),
  globals: { viewport: { value: "mobile1" } },
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByRole("heading", { level: 1, name: "Raven" })).toBeVisible()
  },
}
