import type { Meta, StoryObj } from "@storybook/react-vite"
import { Emblem, Wordmark } from "@/components/emblem"

const meta = {
  title: "Site/Emblem",
  component: Emblem,
  args: { className: "size-24" },
} satisfies Meta<typeof Emblem>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}

/** The lockup in the header and the hero. */
export const WithWordmark: Story = {
  render: (args) => (
    <div className="flex items-center gap-4">
      <Emblem {...args} />
      <Wordmark className="text-5xl" />
    </div>
  ),
  args: { className: "size-14" },
}
