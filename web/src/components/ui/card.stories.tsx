import { DownloadSimpleIcon, WindowsLogoIcon } from "@phosphor-icons/react"
import type { Meta, StoryObj } from "@storybook/react-vite"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"

const meta = {
  title: "UI/Card",
  component: Card,
  args: { className: "max-w-md" },
  argTypes: {
    size: { control: "inline-radio", options: ["default", "sm"] },
  },
  render: (args) => (
    <Card {...args}>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-lg font-semibold">
          <WindowsLogoIcon weight="fill" className="size-5 text-primary" />
          Windows
        </CardTitle>
        <CardDescription>Windows 10 or 11, 64-bit.</CardDescription>
      </CardHeader>
      <CardContent>
        <p className="text-muted-foreground">v0.1.9 · 14 Oct 2026 · 91 MB</p>
      </CardContent>
      <CardFooter className="bg-transparent">
        <Button className="font-semibold">
          <DownloadSimpleIcon weight="bold" />
          Download for Windows
        </Button>
      </CardFooter>
    </Card>
  ),
} satisfies Meta<typeof Card>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}

export const Small: Story = { args: { size: "sm" } }

export const ContentOnly: Story = {
  render: (args) => (
    <Card {...args}>
      <CardContent className="text-sm">A card with nothing but a body.</CardContent>
    </Card>
  ),
}
