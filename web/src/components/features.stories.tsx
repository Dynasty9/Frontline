import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { Features } from "@/components/features"

const meta = {
  title: "Site/Features",
  component: Features,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof Features>

export default meta
type Story = StoryObj<typeof meta>

/** Five rows, each a clip beside what it shows; they slide in as they scroll into view. */
export const Default: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getAllByRole("article")).toHaveLength(5)
    await expect(canvas.getByRole("heading", { name: "Call it in" })).toBeInTheDocument()
  },
}
