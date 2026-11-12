import type { Meta, StoryObj } from "@storybook/react-vite"
import { expect, spyOn, userEvent, waitFor, within } from "storybook/test"
import { health } from "@/test/fixtures"
import { mockMatchmaker } from "@/test/network"
import { loadPage } from "@/test/load-page"
import { SiteAt } from "@/test/router"

// The Field Manual: its overview, and a page for each kind of thing in the
// game, with the game's own 3D viewer (stood in for here: an exported game
// doesn't boot in Storybook, so the stories speak its message protocol).

const meta = {
  title: "Pages/Manual",
  component: SiteAt,
  parameters: { layout: "fullscreen", router: false },
  loaders: [loadPage],
  args: { path: "/manual/vehicles" },
  beforeEach: mockMatchmaker({ health }),
} satisfies Meta<typeof SiteAt>
export default meta
type Story = StoryObj<typeof meta>

/** The viewer, asked for (it waits for the visitor, unless they've loaded it on this device before). */
async function load(page: HTMLElement, name: RegExp = /3D model of/) {
  const canvas = within(page)
  // once the viewer's manifest has answered: its Load button, or the viewer itself if it was loaded before
  const first = await waitFor(() => {
    const found = canvas.queryByRole("button", { name: /Load 3D models/ }) ?? canvas.queryByTitle(name)
    if (!found) throw new Error("No 3D viewer yet")
    return found
  })
  if (first.tagName === "BUTTON") await userEvent.click(first)
  return (await canvas.findByTitle(name)) as HTMLIFrameElement
}

/** A stand-in viewer: the frame emptied, and its messages to and from the page by hand. */
async function viewer(frame: HTMLIFrameElement) {
  await new Promise<void>((resolve) => {
    frame.addEventListener("load", () => resolve(), { once: true })
    frame.src = "about:blank"
  })
  const messages = spyOn(frame.contentWindow!, "postMessage")
  const receive = (type: string, key?: string, source: Window | null = frame.contentWindow) =>
    window.dispatchEvent(new MessageEvent("message", { origin: window.location.origin, source, data: { type, key } }))
  return { messages, receive }
}

/** How the game fights, and the way into every chapter. */
export const Overview: Story = {
  args: { path: "/manual" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 1, name: /How Frontline fights/ })).toBeVisible()
    const chapters = within(canvas.getByRole("navigation", { name: "Chapters" }))
    await expect(chapters.getByRole("link", { name: /Vehicles/ })).toHaveAttribute("href", "/manual/vehicles")
    await expect(chapters.getByRole("link", { name: /Buildings/ })).toHaveAttribute("href", "/manual/buildings")
    await expect(canvas.getByRole("heading", { name: /Supply decides it/ })).toBeInTheDocument()
    await expect(canvas.getByRole("table", { name: "Each side's forces" })).toBeInTheDocument()
    // the header's Manual is this page
    await expect(
      within(canvas.getByRole("navigation", { name: "Site" })).getByRole("link", { name: "Manual" })
    ).toHaveAttribute("aria-current", "page")
  },
}

export const Vehicles: Story = {}

/** The vehicle roster's old address goes to the manual's vehicles. */
export const OldVehiclesLink: Story = {
  args: { path: "/vehicles" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 1, name: /Know your motor pool/ })).toBeVisible()
    await expect(canvas.getByRole("link", { name: "Vehicles", current: "page" })).toHaveAttribute(
      "href",
      "/manual/vehicles"
    )
  },
}

/** A link to an entry opens on it, with the game's figures. */
export const Infantry: Story = {
  args: { path: "/manual/infantry?entry=engineer" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const entry = within(await canvas.findByRole("article", { name: "Engineer" }))
    await expect(entry.getByText("x2.0 faster")).toBeVisible()
    await expect(entry.getByText("In: Engineers")).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Weapons" }))
    await userEvent.click(canvas.getByRole("button", { name: /^\.50 cal/ }))
    await expect(canvas.getByRole("heading", { level: 2, name: ".50 cal" })).toBeVisible()
    await expect(canvas.getByText(/Used by: .*\.50 Cal Nest/)).toBeVisible()
  },
}

/** Each side's buildings: the Rebels dig tunnels; only the Coalition puts up T-Walls. */
export const Buildings: Story = {
  args: { path: "/manual/buildings" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const list = within(await canvas.findByRole("list", { name: "Buildings" }))
    await expect(list.getByRole("button", { name: /^T-Wall/ })).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Rebels" }))
    await expect(list.queryByRole("button", { name: /^T-Wall/ })).toBeNull()
    await userEvent.click(list.getByRole("button", { name: /^Tunnel Entrance/ }))
    await expect(canvas.getByRole("heading", { level: 2, name: "Tunnel Entrance" })).toBeVisible()
  },
}

