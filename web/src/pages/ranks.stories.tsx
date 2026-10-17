import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, screen, userEvent, waitFor, within } from "storybook/test"
import { RANKS } from "@/lib/insignia"
import { health, player } from "@/test/fixtures"
import { mockMatchmaker, signedIn } from "@/test/network"
import { loadPage } from "@/test/load-page"
import { SiteAt } from "@/test/router"

const meta = {
  title: "Pages/Ranks",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: "/ranks" },
} satisfies Meta<typeof SiteAt>
export default meta
type Story = StoryObj<typeof meta>
export const SignedOut: Story = {
  beforeEach: mockMatchmaker({ health }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 1, name: /Every battle/ })).toBeVisible()
    await expect(canvas.getAllByRole("row")).toHaveLength(RANKS.length + 1)
    await expect(canvas.getByRole("link", { name: "Rank guide" })).toHaveAttribute("aria-current", "page")
    await userEvent.click(canvas.getByRole("button", { name: "Sign in to track progress" }))
    await waitFor(() => expect(screen.getByRole("dialog", { name: "Sign in to Frontline" })).toBeVisible())
    await userEvent.keyboard("{Escape}")
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull())
  },
}
export const SignedIn: Story = {
  beforeEach: [mockMatchmaker({ health, me: player }), signedIn(player)],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("link", { name: "Choose your insignia" })).toHaveAttribute(
      "href",
      "/profile#your-insignia"
    )
    await expect(canvas.getByText("You")).toBeVisible()
    await expect(canvas.queryByRole("button", { pressed: true })).toBeNull()
  },
}
export const AccountsOff: Story = {
  beforeEach: mockMatchmaker({ health: { ...health, accounts: "off" } }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText(/Accounts are currently unavailable/)).toBeVisible()
    await expect(canvas.queryByRole("button", { name: /Sign in/ })).toBeNull()
  },
}
