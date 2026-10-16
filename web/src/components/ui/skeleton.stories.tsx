import type { Meta, StoryObj } from "@storybook/react-vite"
import { Skeleton } from "@/components/ui/skeleton"

const meta = {
  title: "UI/Skeleton",
  component: Skeleton,
  args: { className: "h-4 w-48" },
} satisfies Meta<typeof Skeleton>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}

/** The battle list while it loads: a name, a player count and a button per row. */
export const BattleRows: Story = {
  render: () => (
    <div className="max-w-xl space-y-3">
      {[0, 1, 2].map((i) => (
        <div key={i} className="flex items-center gap-4">
          <Skeleton className="h-4 flex-1" />
          <Skeleton className="h-4 w-20" />
          <Skeleton className="h-8 w-14" />
        </div>
      ))}
    </div>
  ),
}
