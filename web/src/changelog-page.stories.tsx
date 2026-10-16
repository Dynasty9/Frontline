import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import ChangelogPage from "@/changelog-page"
import { releases } from "@/lib/changelog"

// /changelog/: every release in the site's changelog, newest first.
const meta = {
  title: "Site/Changelog page",
  component: ChangelogPage,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof ChangelogPage>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const cards = canvas.getAllByRole("heading", { level: 2 })
    await expect(cards.map((h) => h.textContent)).toEqual(releases.map((r) => r.name))
    // only the newest is marked as the latest
    await expect(canvas.getAllByText("Latest")).toHaveLength(1)
  },
}
