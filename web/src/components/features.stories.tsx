import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { Features } from "@/components/features"

const meta = { title: "Site/Features", component: Features, parameters: { layout: "fullscreen" } } satisfies Meta<
  typeof Features
>
export default meta
type Story = StoryObj<typeof meta>
export const Default: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole("heading", { name: /The road is covered/ })).toBeInTheDocument()
    await expect(canvas.getByRole("heading", { name: "Call it in" })).toBeInTheDocument()
    await expect(canvas.getByRole("heading", { name: "Open another front" })).toBeInTheDocument()
  },
}
