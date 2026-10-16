import { create } from "storybook/theming"

// Storybook's own chrome in the site's colours (src/index.css), so the
// components sit on the page they'll really be on. Dark only, like the site.
export const theme = create({
  base: "dark",
  // the emblem and the wordmark, as in the site's header
  brandTitle: `<span style="display:flex;align-items:center;gap:10px">
    <img src="./favicon.svg" width="26" height="26" alt="" />
    <span style="font-weight:700;letter-spacing:0.28em;text-transform:uppercase;color:#f2ebd6">Frontline</span>
  </span>`,
  brandUrl: "https://github.com/Dynasty9/Frontline",
  brandTarget: "_blank",

  colorPrimary: "#f5c96e",
  colorSecondary: "#f5c96e",

  appBg: "#0e1211",
  appContentBg: "#0a0c0b",
  appPreviewBg: "#0a0c0b",
  appBorderColor: "rgb(255 255 255 / 9%)",
  appBorderRadius: 4,

  fontBase: "Bahnschrift, 'Barlow', 'Segoe UI', system-ui, sans-serif",
  fontCode: "ui-monospace, 'Cascadia Mono', Consolas, monospace",

  textColor: "#edede3",
  textMutedColor: "#9ea394",
  textInverseColor: "#15120b",

  barBg: "#0e1211",
  barTextColor: "#9ea394",
  barSelectedColor: "#f5c96e",
  barHoverColor: "#f5c96e",

  inputBg: "#151917",
  inputBorder: "rgb(255 255 255 / 12%)",
  inputTextColor: "#edede3",
  inputBorderRadius: 4,
})
