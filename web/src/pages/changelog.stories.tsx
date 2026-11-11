import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, within, screen, userEvent, waitFor } from "storybook/test"
import { releases } from "@/lib/changelog"
import { health } from "@/test/fixtures"
import { mockMatchmaker } from "@/test/network"
import { loadPage } from "@/test/load-page"
import { SiteAt } from "@/test/router"

// /changelog: every release in the site's changelog, newest first.
const meta = {
  title: "Pages/Changelog",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: "/changelog" },
  beforeEach: mockMatchmaker({ health }),
} satisfies Meta<typeof SiteAt>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await canvas.findByRole("heading", { level: 1, name: "What's changed" })
    const cards = canvas.getAllByRole("heading", { level: 2 })
    await expect(cards.map((h) => h.textContent)).toEqual([releases[0].name])
    // only the newest is marked as the latest
    await expect(canvas.getAllByText("Latest")).toHaveLength(1)
  },
}

/** The address the game's What's new opens (/changelog/#vX.Y.Z) still works. */
export const FromTheGame: Story = {
  args: { path: `/changelog/#${releases[0]?.tag ?? ""}` },
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByRole("heading", { level: 1, name: "What's changed" })).toBeVisible()
  },
}

/** An address the site has no page for. */
export const NotFound: Story = {
  args: { path: "/no/such/page" },
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByRole("heading", { level: 1, name: /Off the map/ })).toBeVisible()
  },
}

/** Mobile navigation uses the shared Radix menu and preserves release anchors. */
export const PhoneNavigation: Story = {
  globals: { viewport: { value: "mobile1", isRotated: false } },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const trigger = await canvas.findByRole("button", { name: /Choose a release/ })
    await userEvent.click(trigger)
    const menu = await screen.findByRole("menu")
    const first = within(menu).getAllByRole("menuitem")[0]
    await expect(first).toHaveAttribute("href", `/changelog#${releases[0].tag}`)
    await userEvent.keyboard("{Escape}")
    await waitFor(() => expect(trigger).toHaveFocus())
    await expect(canvasElement.scrollWidth).toBeLessThanOrEqual(document.documentElement.clientWidth)
  },
}

/** Archive selection mounts only that release, and entry links open their own detail. */
export const OlderEntry: Story = {
  args: { path: `/changelog/#${releases[1].tag}-${releases[1].entries[0].slug}` },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 2, name: releases[1].name })).toBeVisible()
    const entry = canvasElement.querySelector(`details[id="${releases[1].tag}-${releases[1].entries[0].slug}"]`)!
    await waitFor(() => expect(entry).toHaveAttribute("open"))
    await expect(canvas.queryByRole("heading", { level: 2, name: releases[0].name })).toBeNull()
  },
}

export const InvalidLink: Story = {
  args: { path: "/changelog/#%E0%A4%A" },
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByRole("heading", { level: 2, name: releases[0].name })).toBeVisible()
  },
}

export const SwitchRelease: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const archive = within(await canvas.findByRole("navigation", { name: "Releases" }))
    await userEvent.click(archive.getByRole("link", { name: new RegExp(releases[1].tag.replaceAll(".", "\\.")) }))
    await expect(await canvas.findByRole("heading", { level: 2, name: releases[1].name })).toBeVisible()
    await expect(canvas.getAllByRole("heading", { level: 2 })).toHaveLength(1)
  },
}
