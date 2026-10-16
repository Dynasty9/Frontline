import { InfoIcon, WarningIcon } from "@phosphor-icons/react"
import type { Meta, StoryObj } from "@storybook/react-vite"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"

const meta = {
  title: "UI/Alert",
  component: Alert,
  args: { className: "max-w-xl" },
  render: (args) => (
    <Alert {...args}>
      <InfoIcon />
      <AlertTitle>Opening Frontline…</AlertTitle>
      <AlertDescription>Your browser may ask whether to open the game.</AlertDescription>
    </Alert>
  ),
} satisfies Meta<typeof Alert>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}

/** Highlighted in the site's amber, as after pressing Join. */
export const Highlighted: Story = {
  args: { className: "max-w-xl border-primary/40 bg-primary/5" },
}

export const Destructive: Story = {
  args: { variant: "destructive", className: "max-w-xl border-destructive/30" },
  render: (args) => (
    <Alert {...args}>
      <WarningIcon />
      <AlertTitle>Can't reach the matchmaker</AlertTitle>
      <AlertDescription>The list of battles will come back by itself.</AlertDescription>
    </Alert>
  ),
}

export const TitleOnly: Story = {
  render: (args) => (
    <Alert {...args}>
      <AlertTitle>No builds have been published yet.</AlertTitle>
    </Alert>
  ),
}
