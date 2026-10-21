import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { health, ravenBattle, ravenPublic } from "@/test/fixtures"
import { loadPage } from "@/test/load-page"
import { mockMatchmaker } from "@/test/network"
import { SiteAt } from "@/test/router"

// /player/:callsign/battle/:id: a battle's after-action report, as the player's game kept it.
const meta = {
  title: "Pages/Battle",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: `/player/Raven/battle/${ravenBattle.id}` },
  beforeEach: mockMatchmaker({ health, players: [ravenPublic], reports: { Raven: [ravenBattle] } }),
} satisfies Meta<typeof SiteAt>

export default meta
type Story = StoryObj<typeof meta>

/** How it went, their part, every commander rated as the game rates them, and the two sides head to head. */
export const Report: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 1, name: "Co-op vs the AI" })).toBeVisible()
    await expect(canvas.getByText("Victory")).toBeVisible()
    await expect(canvas.getByText("Outstanding")).toBeVisible()
    // Raven's own row, marked; the AI's too
    const commanders = within(canvas.getByRole("heading", { name: "Commanders" }).closest("section")!)
    await expect(commanders.getAllByRole("row")).toHaveLength(1 + ravenBattle.report.players!.length)
    await expect(commanders.getByText("Coalition AI")).toBeVisible()
    // the side that killed more, marked the better
    const sides = within(canvas.getByRole("heading", { name: "The two sides" }).closest("section")!)
    const killed = sides.getByText("Enemy killed").closest("tr")!
    await expect(within(killed).getByText("29")).toHaveClass("text-good")
    await expect(canvas.getByRole("link", { name: "Raven" })).toHaveAttribute("href", "/player/Raven")
  },
}

/** A battle that isn't on their record (or they keep their battles back). */
export const NotFound: Story = {
  args: { path: "/player/Raven/battle/6c0f4e9a-0000-4000-8000-00000000dead" },
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByRole("heading", { level: 1, name: "No such battle" })).toBeVisible()
  },
}

export const Phone: Story = {
  globals: { viewport: { value: "mobile1" } },
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByRole("heading", { level: 1, name: "Co-op vs the AI" })).toBeVisible()
  },
}
