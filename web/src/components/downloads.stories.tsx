import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { Downloads } from "@/components/downloads"
import { nightlyBuild, stableBuild, windowsOnlyBuild } from "@/test/fixtures"

const meta = {
  title: "Site/Downloads",
  component: Downloads,
  parameters: { layout: "fullscreen" },
  args: {
    stable: stableBuild,
    nightly: null,
    loading: false,
    error: null,
    platform: "windows",
  },
} satisfies Meta<typeof Downloads>

export default meta
type Story = StoryObj<typeof meta>

/** The newest release, with the visitor's own system's button filled in. */
export const Release: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole("link", { name: "Download for Windows" })).toHaveAttribute(
      "href",
      stableBuild.assets.windows?.url
    )
    await expect(canvas.getByRole("link", { name: "Download for Linux" })).toHaveAttribute(
      "href",
      stableBuild.assets.linux?.url
    )
    await expect(canvas.getByText("Your system")).toBeVisible()
  },
}

export const LinuxVisitor: Story = {
  args: { platform: "linux" },
}

/** A release and a newer build of main: the nightly gets a link of its own. */
export const ReleaseAndNightly: Story = {
  args: { nightly: nightlyBuild },
  play: async ({ canvasElement }) => {
    await expect(within(canvasElement).getByRole("link", { name: /nightly/ })).toHaveAttribute("href", nightlyBuild.url)
  },
}

/** Only the nightly pre-release exists (before the first numbered release). */
export const NightlyOnly: Story = {
  args: { stable: null, nightly: nightlyBuild },
}

/** A release missing one platform's zip. */
export const MissingPlatform: Story = {
  args: { stable: windowsOnlyBuild },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByText("Not published yet.")).toBeVisible()
    await expect(canvas.getByRole("button", { name: "Download for Linux" })).toBeDisabled()
  },
}

export const Loading: Story = {
  args: { stable: null, loading: true },
}

/** GitHub didn't answer (or rate-limited the visitor). */
export const GitHubUnreachable: Story = {
  args: { stable: null, error: new Error("GitHub answered 403") },
  play: async ({ canvasElement }) => {
    await expect(within(canvasElement).getByText(/Couldn't reach GitHub/)).toBeVisible()
  },
}

export const NothingPublished: Story = {
  args: { stable: null },
}
