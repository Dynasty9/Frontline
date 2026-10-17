import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
import { health, lobbies, lobbyOpen } from "@/test/fixtures"
import { mockMatchmaker } from "@/test/network"
import { loadPage } from "@/test/load-page"
import { SiteAt } from "@/test/router"

// /battles: every battle being hosted, live.
const meta = {
  title: "Pages/Battles",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: "/battles" },
  beforeEach: mockMatchmaker({ lobbies, health }),
} satisfies Meta<typeof SiteAt>

export default meta
type Story = StoryObj<typeof meta>

export const Live: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 1, name: /Live battles/ })).toBeVisible()
    await waitFor(() => expect(canvas.getAllByRole("row")).toHaveLength(lobbies.length + 1))
    // the page's own link in the header is marked as the one you're on
    await expect(canvas.getByRole("link", { name: /^Battles/ })).toHaveAttribute("aria-current", "page")
  },
}

/** A friend's invite (?join=ID): their battle up top, and gone once dismissed. */
export const Invited: Story = {
  args: { path: `/battles?join=${lobbyOpen.id}` },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText("Raven invited you to Bridgehead at dawn")).toBeVisible()
    await userEvent.click(canvas.getAllByRole("button", { name: "Dismiss" })[0])
    await waitFor(() => expect(canvas.queryByText(/invited you/)).toBeNull())
  },
}
