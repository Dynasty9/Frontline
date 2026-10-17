import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, screen, userEvent, waitFor, within } from "storybook/test"
import { health, player } from "@/test/fixtures"
import { mockMatchmaker, signedIn } from "@/test/network"
import { loadPage } from "@/test/load-page"
import { SiteAt } from "@/test/router"

// /ranks: how ranks are earned, and the insignia collection.
const meta = {
  title: "Pages/Ranks",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: "/ranks" },
} satisfies Meta<typeof SiteAt>

export default meta
type Story = StoryObj<typeof meta>

/** Signed out: the whole collection, and Sign in opens the sign-in dialog. */
export const SignedOut: Story = {
  beforeEach: mockMatchmaker({ health }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 1, name: "Earn your insignia" })).toBeVisible()
    await expect(canvas.getAllByRole("listitem")).toHaveLength(160)
    // the page's own Sign in, not the header's
    await userEvent.click(within(canvas.getByRole("main")).getByRole("button", { name: "Sign in" }))
    // it fades in: keep looking until it has
    await waitFor(() => expect(screen.getByRole("dialog", { name: "Sign in to Frontline" })).toBeVisible())
    await userEvent.keyboard("{Escape}")
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull())
  },
}

/** Signed in: their rank beside the collection, and the way to their profile. */
export const SignedIn: Story = {
  beforeEach: [mockMatchmaker({ health, me: player }), signedIn(player)],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 1, name: "Your insignia" })).toBeVisible()
    await expect(canvas.getByText("Corporal I")).toBeVisible()
    await expect(canvas.getByRole("link", { name: /Your profile: your callsign/ })).toHaveAttribute("href", "/profile")
  },
}
