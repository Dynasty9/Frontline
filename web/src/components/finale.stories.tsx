import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { Finale } from "@/components/finale"
import { latest } from "@/lib/releases"

const meta = {
  title: "Site/Finale",
  component: Finale,
  parameters: { layout: "fullscreen" },
  args: { platform: "windows" },
} satisfies Meta<typeof Finale>

export default meta
type Story = StoryObj<typeof meta>

export const WindowsVisitor: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole("link", { name: "Download for Windows" })).toHaveAttribute(
      "href",
      latest.assets.windows.url
    )
    // the play page launches the game, or says how to get it
    await expect(canvas.getByRole("link", { name: "Play now" })).toHaveAttribute("href", "/play")
  },
}

export const LinuxVisitor: Story = {
  args: { platform: "linux" },
}
