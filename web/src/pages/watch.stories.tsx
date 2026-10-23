import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, userEvent, within } from "storybook/test"
import { mockMatchmaker } from "@/test/network"
import { health } from "@/test/fixtures"
import { loadPage } from "@/test/load-page"
import { SiteAt } from "@/test/router"
import type { Replay } from "@/lib/replays"

const replay: Replay = {
  id: "0123456789abcdef01234567",
  lobby: "battle",
  name: "Bridgehead at dawn",
  host: "Raven",
  version: "1.0.10",
  protocol: 9,
  status: "complete",
  duration: 1340,
  delay: 1,
  created: 1792530000000,
  verified: false,
  chunks: [{ sequence: 0, start: 0, end: 10 }],
}
const meta = {
  title: "Pages/Watch",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: `/watch/${replay.id}` },
  beforeEach: mockMatchmaker({ health, replays: [replay], viewer: true }),
} satisfies Meta<typeof SiteAt>
export default meta
type Story = StoryObj<typeof meta>

export const Ready: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { name: replay.name })).toBeVisible()
    await expect(await canvas.findByText("Take a seat at the command table.")).toBeVisible()
    await expect(canvas.getByRole("button", { name: "Open battlefield" })).toBeEnabled()
    await expect(canvas.getByText(/not been independently verified/)).toBeVisible()
  },
}
export const Player: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const page = within(canvasElement.ownerDocument.body)
    await userEvent.click(await canvas.findByRole("button", { name: "Open battlefield" }))
    const player = await page.findByRole("dialog", { name: replay.name })
    await expect(within(player).getByTitle(`Frontline battle: ${replay.name}`)).toBeVisible()
    await userEvent.click(within(player).getByRole("button", { name: /^Close$/ }))
    await expect(page.queryByRole("dialog")).not.toBeInTheDocument()
    await expect(canvas.getByRole("button", { name: "Open battlefield" })).toBeEnabled()
  },
}
export const WaitingForDelay: Story = {
  beforeEach: mockMatchmaker({
    health,
    replays: [{ ...replay, status: "live", duration: 0, chunks: [] }],
    viewer: true,
  }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText(/broadcast is starting/)).toBeVisible()
    await expect(canvas.getByRole("button", { name: "Open battlefield" })).toBeDisabled()
  },
}
export const ViewerUnavailable: Story = {
  beforeEach: mockMatchmaker({ health, replays: [replay] }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText(/compatible browser viewer is not available/)).toBeVisible()
    await expect(canvas.getByRole("button", { name: "Open battlefield" })).toBeDisabled()
  },
}
export const Expired: Story = {
  beforeEach: mockMatchmaker({ health }),
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByRole("alert")).toHaveTextContent(/expired/)
  },
}
export const Broadcasts: Story = {
  args: { path: "/battles" },
  beforeEach: mockMatchmaker({
    health,
    lobbies: [],
    replays: [replay, { ...replay, id: "abcdef0123456789abcdef01", name: "Holding the crossing", status: "live" }],
  }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("link", { name: /Watch replay.*Bridgehead/ })).toHaveAttribute(
      "href",
      `/watch/${replay.id}`
    )
    await expect(canvas.getByRole("link", { name: /Watch battle.*Holding/ })).toBeVisible()
  },
}
