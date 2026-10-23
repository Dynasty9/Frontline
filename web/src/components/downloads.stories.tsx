import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { Downloads } from "@/components/downloads"
import { assetFor } from "@/lib/releases"
import { buildWithInstallers, buildWithMac, buildWithoutInstallers } from "@/test/fixtures"

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
      assetFor("windows").url
    )
    await expect(canvas.getByRole("link", { name: "Download for Linux" })).toHaveAttribute(
      "href",
      assetFor("linux").url
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
      assetFor("macos", buildWithMac).url
    )
    await expect(canvas.getByText(/Open Anyway/)).toBeVisible()
    await expect(canvas.getAllByRole("link", { name: /^Download for / })).toHaveLength(3)
  },
}

/** Installers for Windows and the Mac: the buttons give those, and each card keeps its zip a link away. */
export const WithInstallers: Story = {
  args: { build: buildWithInstallers },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole("link", { name: "Download for Windows" })).toHaveAttribute(
      "href",
      buildWithInstallers.installers!.windows!.url
    )
    await expect(canvas.getByRole("link", { name: "Download for macOS" })).toHaveAttribute(
      "href",
      buildWithInstallers.installers!.macos!.url
    )
    // Linux has no installer: its button is the zip, with nothing beside it
    await expect(canvas.getByRole("link", { name: "Download for Linux" })).toHaveAttribute(
      "href",
      buildWithInstallers.assets.linux.url
    )
    const zips = canvas.getAllByRole("link", { name: "or the zip, to run without installing" })
    await expect(zips.map((a) => a.getAttribute("href"))).toEqual([
      buildWithInstallers.assets.windows.url,
      buildWithInstallers.assets.macos!.url,
    ])
    await expect(canvas.getByText(/The installer needs no administrator rights/)).toBeVisible()
    await expect(canvas.getByText(/drag Frontline into Applications/)).toBeVisible()
  },
}

/** A release from before the installers: the zips, and how to run them. */
export const ZipsOnly: Story = {
  args: { build: buildWithoutInstallers },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole("link", { name: "Download for Windows" })).toHaveAttribute(
      "href",
      buildWithoutInstallers.assets.windows.url
    )
    await expect(canvas.queryByRole("link", { name: /or the zip/ })).toBeNull()
    await expect(canvas.getByText(/Unzip it anywhere and run Frontline/)).toBeVisible()
  },
}
