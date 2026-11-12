import { useSyncExternalStore } from "react"

function subscribe(onChange: () => void) {
  window.addEventListener("load", onChange)
  return () => window.removeEventListener("load", onChange)
}

/**
 * True once the page has finished loading (its scripts, styles, fonts and the
 * pictures above the fold): what can wait, like a looping clip behind the
 * headline, waits for it, so the first paint has the line to itself.
 */
export function usePageLoaded() {
  return useSyncExternalStore(subscribe, () => document.readyState === "complete")
}
