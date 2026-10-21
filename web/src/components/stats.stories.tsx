import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { Stats } from "@/components/stats"
import { STATS } from "@/lib/intel"

const meta = {
  title: "Site/Stats",
  component: Stats,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof Stats>

export default meta
type Story = StoryObj<typeof meta>

/** The numbers roll up (or, for imported assets, down to nothing) as they come into view. */
export const Counters: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    for (const s of STATS) await expect(canvas.getByText(s.label)).toBeInTheDocument()
    await expect(await canvas.findByText("97", undefined, { timeout: 4000 })).toBeInTheDocument()
  },
}