/** Upgrades have no model: their page is the figures alone. */
export const Research: Story = {
  args: { path: "/manual/research" },
  beforeEach: mockMatchmaker({ health, viewer: true, manual: true }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 1, name: /Train harder/ })).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: /^Combined Arms/ }))
    const entry = within(canvas.getByRole("article", { name: "Combined Arms" }))
    await expect(entry.getByText("Armoured Warfare")).toBeVisible()
    await expect(canvas.queryByTitle(/3D model of/)).toBeNull()
  },
}

/** No such chapter. */
export const Unknown: Story = {
  args: { path: "/manual/nope" },
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByRole("heading", { name: /Off the map/ })).toBeVisible()
  },
}

export const InspectModel: Story = {
  beforeEach: mockMatchmaker({ health, viewer: true, manual: true }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const frame = await load(canvasElement)
    const { messages, receive } = await viewer(frame)
    const initialSrc = frame.getAttribute("src")
    receive("frontline-model-loaded")
    const search = await canvas.findByRole("searchbox", { name: "Vehicles" })
    await userEvent.type(search, "hunter hmg")
    await expect(canvas.getByRole("heading", { level: 2, name: "Hunter HMG" })).toBeVisible()
    await expect(await canvas.findByTitle("3D model of Hunter HMG")).toBe(frame)
    await expect(frame).toHaveAttribute("src", initialSrc)
    await waitFor(() =>
      expect(messages).toHaveBeenCalledWith(
        { type: "frontline-model", action: "select", key: "hunter_hmg" },
        window.location.origin
      )
    )
    receive("frontline-model-ready", "hunter_hmg", null)
    await expect(canvas.getByRole("button", { name: "Zoom in" })).toBeDisabled()
    receive("frontline-model-ready", "hunter_hmg")
    await waitFor(() => expect(canvas.getByRole("button", { name: "Zoom in" })).toBeEnabled())
    await userEvent.clear(search)
    await userEvent.type(search, "no-such-vehicle")
    await expect(frame).toBeInTheDocument()
    await expect(frame).not.toBeVisible()
    await userEvent.clear(search)
    await expect(canvas.getByTitle(/3D model of/)).toBe(frame)
    // another chapter keeps the same viewer, and sends it the new entry
    await userEvent.click(
      within(canvas.getByRole("navigation", { name: "Field Manual" })).getByRole("link", { name: "Buildings" })
    )
    await expect(await canvas.findByRole("heading", { level: 1, name: /Build it/ })).toBeVisible()
    await expect(canvas.getByTitle("3D model of FOB")).toBe(frame)
    await waitFor(() =>
      expect(messages).toHaveBeenCalledWith(
        { type: "frontline-model", action: "select", key: "fob" },
        window.location.origin
      )
    )
    messages.mockRestore()
  },
}

export const SupportDemo: Story = {
  beforeEach: mockMatchmaker({ health, viewer: true, manual: true }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const frame = await load(canvasElement)
    const { messages, receive } = await viewer(frame)
    receive("frontline-model-loaded")
    const search = await canvas.findByRole("searchbox", { name: "Vehicles" })
    await userEvent.type(search, "wipeout")
    receive("frontline-model-ready", "wipeout")
    const play = await canvas.findByRole("button", { name: "Watch gun run" })
    await waitFor(() => expect(play).toBeEnabled())
    await userEvent.click(play)
    await expect(messages).toHaveBeenCalledWith(
      { type: "frontline-model", action: "demo", key: "wipeout" },
      window.location.origin
    )
    await expect(canvas.getByRole("button", { name: "Replay sortie" })).toBeDisabled()
    receive("frontline-demo-ready", "wipeout")
    await waitFor(() => expect(canvas.getByRole("button", { name: "Replay sortie" })).toBeEnabled())
    receive("frontline-demo-ended")
    await expect(await canvas.findByText("Sortie complete")).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Back to model" }))
    receive("frontline-model-ready", "wipeout")
    await waitFor(() => expect(canvas.getByRole("button", { name: "Zoom in" })).toBeEnabled())
    await expect(canvas.getByTitle(/3D model of/)).toBe(frame)
    messages.mockRestore()
  },
}

