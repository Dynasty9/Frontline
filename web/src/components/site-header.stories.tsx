import type { Meta, StoryObj } from "@storybook/react-vite"
import { SiteHeader } from "@/components/site-header"

const meta = {
  title: "Site/Header",
  component: SiteHeader,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof SiteHeader>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}

/** On the front page it floats clear over the hero's footage until the page scrolls. */
export const Overlay: Story = {
  args: { overlay: true },
  parameters: { backgrounds: { value: "card" } },
}

/** On a phone the section links go, and only the GitHub button stays. */
export const Phone: Story = {
  globals: { viewport: { value: "mobile1" } },
}
