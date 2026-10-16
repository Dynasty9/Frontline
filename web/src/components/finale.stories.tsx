import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, fn, userEvent, within } from "storybook/test"
import { Finale } from "@/components/finale"
import { latest } from "@/lib/releases"

const meta = {
  title: "Site/Finale",
  component: Finale,
  parameters: { layout: "fullscreen" },
  args: { platform: "windows", onLaunch: fn() },
} satisfies Meta<typeof Finale>

export default meta
type Story = StoryObj<typeof meta>

export const WindowsVisitor: Story = {
  play: async ({ args, canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole("link", { name: "Download for Windows" })).toHaveAttribute(
      "href",
      latest.assets.windows.url
    )
    await userEvent.click(canvas.getByRole("link", { name: "Find a match" }))
    await expect(args.onLaunch).toHaveBeenCalledOnce()
  },
}

export const LinuxVisitor: Story = {
  args: { platform: "linux" },
}
