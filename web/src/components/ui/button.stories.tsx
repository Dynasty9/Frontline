import { CrosshairIcon, DownloadSimpleIcon } from "@phosphor-icons/react"
import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, fn, userEvent, within } from "storybook/test"
import { Button } from "@/components/ui/button"

const meta = {
  title: "UI/Button",
  component: Button,
  args: { children: "Find a match", onClick: fn() },
  argTypes: {
    variant: {
      control: "select",
      options: ["default", "outline", "secondary", "ghost", "destructive", "link"],
    },
    size: {
      control: "select",
      options: ["default", "xs", "sm", "lg", "icon", "icon-xs", "icon-sm", "icon-lg"],
    },
  },
} satisfies Meta<typeof Button>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  play: async ({ args, canvasElement }) => {
    await userEvent.click(within(canvasElement).getByRole("button"))
    await expect(args.onClick).toHaveBeenCalledOnce()
  },
}

export const Outline: Story = { args: { variant: "outline" } }
export const Secondary: Story = { args: { variant: "secondary" } }
export const Ghost: Story = { args: { variant: "ghost" } }
export const Destructive: Story = {
  args: { variant: "destructive", children: "Leave battle" },
}
export const Link: Story = {
  args: { variant: "link", children: "Report a bug" },
}

export const Disabled: Story = {
  args: { variant: "outline", disabled: true, children: "Full" },
  play: async ({ args, canvasElement }) => {
    const button = within(canvasElement).getByRole("button")
    await expect(button).toBeDisabled()
    await userEvent.click(button, { pointerEventsCheck: 0 })
    await expect(args.onClick).not.toHaveBeenCalled()
  },
}

/** The hero's call to action: large, with an icon. */
export const WithIcon: Story = {
  args: {
    size: "lg",
    className: "h-11 px-5 text-sm font-semibold",
    children: (
      <>
        <DownloadSimpleIcon weight="bold" />
        Download for Windows
      </>
    ),
  },
}

/** `asChild` hands the styling to a link: Join, Find Match and the downloads are all anchors. */
export const AsLink: Story = {
  args: {
    asChild: true,
    variant: "outline",
    children: (
      <a href="frontline://find-match">
        <CrosshairIcon weight="bold" />
        Find a match
      </a>
    ),
  },
  play: async ({ canvasElement }) => {
    await expect(within(canvasElement).getByRole("link")).toHaveAttribute("data-slot", "button")
  },
}

export const Sizes: Story = {
  render: (args) => (
    <div className="flex flex-wrap items-center gap-3">
      <Button {...args} size="xs">
        Extra small
      </Button>
      <Button {...args} size="sm">
        Small
      </Button>
      <Button {...args}>Default</Button>
      <Button {...args} size="lg">
        Large
      </Button>
      <Button {...args} size="icon" aria-label="Find a match">
        <CrosshairIcon weight="bold" />
      </Button>
    </div>
  ),
}
