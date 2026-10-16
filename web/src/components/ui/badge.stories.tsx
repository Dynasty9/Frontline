import { WarningIcon } from "@phosphor-icons/react"
import type { Meta, StoryObj } from "@storybook/react-vite"
import { Badge } from "@/components/ui/badge"

const meta = {
  title: "UI/Badge",
  component: Badge,
  args: { children: "Your system" },
  argTypes: {
    variant: {
      control: "select",
      options: ["default", "secondary", "destructive", "outline", "ghost", "link"],
    },
  },
} satisfies Meta<typeof Badge>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}
export const Secondary: Story = { args: { variant: "secondary" } }
export const Destructive: Story = {
  args: { variant: "destructive", children: "Offline" },
}
export const Outline: Story = { args: { variant: "outline" } }

/** The battle list's status badges, recoloured with the game's palette. */
export const BattleStatus: Story = {
  render: () => (
    <div className="flex flex-wrap items-center gap-1.5">
      <Badge variant="outline" className="border-good/40 text-good">
        In the lobby
      </Badge>
      <Badge variant="outline" className="border-primary/40 text-primary">
        In battle · drop-in
      </Badge>
      <Badge variant="outline" className="text-muted-foreground">
        In battle · closed
      </Badge>
      <Badge variant="outline" className="border-warn/40 text-warn">
        <WarningIcon />
        Strict router
      </Badge>
    </div>
  ),
}
