import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, userEvent, waitFor, within } from "storybook/test"
import { latest } from "@/lib/releases"
import { health } from "@/test/fixtures"
import { mockMatchmaker } from "@/test/network"
import { loadPage } from "@/test/load-page"
import { SiteAt } from "@/test/router"

// /play: launch or download the desktop game, and the browser version beside it.

/** A `beforeEach` that makes the page think it's on another computer. */
const visitor =
  (userAgent: string, touchPoints = 0) =>
  () => {
    const real = Object.getOwnPropertyDescriptors(navigator)
    Object.defineProperty(navigator, "userAgent", { value: userAgent, configurable: true })
    Object.defineProperty(navigator, "maxTouchPoints", { value: touchPoints, configurable: true })
    return () => {
      // the real ones are on Navigator's prototype: dropping ours brings them back
      if (!real.userAgent) delete (navigator as { userAgent?: string }).userAgent
      if (!real.maxTouchPoints) delete (navigator as { maxTouchPoints?: number }).maxTouchPoints
    }
  }

const WINDOWS = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140.0"
const LINUX = "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0"
const MAC = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_6) AppleWebKit/605.1.15 Safari/605.1.15"
const PHONE = "Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 Chrome/140.0 Mobile"

const meta = {
  title: "Pages/Play",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: "/play" },
  beforeEach: mockMatchmaker({ health }),
} satisfies Meta<typeof SiteAt>

export default meta
type Story = StoryObj<typeof meta>

/** On Windows: launch the game, find a match, or download it. */
export const Windows: Story = {
  beforeEach: visitor(WINDOWS),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 1, name: /Report for duty/ })).toBeVisible()
    await expect(canvas.getByRole("link", { name: "Launch Frontline" })).toHaveAttribute("href", "frontline://open")
    await expect(canvas.getByRole("link", { name: "Find a match" })).toHaveAttribute("href", "frontline://find-match")
    await expect(canvas.getByRole("link", { name: /^Download for Windows ·/ })).toHaveAttribute(
      "href",
      latest.assets.windows.url
    )
    // the browser version isn't out yet
    await expect(canvas.getByRole("button", { name: "Arrives with the next release" })).toBeDisabled()
  },
}

/**
 * Launch with nothing to open the link (as here): the page never loses
 * focus, so after a moment it says the game most likely isn't installed.
 */
export const NotInstalled: Story = {
  beforeEach: visitor(WINDOWS),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await userEvent.click(await canvas.findByRole("link", { name: "Launch Frontline" }))
    await expect(canvas.getByText("Opening Frontline…")).toBeVisible()
    await waitFor(() => expect(canvas.getByText(/Frontline isn't on this computer yet/)).toBeVisible(), {
      timeout: 5000,
    })
  },
}

/** The browser handing the link over: the page loses focus, and says the game is on its way. */
export const Opened: Story = {
  // the page remembers the game opened here: forget it again after
  beforeEach: [visitor(WINDOWS), () => () => localStorage.removeItem("frontline.installed")],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await userEvent.click(await canvas.findByRole("link", { name: "Launch Frontline" }))
    window.dispatchEvent(new Event("blur"))
    await waitFor(() => expect(canvas.getByText(/Over to the game/)).toBeVisible())
    await expect(localStorage.getItem("frontline.installed")).toBe("1")
  },
}

export const Linux: Story = {
  beforeEach: visitor(LINUX),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("link", { name: /^Download for Linux ·/ })).toHaveAttribute(
      "href",
      latest.assets.linux.url
    )
  },
}

/** No Mac build: say so, rather than offer the Windows one. */
export const Mac: Story = {
  beforeEach: visitor(MAC),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText(/There's no Mac version yet/)).toBeVisible()
    await expect(canvas.queryByRole("link", { name: "Launch Frontline" })).toBeNull()
  },
}

export const Phone: Story = {
  beforeEach: visitor(PHONE, 5),
  globals: { viewport: { value: "mobile1" } },
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByText(/played with a keyboard and mouse/)).toBeVisible()
  },
}
