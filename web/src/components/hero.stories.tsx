import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, fn, within } from "storybook/test"
import { Hero } from "@/components/hero"
import { latest } from "@/lib/releases"
import { health, healthQuiet } from "@/test/fixtures"

const meta = {
  title: "Site/Hero",
  component: Hero,
  parameters: { layout: "fullscreen" },
  args: {
    health,
    platform: "windows",
    onLaunch: fn(),
  },
} satisfies Meta<typeof Hero>

export default meta
type Story = StoryObj<typeof meta>

export const BattlesLive: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByText(`${health.lobbies} battles live · ${health.players} players`)).toBeVisible()
    await expect(canvas.getByRole("link", { name: "Download for Windows" })).toHaveAttribute(
      "href",
      latest.assets.windows.url
    )
  },
}

export const NoBattles: Story = {
  args: { health: healthQuiet },
}

/** Before the matchmaker answers: the line under the buttons is left blank, not a guess. */
export const Loading: Story = {
  args: { health: undefined },
  play: async ({ canvasElement }) => {
    await expect(within(canvasElement).queryByText(/battles? live|No battles/)).toBeNull()
  },
}

export const LinuxVisitor: Story = {
  args: { platform: "linux" },
}
