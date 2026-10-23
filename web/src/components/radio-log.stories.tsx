import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { RadioLog } from "@/components/radio-log"
import { RADIO } from "@/lib/intel"

// The hero's command net: real lines from the missions, typed out one by one.
const meta = {
  title: "Site/Radio log",
  component: RadioLog,
  args: { className: "w-[22rem]" },
} satisfies Meta<typeof RadioLog>

export default meta
type Story = StoryObj<typeof meta>

export const CommandNet: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByText("Command net")).toBeVisible()
    // the lines already in show whole; the next one types in after them
    await expect(canvas.getByText(RADIO[0][1])).toBeInTheDocument()
  },
}
