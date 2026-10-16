import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { InsigniaSection } from "@/components/insignia"

// Signed out (the stories never sign in: that would talk to the live matchmaker).
const meta = {
  title: "Site/Insignia",
  component: InsigniaSection,
  parameters: { layout: "fullscreen" },
  args: { accounts: "supabase" },
} satisfies Meta<typeof InsigniaSection>

export default meta
type Story = StoryObj<typeof meta>

/** The collection as a new account sees it, and the sign-in form beside it. */
export const SignedOut: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole("heading", { name: "Earn your insignia" })).toBeVisible()
    // the Sign in tab and the form's button
    await expect(canvas.getAllByRole("button", { name: "Sign in" })).toHaveLength(2)
    // all 160, none of them wearable until you sign in
    const tiles = canvas.getAllByRole("listitem")
    await expect(tiles).toHaveLength(160)
    await expect(canvas.getByRole("button", { name: /^Infantry\. Every account starts with it/ })).toHaveAttribute(
      "aria-disabled",
      "true"
    )
    await expect(
      canvas.getByRole("button", { name: /^Dawn Eagles\. Unlocks at rank 21, Master Sergeant I/ })
    ).toBeVisible()
    await expect(canvas.getByRole("button", { name: /^Valor Cross\. Can't be earned yet/ })).toBeVisible()
  },
}

/** A matchmaker without accounts: the collection, and no way to sign in. */
export const AccountsOff: Story = {
  args: { accounts: "off" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.queryAllByRole("button", { name: "Sign in" })).toHaveLength(0)
    await expect(canvas.getAllByRole("listitem")).toHaveLength(160)
  },
}

/** On a phone the tiles run five to a row. */
export const Phone: Story = {
  globals: { viewport: { value: "mobile1" } },
}
