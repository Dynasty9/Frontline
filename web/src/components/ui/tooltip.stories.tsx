import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, screen, userEvent, waitFor, within } from "storybook/test"
import { Button } from "@/components/ui/button"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"

const meta = {
  title: "UI/Tooltip",
  component: Tooltip,
  // room above the trigger for the tooltip
  parameters: { layout: "centered" },
  render: (args) => (
    <Tooltip {...args}>
      <TooltipTrigger asChild>
        <Button variant="outline">Strict router</Button>
      </TooltipTrigger>
      <TooltipContent className="max-w-64">
        This host's router can't be punched through. You'll only get in if they've forwarded UDP port 7777.
      </TooltipContent>
    </Tooltip>
  ),
} satisfies Meta<typeof Tooltip>

export default meta
type Story = StoryObj<typeof meta>

/** Hover (or focus) the trigger. */
export const Default: Story = {
  play: async ({ canvasElement }) => {
    await userEvent.hover(within(canvasElement).getByRole("button"))
    // the content is portalled to the end of <body>, outside the story's canvas
    await waitFor(() => expect(screen.getByRole("tooltip")).toHaveTextContent(/UDP port 7777/))
  },
}

export const Open: Story = {
  args: { open: true },
}
