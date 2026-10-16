import type { Meta, StoryObj } from "@storybook/react-vite"
import { Gallery } from "@/components/gallery"

const meta = {
  title: "Site/Gallery",
  component: Gallery,
  parameters: { layout: "fullscreen" },
} satisfies Meta<typeof Gallery>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}
