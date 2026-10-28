import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, spyOn, userEvent, waitFor, within } from "storybook/test"
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
    const frame = (await canvas.findByTitle(/3D model of/)) as HTMLIFrameElement
    const initialSrc = frame.getAttribute("src")
    const messages = spyOn(frame.contentWindow!, "postMessage")
    const receive = (type: string, key?: string, source: Window | null = frame.contentWindow) =>
      window.dispatchEvent(new MessageEvent("message", { origin: window.location.origin, source, data: { type, key } }))
    receive("frontline-model-loaded")
    const search = await canvas.findByRole("searchbox", { name: "Vehicle roster" })
    await userEvent.type(search, "hunter hmg")
    await expect(canvas.getByRole("heading", { name: "Hunter HMG" })).toBeVisible()
    await expect(await canvas.findByTitle("3D model of Hunter HMG")).toBe(frame)
    await expect(frame).toHaveAttribute("src", initialSrc)
    await waitFor(() =>
      expect(messages).toHaveBeenCalledWith(
        { type: "frontline-model", action: "select", key: "hunter_hmg" },
        window.location.origin
      )
    )
    await expect(canvas.queryByRole("dialog")).toBeNull()
    receive("frontline-model-ready", "hunter_hmg", null)
    await expect(canvas.getByRole("button", { name: "Zoom in" })).toBeDisabled()
    receive("frontline-model-ready", "hunter_hmg")
    await waitFor(() => expect(canvas.getByRole("button", { name: "Zoom in" })).toBeEnabled())
    await userEvent.clear(search)
    await userEvent.type(search, "no-such-vehicle")
    await expect(frame).toBeInTheDocument()
    await expect(frame).not.toBeVisible()
    await userEvent.clear(search)
    await expect(canvas.getByTitle(/3D model of/)).toBe(frame)
    await expect(frame).toHaveAttribute("src", initialSrc)
    messages.mockRestore()
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
