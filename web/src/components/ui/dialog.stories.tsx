import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, screen, userEvent, waitFor, within } from "storybook/test"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"

const meta = {
  title: "UI/Dialog",
  component: Dialog,
  render: (args) => (
    <Dialog {...args}>
      <DialogTrigger asChild>
        <Button variant="outline">Open</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>A firefight around a Coalition trench line</DialogTitle>
          <DialogDescription>The changelog shows screenshots full size in one of these.</DialogDescription>
        </DialogHeader>
        <img src="/shots/battle.jpg" alt="A firefight around a Coalition trench line" className="w-full" />
        <DialogFooter>
          <DialogClose asChild>
            <Button variant="outline">Done</Button>
          </DialogClose>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  ),
} satisfies Meta<typeof Dialog>

export default meta
type Story = StoryObj<typeof meta>

/** Opens from its trigger; Done, the corner button or Escape closes it. */
export const Default: Story = {
  play: async ({ canvasElement }) => {
    await userEvent.click(within(canvasElement).getByRole("button", { name: "Open" }))
    // the dialog is portalled to the end of <body>, outside the story's canvas
    const dialog = await waitFor(() => screen.getByRole("dialog"))
    await expect(dialog).toHaveAccessibleName("A firefight around a Coalition trench line")
    await userEvent.click(within(dialog).getByRole("button", { name: "Done" }))
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull())
  },
}

export const Open: Story = {
  args: { open: true },
}
