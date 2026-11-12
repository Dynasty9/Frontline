import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, userEvent, within } from "storybook/test"
import { health } from "@/test/fixtures"
import { loadPage } from "@/test/load-page"
import { mockMatchmaker } from "@/test/network"
import { SiteAt } from "@/test/router"

const meta = {
  title: "Pages/Cutting room",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: "/cutting-room?edit=13" },
  beforeEach: mockMatchmaker({ health }),
} satisfies Meta<typeof SiteAt>
export default meta
type Story = StoryObj<typeof meta>

export const ScreenAndCompare: Story = {
  play: async ({ canvasElement }) => {
    const page = within(canvasElement)
    await expect(await page.findByRole("heading", { name: "Over the bridge" })).toBeVisible()
    await userEvent.click(page.getByRole("button", { name: "Compare editions" }))
    await expect(page.getByTitle("Synchronized edition comparison")).toBeInTheDocument()
    await userEvent.click(page.getByRole("button", { name: "Reveal the editor’s choice" }))
    await expect(page.getByText("Under the wing made the cut.")).toBeVisible()
    await userEvent.click(page.getByRole("button", { name: "First assembly" }))
    await userEvent.click(page.getByRole("button", { name: /Edition 07 Dawn crossing and falling spray/ }))
    await expect(page.getByRole("heading", { name: "Dawn crossing and falling spray", level: 2 })).toBeVisible()
  },
}
