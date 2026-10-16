import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { Missions } from "@/components/missions"
import { MISSIONS } from "@/lib/intel"

const meta = {
  title: "Site/Missions",
  component: Missions,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof Missions>

export default meta
type Story = StoryObj<typeof meta>

/** Every mission the game's menu lists, the first on the big tile. */
export const Default: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    for (const m of MISSIONS) await expect(canvas.getByRole("heading", { name: m.title })).toBeInTheDocument()
  },
}
