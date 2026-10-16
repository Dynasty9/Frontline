import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, fn, userEvent, within } from "storybook/test"
import { Battles } from "@/components/battles"
import { lobbies, lobbyClosed, lobbyDropIn, lobbyFull, lobbyOpen, lobbyStrict } from "@/test/fixtures"

const meta = {
  title: "Site/Battles",
  component: Battles,
  parameters: { layout: "fullscreen" },
  args: {
    lobbies,
    error: null,
    updatedAt: Date.now(),
    launched: false,
    onLaunch: fn(),
    onDismissLaunch: fn(),
  },
} satisfies Meta<typeof Battles>

export default meta
type Story = StoryObj<typeof meta>

/** Every kind of listing: open, drop-in, closed, full, and a host behind a strict router. */
export const Live: Story = {
  play: async ({ args, canvasElement }) => {
    const canvas = within(canvasElement)
    // the battles you can join first, otherwise in the matchmaker's order
    const rows = canvas.getAllByRole("row").slice(1)
    const order = [lobbyDropIn, lobbyOpen, lobbyStrict, lobbyFull, lobbyClosed]
    await expect(rows).toHaveLength(order.length)
    for (const [i, l] of order.entries()) await expect(rows[i]).toHaveTextContent(l.name)
    await expect(canvas.getByRole("button", { name: "Full" })).toBeDisabled()
    await expect(canvas.getByRole("button", { name: "Closed" })).toBeDisabled()

    const join = canvas.getAllByRole("link", { name: "Join" })
    await expect(join).toHaveLength(3)
    await expect(join[0]).toHaveAttribute("href", `frontline://join/${lobbyDropIn.id}`)
    await userEvent.click(join[0])
    await expect(args.onLaunch).toHaveBeenCalledOnce()
  },
}

/** Before the first answer from the matchmaker. */
export const Loading: Story = {
  args: { lobbies: undefined, updatedAt: null },
}

/** Nobody hosting: the way in is Find Match. */
export const Empty: Story = {
  args: { lobbies: [] },
  play: async ({ args, canvasElement }) => {
    const canvas = within(canvasElement)
    const find = canvas.getByRole("link", { name: /Find a match/ })
    await expect(find).toHaveAttribute("href", "frontline://find-match")
    await userEvent.click(find)
    await expect(args.onLaunch).toHaveBeenCalledOnce()
  },
}

/** The matchmaker has never answered. */
export const Unreachable: Story = {
  args: { lobbies: undefined, updatedAt: null, error: new Error("The matchmaker answered 502") },
}

/** A refresh failed: the last list stays up, marked as reconnecting. */
export const Reconnecting: Story = {
  args: { error: new Error("Failed to fetch"), updatedAt: Date.now() - 12_000 },
  play: async ({ canvasElement }) => {
    await expect(within(canvasElement).getByText(/Reconnecting/)).toBeVisible()
  },
}

/** After a Join or Find Match link: what to do if the game didn't open. */
export const Launched: Story = {
  args: { launched: true },
  play: async ({ args, canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByText("Opening Frontline…")).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Dismiss" }))
    await expect(args.onDismissLaunch).toHaveBeenCalledOnce()
  },
}
