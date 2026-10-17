import type { Preview } from "@storybook/react-vite"
import { MemoryRouter } from "react-router"
import { TooltipProvider } from "@/components/ui/tooltip"
import { theme } from "./theme"
import "../src/index.css"

// index.html puts the site in dark mode; the stories' page has to as well
document.documentElement.classList.add("dark")

// Join and Find Match links would ask the browser to open the game. Here they
// only report the click (the stories' onLaunch).
document.addEventListener(
  "click",
  (e) => {
    if (e.target instanceof Element && e.target.closest('a[href^="frontline:"]')) e.preventDefault()
  },
  true
)

const preview: Preview = {
  tags: ["autodocs"],
  // The site's layout wraps every page in one provider; a story gets its own.
  // A component's links need a router to belong to: one in memory, unless the
  // story is a whole page with the site's own router (src/test/router.tsx,
  // parameters.router: false).
  decorators: [
    (Story, { parameters }) => {
      const story = (
        <TooltipProvider delayDuration={150}>
          <Story />
        </TooltipProvider>
      )
      return parameters.router === false ? story : <MemoryRouter>{story}</MemoryRouter>
    },
  ],
  parameters: {
    layout: "padded",
    docs: { theme },
    backgrounds: {
      options: {
        page: { name: "Page", value: "#0a0c0b" },
        card: { name: "Card", value: "#0e1211" },
      },
    },
    controls: {
      matchers: { color: /(background|color)$/i, date: /Date$/i },
    },
    // every story is also an accessibility test (npm run test:stories): a
    // violation fails it, in CI as well as in the Storybook panel
    a11y: { test: "error" },
  },
  initialGlobals: {
    backgrounds: { value: "page" },
  },
}

export default preview
