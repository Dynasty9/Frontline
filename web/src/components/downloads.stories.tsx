import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { Downloads } from "@/components/downloads"
import { latest } from "@/lib/releases"
import { buildWithMac } from "@/test/fixtures"

// Always the latest release, baked into the site (src/release.json).
const meta = {
  title: "Site/Downloads",
  component: Downloads,
  parameters: { layout: "fullscreen" },
  args: { platform: "windows" },
} satisfies Meta<typeof Downloads>

export default meta
type Story = StoryObj<typeof meta>

/** The visitor's own system's button filled in. */
export const WindowsVisitor: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole("link", { name: "Download for Windows" })).toHaveAttribute(
      "href",
      latest.assets.windows.url
    )
    await expect(canvas.getByRole("link", { name: "Download for Linux" })).toHaveAttribute(
      "href",
      latest.assets.linux.url
    )
    await expect(canvas.getByText("Your system")).toBeVisible()
  },
}

export const LinuxVisitor: Story = {
  args: { platform: "linux" },
}

/** A release with a Mac build: a third card, and the Mac's own steps. */
export const MacVisitor: Story = {
  args: { platform: "macos", build: buildWithMac },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole("link", { name: "Download for macOS" })).toHaveAttribute(
      "href",
      buildWithMac.assets.macos!.url
    )
    await expect(canvas.getByText(/Open Anyway/)).toBeVisible()
    await expect(canvas.getAllByRole("link", { name: /^Download for / })).toHaveLength(3)
  },
}
