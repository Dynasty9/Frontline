import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, screen, userEvent, waitFor, within } from "storybook/test"
import { assetFor, guessPlatform, PLATFORM_NAMES } from "@/lib/releases"
import { health, lobbies, lobbyOpen, player } from "@/test/fixtures"
import { awayAtGitHub, mockMatchmaker } from "@/test/network"
import { loadPage } from "@/test/load-page"
import { SiteAt } from "@/test/router"

// The whole front page, polling a stand-in matchmaker.

// The hero and the finale offer the build for the browser's own platform (Windows here, Linux in CI).
const platform = guessPlatform()
const download = { name: `Download for ${PLATFORM_NAMES[platform]}`, url: assetFor(platform).url }
const meta = {
  title: "Pages/Home",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: "/" },
} satisfies Meta<typeof SiteAt>

export default meta
type Story = StoryObj<typeof meta>

export const Live: Story = {
  beforeEach: mockMatchmaker({ lobbies, health }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText(`${health.lobbies} battles live · ${health.players} players`)).toBeVisible()
    // Play goes to the play page; the hero's download and the finale's both offer the baked-in release
    for (const p of canvas.getAllByRole("link", { name: "Play now" })) await expect(p).toHaveAttribute("href", "/play")
    const downloads = canvas.getAllByRole("link", { name: download.name })
    for (const d of downloads) await expect(d).toHaveAttribute("href", download.url)
    // the header says how many battles are on
    await expect(canvas.getByRole("link", { name: `Battles ${health.lobbies} battles live` })).toHaveAttribute(
      "href",
      "/battles"
    )
    // the battles, the ranks and the downloads have pages of their own
    await expect(canvas.queryByText(lobbyOpen.name)).toBeNull()
    await expect(canvas.queryByRole("heading", { name: "Earn your insignia" })).toBeNull()
    for (const r of canvas.getAllByRole("link", { name: "Ranks" })) await expect(r).toHaveAttribute("href", "/ranks")
  },
}

/** The matchmaker down: the page still sells the game, and the downloads still work. */
export const MatchmakerDown: Story = {
  beforeEach: mockMatchmaker({}),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getAllByRole("link", { name: download.name })[0]).toHaveAttribute("href", download.url)
  },
}

/** The header's Sign in opens the sign-in dialog over the page: no going looking for it. */
export const SignIn: Story = {
  beforeEach: mockMatchmaker({ lobbies, health }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await userEvent.click(await canvas.findByRole("button", { name: "Sign in" }))
    // it fades in: keep looking until it has
    await waitFor(() => expect(screen.getByRole("dialog", { name: "Sign in to Frontline" })).toBeVisible())
    await expect(screen.getByRole("button", { name: "Sign in with GitHub" })).toBeEnabled()
    await userEvent.keyboard("{Escape}")
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull())
  },
}

/** Back from GitHub (/?code=): the dialog signs them in, and on to their profile. */
export const BackFromGitHub: Story = {
  args: { path: "/?code=code-back" },
  // where it goes once signed in: the profile page
  loaders: [() => import("@/pages/profile").then(() => ({}))],
  beforeEach: [mockMatchmaker({ lobbies, health, exchange: player }), awayAtGitHub()],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    // the code swapped, /me asked, the dialog shut, the profile shown: give it a moment on a busy machine
    await expect(
      await canvas.findByRole("heading", { level: 1, name: "Your profile" }, { timeout: 5000 })
    ).toBeVisible()
    await expect(canvas.getByRole("button", { name: "Your account: Raven rank 6" })).toBeVisible()
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull())
  },
}

/** GitHub (or the player) said no: the dialog says so, with the button to try again. */
export const GitHubSaidNo: Story = {
  args: { path: "/?error=access_denied&error_description=The+user+denied+access" },
  beforeEach: [mockMatchmaker({ lobbies, health }), awayAtGitHub()],
  play: async () => {
    await waitFor(() => expect(screen.getByRole("dialog", { name: "Sign in to Frontline" })).toBeVisible())
    const dialog = within(screen.getByRole("dialog"))
    await expect(dialog.getByRole("alert")).toHaveTextContent("GitHub didn't sign you in (The user denied access)")
    await expect(dialog.getByRole("button", { name: "Sign in with GitHub" })).toBeEnabled()
  },
}

/** The game's Download button opens /#download: the downloads are on the play page now. */
export const OldDownloadLink: Story = {
  args: { path: "/#download" },
  loaders: [() => import("@/pages/play").then(() => ({}))],
  beforeEach: mockMatchmaker({ lobbies, health }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 1, name: /Report for duty/ })).toBeVisible()
    await expect(canvasElement.querySelector("#download")).not.toBeNull()
  },
}

/** A friend's invite, from the game (/?join=ID): it's shown on the battles page. */
export const Invite: Story = {
  args: { path: `/?join=${lobbyOpen.id}` },
  // where it's sent: the battles page
  loaders: [() => import("@/pages/battles").then(() => ({}))],
  beforeEach: mockMatchmaker({ lobbies, health }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await waitFor(() => expect(canvas.getByText("Raven invited you to Bridgehead at dawn")).toBeVisible())
    await expect(canvas.getByRole("heading", { level: 1, name: /Live battles/ })).toBeVisible()
  },
}