/** A fire mission's own page flies its sortie too. */
export const FireSupport: Story = {
  args: { path: "/manual/support?entry=ac130" },
  beforeEach: mockMatchmaker({ health, viewer: true, manual: true }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const frame = await load(canvasElement, /3D model of AC-130U/)
    const { messages, receive } = await viewer(frame)
    receive("frontline-model-loaded")
    receive("frontline-model-ready", "ac130")
    const play = await canvas.findByRole("button", { name: "Watch air support" })
    await waitFor(() => expect(play).toBeEnabled())
    await userEvent.click(play)
    await expect(messages).toHaveBeenCalledWith(
      { type: "frontline-model", action: "demo", key: "ac130" },
      window.location.origin
    )
    messages.mockRestore()
  },
}

/** The viewer is the whole game: it says how big it is and waits to be asked for. */
export const AsksBeforeDownloading: Story = {
  beforeEach: [
    mockMatchmaker({ health, viewer: true, manual: true }),
    () => {
      localStorage.removeItem("frontline:3d-models")
    },
  ],
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const ask = await canvas.findByRole("button", { name: "Load 3D models · 249 MB" })
    await expect(canvas.queryByTitle(/3D model of/)).toBeNull()
    await userEvent.click(ask)
    await expect(await canvas.findByTitle(/3D model of/)).toBeInTheDocument()
    await expect(localStorage.getItem("frontline:3d-models")).toBe("on")
  },
}

export const OlderViewer: Story = {
  beforeEach: mockMatchmaker({ health, viewer: true }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByText("3D preview unavailable")).toBeVisible()
    await expect(canvas.queryByTitle(/3D model of/)).toBeNull()
  },
}

export const SearchAndFilter: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const search = await canvas.findByRole("searchbox", { name: "Vehicles" })
    await userEvent.type(search, "hUnTeR HMG")
    const list = within(canvas.getByRole("list", { name: "Vehicles" }))
    await expect(list.getAllByRole("button")).toHaveLength(1)
    await expect(canvas.getByRole("heading", { level: 2, name: "Hunter HMG" })).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Air support" }))
    await expect(canvas.getByRole("heading", { name: "Nothing found" })).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Clear filters" }))
    await expect(search).toHaveValue("")
    await userEvent.click(canvas.getByRole("button", { name: "Field Manual only" }))
    await userEvent.click(list.getByRole("button", { name: /^Hatchback Civilian/ }))
    await expect(canvas.getByRole("heading", { level: 2, name: "Hatchback" })).toBeVisible()
    await expect(canvas.getByText(/not a unit you can order/)).toBeVisible()
  },
}

/** A failed Godot boot must not be hidden behind an endless loading message. */
export const ViewerStartupError: Story = {
  beforeEach: mockMatchmaker({ health, viewer: true, manual: true }),
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const frame = await load(canvasElement)
    await new Promise<void>((resolve) => {
      frame.addEventListener("load", () => resolve(), { once: true })
      frame.src = "about:blank"
    })
    const notice = frame.contentDocument!.createElement("div")
    notice.id = "status-notice"
    frame.contentDocument!.body.append(notice)
    notice.textContent = "WebGL2 - Check web browser configuration and hardware support"
    await expect(await canvas.findByText("3D preview couldn't start")).toBeVisible()
    await expect(canvas.getByText(/Enable graphics acceleration/)).toBeVisible()
    await expect(canvas.getByRole("button", { name: "Zoom in" })).toBeDisabled()
    const search = canvas.getByRole("searchbox", { name: "Vehicles" })
    await userEvent.type(search, "hunter hmg")
    await expect(canvas.getByText("3D preview couldn't start")).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: "Retry preview" }))
    await expect(canvas.queryByText("3D preview couldn't start")).toBeNull()
    await expect(canvas.getByTitle(/3D model of/)).not.toBe(frame)
  },
}

/** Every entry has its own address, which a link (and its card) opens on. */
export const EntryAddress: Story = {
  args: { path: "/manual/vehicles/tank" },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(await canvas.findByRole("heading", { level: 2, name: "Battle Tank" })).toBeVisible()
    await userEvent.click(canvas.getByRole("button", { name: /^Humvee/ }))
    await expect(canvas.getByRole("heading", { level: 2, name: "Humvee" })).toBeVisible()
    await waitFor(() => expect(document.title).toBe("Humvee · Vehicles · Frontline"))
  },
}

/** An entry that isn't in the manual is no page at all. */
export const UnknownEntry: Story = {
  args: { path: "/manual/vehicles/no-such-vehicle" },
  play: async ({ canvasElement }) => {
    await expect(await within(canvasElement).findByRole("heading", { name: /Off the map/ })).toBeVisible()
  },
}
