import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, fn, screen, userEvent, waitFor } from "storybook/test"
import { GameSignIn } from "@/components/game-sign-in"

// The game sent the player here to sign in. The dialog renders outside the
// story's canvas (a portal), so the play functions look on the whole screen.
// Where it sends the browser (GitHub, then the game's link) is only recorded
// (navigate), never opened, and the stand-in matchmaker answers only what each
// story needs.

const STATE = "014d51f106f3e7f8399fdc9d92c2b20c"
const USER = { id: "u1", email: "octocat@github.test", callsign: "octocat", icon: "s01", xp: 0, rank: 0 }
const SESSION = { access_token: "access-1", refresh_token: "token-1", expires_in: 3600, user: USER }

/** A stand-in matchmaker: these paths answer, everything else is down. */
function mockMatchmaker(answers: Record<string, unknown>) {
  return () => {
    const realFetch = globalThis.fetch
    globalThis.fetch = async (input) => {
      const path = new URL(input instanceof Request ? input.url : String(input)).pathname
      return path in answers ? Response.json(answers[path]) : Response.json({ error: "down" }, { status: 503 })
    }
    return () => {
      globalThis.fetch = realFetch
      sessionStorage.removeItem("frontline.github")
    }
  }
}

const meta = {
  title: "Site/Game sign-in",
  component: GameSignIn,
  args: {
    request: { state: STATE, create: false, callsign: "" },
    accounts: "supabase",
    email: false,
    onClose: fn(),
    navigate: fn(),
  },
} satisfies Meta<typeof GameSignIn>

export default meta
type Story = StoryObj<typeof meta>

/** What players see: GitHub, and off they go, the game's request kept for when they're back. */
export const SignIn: Story = {
  beforeEach: mockMatchmaker({ "/auth/oauth": { url: "https://github.test/authorize" } }),
  play: async ({ args }) => {
    await waitFor(() => expect(screen.getByRole("dialog", { name: "Sign in to Frontline" })).toBeVisible())
    await expect(screen.queryByLabelText("Password")).toBeNull()
    await userEvent.click(screen.getByRole("button", { name: "Sign in with GitHub" }))
    await waitFor(() => expect(args.navigate).toHaveBeenCalledWith("https://github.test/authorize"))
    const away = JSON.parse(sessionStorage.getItem("frontline.github") ?? "null")
    await expect(away.game.state).toBe(STATE)
    await expect(away.verifier).toMatch(/^[A-Za-z0-9_-]{43}$/)
  },
}

/** Back from GitHub: the code swapped for the game's own session, and handed to the game. */
export const BackFromGitHub: Story = {
  args: {
    returned: { game: { state: STATE, create: false, callsign: "" }, code: "code-back", verifier: "v".repeat(43) },
  },
  beforeEach: mockMatchmaker({ "/auth/exchange": { session: SESSION } }),
  play: async ({ args }) => {
    // it fades in: keep looking until it has
    await waitFor(() => expect(screen.getByRole("heading", { name: "You're signed in" })).toBeVisible())
    const link = `frontline://sign-in/${STATE}/token-1`
    await expect(args.navigate).toHaveBeenCalledOnce()
    await expect(args.navigate).toHaveBeenCalledWith(link)
    await expect(screen.getByRole("link", { name: "Open Frontline" })).toHaveAttribute("href", link)
    // the game's session, not the site's: the site stays signed out
    await expect(localStorage.getItem("frontline.account")).toBeNull()
  },
}

/** GitHub (or the player) said no: why, and the button to try again. */
export const GitHubSaidNo: Story = {
  args: {
    returned: { game: { state: STATE, create: false, callsign: "" }, error: "The user denied access" },
  },
  play: async ({ args }) => {
    await expect(await screen.findByRole("alert")).toHaveTextContent("GitHub didn't sign you in")
    await expect(screen.getByRole("button", { name: "Sign in with GitHub" })).toBeEnabled()
    await expect(args.navigate).not.toHaveBeenCalled()
  },
}

/** A test build (the dev server, or a local matchmaker): email and password under GitHub. */
export const Testing: Story = {
  args: { email: true },
  beforeEach: mockMatchmaker({ "/auth/login": { session: SESSION } }),
  play: async ({ args }) => {
    await waitFor(() => expect(screen.getByRole("dialog", { name: "Sign in to Frontline" })).toBeVisible())
    await userEvent.type(screen.getByLabelText("Email"), "tester@example.test")
    await userEvent.type(screen.getByLabelText("Password"), "password1")
    await userEvent.click(screen.getAllByRole("button", { name: "Sign in" })[1])
    // it fades in: keep looking until it has
    await waitFor(() => expect(screen.getByRole("heading", { name: "You're signed in" })).toBeVisible())
    await expect(args.navigate).toHaveBeenCalledWith(`frontline://sign-in/${STATE}/token-1`)
  },
}

/** Create account pressed in a test build of the game: the form opens on it, with the name they play under. */
export const TestingNewAccount: Story = {
  args: { email: true, request: { state: STATE, create: true, callsign: "Some Name" } },
  play: async () => {
    await waitFor(() => expect(screen.getByRole("dialog", { name: "Sign in to Frontline" })).toBeVisible())
    await expect(screen.getByRole("button", { name: "Create account", pressed: true })).toBeVisible()
    await expect(screen.getByLabelText("Callsign")).toHaveValue("Some Name")
  },
}

/** A matchmaker without accounts: nothing to sign in to. */
export const AccountsOff: Story = {
  args: { accounts: "off" },
  play: async () => {
    await waitFor(() => expect(screen.getByText(/isn't taking sign-ins right now/)).toBeVisible())
    await expect(screen.queryByRole("button", { name: "Sign in with GitHub" })).toBeNull()
  },
}

/** On a phone. */
export const Phone: Story = {
  globals: { viewport: { value: "mobile1" } },
}
