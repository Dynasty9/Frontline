import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, fn, within } from "storybook/test"
import { Hero } from "@/components/hero"
import { health, healthQuiet, nightlyBuild, stableBuild } from "@/test/fixtures"

const meta = {
  title: "Site/Hero",
  component: Hero,
  parameters: { layout: "fullscreen" },
  args: {
    health,
    build: stableBuild,
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
      stableBuild.assets.windows?.url
    )
  },
}

export const NoBattles: Story = {
  args: { health: healthQuiet },
}

/** Before the matchmaker and GitHub answer: the download button falls back to the downloads section. */
export const Loading: Story = {
  args: { health: undefined, build: null },
  play: async ({ canvasElement }) => {
    await expect(within(canvasElement).getByRole("link", { name: "Download for Windows" })).toHaveAttribute(
      "href",
      "#download"
    )
  },
}

export const NightlyBuild: Story = {
  args: { build: nightlyBuild, platform: "linux" },
}
