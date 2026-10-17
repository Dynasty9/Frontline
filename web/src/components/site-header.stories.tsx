import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { SiteHeader } from "@/components/site-header"
import { player } from "@/test/fixtures"
import { signedIn } from "@/test/network"

const meta = { title: "Site/Header", component: SiteHeader, parameters: { layout: "fullscreen" } } satisfies Meta<
  typeof SiteHeader
>
export default meta
type Story = StoryObj<typeof meta>
export const Default: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const nav = within(canvas.getByRole("navigation", { name: "Site" }))
    await expect(nav.getAllByRole("link")).toHaveLength(4)
    await expect(nav.queryByRole("link", { name: "Ranks" })).toBeNull()
    await expect(canvas.getByRole("link", { name: "Play free" })).toHaveAttribute("href", "/play")
  },
}
export const Overlay: Story = { args: { overlay: true }, parameters: { backgrounds: { value: "card" } } }
export const Phone: Story = { globals: { viewport: { value: "mobile1" } } }
export const SignedIn: Story = { beforeEach: signedIn(player) }
export const AccountsOff: Story = {
  args: { accounts: "off" },
  play: async ({ canvasElement }) => {
    await expect(within(canvasElement).queryByRole("button", { name: "Sign in" })).toBeNull()
  },
}
