import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
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
export const InspectModel: Story = {
  beforeEach: mockMatchmaker({ health, viewer: true, manual: true }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const search = await canvas.findByRole("searchbox", { name: "Vehicle roster" })
    await userEvent.type(search, "hunter hmg")
    await expect(canvas.getByRole("heading", { name: "Hunter HMG" })).toBeVisible()
    const frame = (await canvas.findByTitle("3D model of Hunter HMG")) as HTMLIFrameElement
    await expect(frame).toHaveAttribute("src", "/game/index.html?manual=hunter_hmg")
    await expect(canvas.queryByRole("dialog")).toBeNull()
    window.dispatchEvent(
      new MessageEvent("message", {
        origin: window.location.origin,
        data: { type: "frontline-model-ready", key: "hunter_hmg" },
      })
    )
    await expect(canvas.getByRole("button", { name: "Zoom in" })).toBeDisabled()
    window.dispatchEvent(
      new MessageEvent("message", {
        origin: window.location.origin,
        source: frame.contentWindow,
        data: { type: "frontline-model-ready", key: "hunter_hmg" },
      })
    )
    await waitFor(() => expect(canvas.getByRole("button", { name: "Zoom in" })).toBeEnabled())
  },
}
export const OlderViewer: Story = {
  beforeEach: mockMatchmaker({ health, viewer: true }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText("3D preview unavailable")).toBeVisible()
    await expect(canvas.queryByTitle(/3D model of/)).toBeNull()
  },
}
export const SearchAndFilter: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const search = await canvas.findByRole("searchbox", { name: "Vehicle roster" })
    await userEvent.type(search, "hUnTeR HMG")
    const list = within(canvas.getByRole("list", { name: "Vehicles" }))
    await expect(list.getAllByRole("button")).toHaveLength(1)
    await expect(canvas.getByRole("heading", { name: "Hunter HMG" })).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Air support" }))
    await expect(canvas.getByRole("heading", { name: "No vehicles found" })).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Clear filters" }))
    await expect(search).toHaveValue("")
    await userEvent.click(canvas.getByRole("button", { name: "Field Manual only" }))
    await userEvent.click(list.getByRole("button", { name: /^Hatchback Civilian/ }))
    await expect(canvas.getByRole("heading", { name: "Hatchback" })).toBeVisible()
    await expect(canvas.getByText(/not a unit you can order/)).toBeVisible()
  },
}
