// Opening the desktop game from a frontline:// link. The browser hands the
// link to whatever registered the scheme (the game does, the first time it
// runs: scripts/autoload/links.gd), and says nothing at all when nothing did.
// What gives a handoff away is the page losing focus: the browser's "Open
// Frontline?" prompt, or the game's own window, comes up over it. No focus
// lost in a couple of seconds most likely means the game isn't installed yet
// (or the player said no to the prompt), and the page can say what to do.

type Events = Pick<EventTarget, "addEventListener" | "removeEventListener">

/** How long the browser gets to hand the link over before we take it that nothing will open it. */
export const HANDOFF_MS = 2500

/**
 * True if the page lost focus (or was hidden) within `waitMs`: the link went
 * to the game, or at least to the browser's prompt for it. False otherwise.
 */
export function watchHandoff(win: Events, doc: Events & { hidden: boolean }, waitMs = HANDOFF_MS): Promise<boolean> {
  return new Promise((resolve) => {
    let timer: ReturnType<typeof setTimeout> | undefined
    const done = (handed: boolean) => {
      clearTimeout(timer)
      win.removeEventListener("blur", away)
      doc.removeEventListener("visibilitychange", hidden)
      resolve(handed)
    }
    const away = () => done(true)
    const hidden = () => {
      if (doc.hidden) done(true)
    }
    win.addEventListener("blur", away)
    doc.addEventListener("visibilitychange", hidden)
    timer = setTimeout(() => done(false), waitMs)
  })
}

const INSTALLED_KEY = "frontline.installed"

/** This browser has handed a link to the game before, so it's installed here. */
export function knownInstalled(): boolean {
  try {
    return localStorage.getItem(INSTALLED_KEY) === "1"
  } catch {
    return false
  }
}

export function rememberInstalled() {
  try {
    localStorage.setItem(INSTALLED_KEY, "1")
  } catch {
    // no storage: the page asks again next time, which is all that's lost
  }
}
