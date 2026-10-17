import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, userEvent, within } from "storybook/test"
import { Missions } from "@/components/missions"
import { MISSIONS } from "@/lib/intel"

const meta = { title: "Site/Missions", component: Missions, parameters: { layout: "fullscreen" } } satisfies Meta<
  typeof Missions
>
export default meta
type Story = StoryObj<typeof meta>
export const Default: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    for (const m of MISSIONS) {
      const choice = canvas.getByRole("button", { name: new RegExp(m.title) })
      await userEvent.click(choice)
      await expect(choice).toHaveAttribute("aria-pressed", "true")
      await expect(canvas.getByRole("heading", { name: m.title })).toBeVisible()
      await expect(canvas.getByText(m.blurb)).toBeVisible()
      await expect(canvas.getByText(m.force, { exact: false })).toBeVisible()
      await expect(canvas.getAllByRole("button", { pressed: true })).toHaveLength(1)
    }
    const first = canvas.getByRole("button", { name: /Bridgehead/ })
    first.focus()
    await userEvent.keyboard("{Enter}")
    await expect(canvas.getByRole("heading", { name: "Bridgehead" })).toBeVisible()
  },
}
