import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, fn, screen, userEvent, waitFor } from "storybook/test"
import { SignInDialog } from "@/components/sign-in-dialog"
import { signInForStory } from "@/lib/account"

// Signing in to the site. The dialog renders outside the story's canvas (a
// portal), so the play functions look on the whole screen. Where it sends the
// browser (GitHub) is only recorded (navigate), never opened. Signing in all
// the way, and on to the profile, is in the Pages/Home stories.

/**
 * A stand-in matchmaker that only knows where GitHub's sign-in is. After,
 * the page is as it was: off to GitHub leaves it busy until it goes, and here
 * it never does.
 */
function mockOAuth() {
  return () => {
    const realFetch = globalThis.fetch
    globalThis.fetch = async (input) => {
      const path = new URL(input instanceof Request ? input.url : String(input)).pathname
      return path === "/auth/oauth"
        ? Response.json({ url: "https://github.test/authorize" })
        : Response.json({ error: "down" }, { status: 503 })
    }
    return () => {
      globalThis.fetch = realFetch
      sessionStorage.removeItem("frontline.github")
      signInForStory(null)
    }
  }
}

const meta = {
  title: "Site/Sign-in dialog",
  component: SignInDialog,
  args: { open: true, accounts: "supabase", email: false, onClose: fn(), navigate: fn() },
} satisfies Meta<typeof SignInDialog>

export default meta
type Story = StoryObj<typeof meta>

/** What players see: GitHub, and off they go, the verifier kept for when they're back. */
export const SignIn: Story = {
  beforeEach: mockOAuth(),
  play: async ({ args }) => {
    // it fades in: keep looking until it has
    await waitFor(() => expect(screen.getByRole("dialog", { name: "Sign in to Frontline" })).toBeVisible())
    await expect(screen.queryByLabelText("Password")).toBeNull()
    await userEvent.click(screen.getByRole("button", { name: "Sign in with GitHub" }))
    await waitFor(() => expect(args.navigate).toHaveBeenCalledWith("https://github.test/authorize"))
    const away = JSON.parse(sessionStorage.getItem("frontline.github") ?? "null")
    await expect(away.game).toBeNull()
    await expect(away.verifier).toMatch(/^[A-Za-z0-9_-]{43}$/)
  },
}

/** Back from GitHub, while the code is swapped for a session. */
export const Finishing: Story = {
  args: { finishing: true },
  play: async () => {
    await waitFor(() => expect(screen.getByRole("dialog", { name: "Signing you in…" })).toBeVisible())
    await expect(screen.getByRole("status")).toHaveTextContent("Signing in with GitHub…")
    await expect(screen.queryByRole("button", { name: "Sign in with GitHub" })).toBeNull()
  },
}

/** A test build (the dev server, or a local matchmaker): email and password under GitHub. */
export const Testing: Story = {
  args: { email: true },
  play: async () => {
    await waitFor(() => expect(screen.getByRole("dialog", { name: "Sign in to Frontline" })).toBeVisible())
    await expect(screen.getByRole("button", { name: "Sign in with GitHub" })).toBeEnabled()
    await expect(screen.getByLabelText("Password")).toBeVisible()
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
