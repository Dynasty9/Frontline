import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
import { board, health, player, ravenPublic, weekBoard } from "@/test/fixtures"
import { loadPage } from "@/test/load-page"
import { mockMatchmaker, signedIn } from "@/test/network"
import { SiteAt } from "@/test/router"

// /leaderboards: the commanders with the most experience, all time, this month and this week.
const meta = {
  title: "Pages/Leaderboards",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: "/leaderboards" },
} satisfies Meta<typeof SiteAt>

export default meta
type Story = StoryObj<typeof meta>

const boards = { all: board, week: weekBoard, month: { ...board, period: "month" as const, rows: [] } }

/** All time: the podium, players level on XP sharing a place, and pages further down. */
export const AllTime: Story = {
  beforeEach: mockMatchmaker({ health, boards }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("link", { name: /Kestrel/ })).toHaveAttribute("href", "/player/Kestrel")
    const rows = canvas.getAllByRole("row").slice(1)
    await expect(rows).toHaveLength(board.rows.length)
    await expect(rows[1]).toHaveTextContent("2")
    await expect(rows[2]).toHaveTextContent("2")
    await expect(canvas.getByRole("link", { name: "All time" })).toHaveAttribute("aria-current", "page")
    await expect(canvas.getByText(/Page 1 of 3/)).toBeVisible()
    await expect(canvas.getByRole("link", { name: /Lower/ })).toHaveAttribute("href", "/leaderboards?page=2")
    await expect(canvas.getByRole("button", { name: /Higher/ })).toBeDisabled()
  },
}

/** Signed in and on the page: your row is marked. */
export const YouOnTheBoard: Story = {
  beforeEach: [mockMatchmaker({ health, boards, me: player }), signedIn(player)],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const you = await canvas.findByText("You")
    await expect(you.closest("tr")).toHaveTextContent("Raven")
  },
}

/** This week, signed in further down than the page reaches: your row at the foot. */
export const ThisWeek: Story = {
  args: { path: "/leaderboards?period=week" },
  beforeEach: [
    mockMatchmaker({ health, boards, me: { ...player, callsign: "Osprey" } }),
    signedIn({ ...player, callsign: "Osprey" }),
  ],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const you = await canvas.findByText("You")
    await expect(you.closest("tr")).toHaveTextContent("57")
    await expect(canvas.getByRole("columnheader", { name: "XP earned" })).toBeVisible()
    await expect(canvas.getByRole("link", { name: "This week" })).toHaveAttribute("aria-current", "page")
  },
}

/** Nobody has earned anything this month yet. */
export const Empty: Story = {
  args: { path: "/leaderboards?period=month" },
  beforeEach: mockMatchmaker({ health, boards }),
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByText("Nobody on the board yet")).toBeVisible()
  },
}

/** The matchmaker down: say so. */
export const Unreachable: Story = {
  beforeEach: mockMatchmaker({ health }),
  play: async ({ canvasElement }) => {
    await expect(
      await within(canvasElement).findByText("The leaderboards aren't available right now", {}, { timeout: 5000 })
    ).toBeVisible()
  },
}

/** Finding a commander as their callsign is typed, and going to their page. */
export const Search: Story = {
  beforeEach: mockMatchmaker({ health, boards, players: [ravenPublic] }),
  // where it goes: Raven's page
  loaders: [() => import("@/pages/player").then(() => ({}))],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await userEvent.type(await canvas.findByRole("searchbox", { name: "Find a commander" }), "ra")
    const list = await canvas.findByRole("list", { name: "Commanders found" }, { timeout: 3000 })
    await expect(within(list).getByRole("link", { name: /Raven/ })).toHaveAttribute("href", "/player/Raven")
    await userEvent.keyboard("{Enter}")
    await waitFor(() => expect(canvas.getByRole("heading", { level: 1, name: "Raven" })).toBeVisible(), {
      timeout: 5000,
    })
  },
}

export const Phone: Story = {
  beforeEach: mockMatchmaker({ health, boards }),
  globals: { viewport: { value: "mobile1" } },
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByRole("link", { name: /Kestrel/ })).toBeVisible()
  },
}
