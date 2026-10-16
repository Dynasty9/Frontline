import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, fn, screen, userEvent, waitFor } from "storybook/test"
import { ReelDialog } from "@/components/reel-dialog"

// The reel, with sound, over the page; the dialog renders outside the story's
// canvas (a portal), so the play function looks for it on the whole screen.
const meta = {
  title: "Site/Reel dialog",
  component: ReelDialog,
  args: { open: true, onClose: fn() },
} satisfies Meta<typeof ReelDialog>

export default meta
type Story = StoryObj<typeof meta>

export const Open: Story = {
  play: async ({ args }) => {
    // it fades in: keep looking until it has
    await waitFor(() => expect(screen.getByRole("dialog", { name: "Frontline gameplay footage" })).toBeVisible())
    await userEvent.click(screen.getByRole("button", { name: "Close" }))
    await expect(args.onClose).toHaveBeenCalledOnce()
  },
}
