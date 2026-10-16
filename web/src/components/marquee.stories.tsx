import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within } from "storybook/test"
import { Marquee, TickerBands } from "@/components/marquee"
import { TICKER } from "@/lib/intel"

const meta = {
  title: "Site/Ticker",
  component: Marquee,
  args: { items: TICKER, className: "bg-primary py-3 text-primary-foreground" },
} satisfies Meta<typeof Marquee>

export default meta
type Story = StoryObj<typeof meta>

/** One band: the row twice over, so the loop never shows a join. */
export const OneBand: Story = {
  args: { itemClassName: "font-display text-2xl font-extrabold uppercase" },
  play: async ({ canvasElement }) => {
    await expect(within(canvasElement).getAllByText(TICKER[0])).toHaveLength(2)
  },
}

/** The two bands crossing under the hero. */
export const Crossing: Story = {
  parameters: { layout: "fullscreen" },
  render: () => <TickerBands />,
}
