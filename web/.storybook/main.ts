import type { StorybookConfig } from "@storybook/react-vite"

// Stories sit next to their components (button.stories.tsx by button.tsx).
// Storybook builds them with the site's own vite.config.ts: the same @/ alias
// and Tailwind, and public/ for the screenshots and the favicon.
const config: StorybookConfig = {
  stories: ["../src/**/*.stories.@(ts|tsx)"],
  addons: ["@storybook/addon-docs", "@storybook/addon-a11y", "@storybook/addon-vitest"],
  framework: "@storybook/react-vite",
  staticDirs: ["../public"],
  core: { disableTelemetry: true },
}

export default config
