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
    invite: null,
    onDismissInvite: fn(),
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

/** What each battle is, and a padlock on the one that wants a password. */
export const Modes: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getAllByText("Mission · Bridgehead")[0]).toBeInTheDocument()
    await expect(canvas.getAllByText("Versus · 3 v 2")[0]).toBeInTheDocument()
    await expect(canvas.getAllByText("Co-op vs AI · Rebels")[0]).toBeInTheDocument()
    await expect(canvas.getAllByLabelText("Password")).toHaveLength(1)
  },
}

/** A friend's invite link (?join=ID): their battle up top, with a Join button. */
export const Invited: Story = {
  args: { invite: lobbyOpen.id },
  play: async ({ args, canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByText("Raven invited you to Bridgehead at dawn")).toBeVisible()
    const join = canvas.getByRole("link", { name: "Join Raven's battle" })
    await expect(join).toHaveAttribute("href", `frontline://join/${lobbyOpen.id}`)
    await userEvent.click(join)
    await expect(args.onLaunch).toHaveBeenCalledOnce()
  },
}

/** An invite to a battle that has since closed. */
export const InviteEnded: Story = {
  args: { invite: "0000deadbeef" },
  play: async ({ args, canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByText("That battle has ended")).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Dismiss" }))
    await expect(args.onDismissInvite).toHaveBeenCalledOnce()
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
