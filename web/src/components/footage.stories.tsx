import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { Clip } from "@/components/footage"

// A clip from public/media in its HUD frame; it plays while it's on screen.
const meta = {
  title: "Site/Footage clip",
  component: Clip,
  args: { name: "fires", label: "Cam 05 · Fire mission", grid: "G4", className: "aspect-video w-[640px]" },
} satisfies Meta<typeof Clip>

export default meta
type Story = StoryObj<typeof meta>

export const FireMission: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByText("Cam 05 · Fire mission")).toBeVisible()
    await expect(canvas.getByText("Grid G4")).toBeVisible()
  },
}

/** No map square: just the camera's caption and the timecode. */
export const WithoutGrid: Story = {
  args: { name: "sea", label: "Cam 06 · Naval", grid: undefined },
}
