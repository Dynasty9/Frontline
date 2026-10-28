import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, userEvent, within } from "storybook/test"
import { health } from "@/test/fixtures"
import { mockMatchmaker } from "@/test/network"
import { loadPage } from "@/test/load-page"
import { SiteAt } from "@/test/router"

const meta = {
  title: "Pages/Vehicles",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: "/vehicles" },
  beforeEach: mockMatchmaker({ health }),
} satisfies Meta<typeof SiteAt>
export default meta
type Story = StoryObj<typeof meta>
export const Roster: Story = {}
export const SearchAndFilter: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const search = await canvas.findByRole("searchbox", { name: "Search vehicles" })
    await userEvent.type(search, "hUnTeR HMG")
    await expect(canvas.getAllByRole("heading", { level: 2 })).toHaveLength(1)
    await expect(canvas.getByRole("heading", { name: "Hunter HMG" })).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Air support" }))
    await expect(canvas.getByRole("heading", { name: "No vehicles found" })).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Clear filters" }))
    await expect(search).toHaveValue("")
    await userEvent.click(canvas.getByRole("button", { name: "Field Manual only" }))
    await expect(canvas.getByRole("heading", { name: "Hatchback" })).toBeVisible()
    await expect(canvas.queryByRole("heading", { name: "Hunter" })).toBeNull()
  },
}
