import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
import { githubPlayer, health, player } from "@/test/fixtures"
import { mockMatchmaker, signedIn } from "@/test/network"
import { loadPage } from "@/test/load-page"
import { SiteAt } from "@/test/router"

// /profile: the signed-in player's callsign, rank and insignia; signed out, signing in.
const meta = {
  title: "Pages/Profile",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: "/profile" },
} satisfies Meta<typeof SiteAt>

export default meta
type Story = StoryObj<typeof meta>

export const SignedOut: Story = {
  beforeEach: mockMatchmaker({ health }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 1, name: "Sign in to Frontline" })).toBeVisible()
    await expect(canvas.getByRole("button", { name: "Sign in with GitHub" })).toBeEnabled()
    await expect(canvas.getByText(/up fifty ranks/)).toBeVisible()
  },
}

/** Signed in: the profile, the callsign, and the insignia to wear. */
export const SignedIn: Story = {
  beforeEach: [mockMatchmaker({ health, me: player }), signedIn(player)],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 1, name: "Your profile" })).toBeVisible()
    await expect(canvas.getByText("Corporal I")).toBeVisible()
    await expect(canvas.getByLabelText("Your callsign")).toHaveValue("Raven")
    // nothing to save until it changes
    await expect(canvas.getByRole("button", { name: "Save" })).toBeDisabled()
    await expect(canvas.getByRole("button", { name: /^Night Watch\. Wearing it/ })).toHaveAttribute(
      "aria-pressed",
      "true"
    )
    // the header has them too, with a menu
    await expect(canvas.getByRole("button", { name: "Your account: Raven rank 6" })).toBeVisible()
  },
}

/** A new callsign, taken by the matchmaker, and the header following it. */
export const Rename: Story = {
  beforeEach: [mockMatchmaker({ health, me: player }), signedIn(player)],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const field = await canvas.findByLabelText("Your callsign")
    await userEvent.clear(field)
    await userEvent.type(field, "Raven Six")
    await userEvent.click(canvas.getByRole("button", { name: "Save" }))
    await expect(await canvas.findByText(/You're Raven Six now/)).toBeVisible()
    await waitFor(() => expect(canvas.getByRole("button", { name: "Your account: Raven Six rank 6" })).toBeVisible())
  },
}

/** Someone has the callsign already: the form says so, and nothing changes. */
export const RenameTaken: Story = {
  beforeEach: [mockMatchmaker({ health, me: player, taken: ["Kestrel"] }), signedIn(player)],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const field = await canvas.findByLabelText("Your callsign")
    await userEvent.clear(field)
    await userEvent.type(field, "Kestrel")
    await userEvent.click(canvas.getByRole("button", { name: "Save" }))
    await expect(await canvas.findByRole("alert")).toHaveTextContent("That callsign is taken.")
    await expect(canvas.getByRole("button", { name: "Your account: Raven rank 6" })).toBeVisible()
  },
}

/** Keeping your battles to yourself, from your profile: your public page link, and the switch. */
export const KeepBattlesBack: Story = {
  beforeEach: [mockMatchmaker({ health, me: player }), signedIn(player)],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("link", { name: "See your page as they do" })).toHaveAttribute(
      "href",
      "/player/Raven"
    )
    const show = canvas.getByRole("checkbox", { name: /Show my battles/ })
    await expect(show).toBeChecked()
    await userEvent.click(show)
    await waitFor(() => expect(show).not.toBeChecked())
  },
}

/** Your picture: an email account has no GitHub picture, so only the insignia. */
export const PictureInsigniaOnly: Story = {
  beforeEach: [mockMatchmaker({ health, me: player }), signedIn(player)],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("radio", { name: /Your insignia/ })).toBeChecked()
    await expect(canvas.getByRole("radio", { name: /Your GitHub picture/ })).toBeDisabled()
  },
}

/** A GitHub account picks its GitHub picture, and the header shows it at once. */
export const PictureFromGitHub: Story = {
  beforeEach: [mockMatchmaker({ health, me: githubPlayer }), signedIn(githubPlayer)],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const github = await canvas.findByRole("radio", { name: /Your GitHub picture/ })
    await userEvent.click(github)
    await waitFor(() => expect(github).toBeChecked())
    const header = canvas.getByRole("button", { name: "Your account: Raven rank 6" })
    await waitFor(() => expect(header.querySelector("img")).toHaveAttribute("src", githubPlayer.github_avatar))
  },
}

/** Signing out of every game and browser, this one too. */
export const SignOutEverywhere: Story = {
  beforeEach: [mockMatchmaker({ health, me: player }), signedIn(player)],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await userEvent.click(await canvas.findByRole("button", { name: "Sign out everywhere" }))
    await expect(await canvas.findByRole("heading", { level: 1, name: "Sign in to Frontline" })).toBeVisible()
  },
}

/** The account menu in the header: your profile, your public page, the boards, and signing out. */
export const AccountMenu: Story = {
  beforeEach: [mockMatchmaker({ health, me: player }), signedIn(player)],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await userEvent.click(await canvas.findByRole("button", { name: "Your account: Raven rank 6" }))
    const menu = within(document.body)
    await expect(await menu.findByRole("menuitem", { name: "Your profile" })).toHaveAttribute("href", "/profile")
    await expect(menu.getByRole("menuitem", { name: "Your public page" })).toHaveAttribute("href", "/player/Raven")
    await expect(menu.getByRole("menuitem", { name: "Leaderboards" })).toHaveAttribute("href", "/leaderboards")
    await userEvent.click(menu.getByRole("menuitem", { name: "Sign out" }))
    await expect(await canvas.findByRole("heading", { level: 1, name: "Sign in to Frontline" })).toBeVisible()
  },
}

/** The profile's old address (/account) still gets there. */
export const OldAddress: Story = {
  args: { path: "/account" },
  // where it's sent: the profile page
  loaders: [() => import("@/pages/profile").then(() => ({}))],
  beforeEach: [mockMatchmaker({ health, me: player }), signedIn(player)],
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByRole("heading", { level: 1, name: "Your profile" })).toBeVisible()
  },
}

export const AccountsOff: Story = {
  beforeEach: mockMatchmaker({ health: { ...health, accounts: "off" } }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText("Accounts are switched off")).toBeVisible()
    await expect(canvas.queryByRole("button", { name: "Sign in with GitHub" })).toBeNull()
  },
}
