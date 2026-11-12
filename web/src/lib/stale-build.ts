// A page's code is fetched the first time it's visited. After a deploy, a tab
// still running the old build asks for bundles that are no longer there
// (each build names its bundles after their contents), and the page can't
// load. Reloading fetches the new build, which has them; once per page, so a
// bundle that's really missing shows the page's error instead of reloading
// for ever.

type Env = {
  /** remembers which page was reloaded (sessionStorage), or null where storage is blocked */
  storage: Pick<Storage, "getItem" | "setItem" | "removeItem"> | null
  path: string
  reload: () => void
}

const KEY = "frontline:reloaded-for"

function browser(): Env {
  let storage: Env["storage"] = null
  try {
    // only a built site is deployed: under the dev server (and Storybook) a
    // page that won't load is a real error, to be shown, not reloaded past
    if (import.meta.env.PROD) storage = window.sessionStorage
  } catch {
    // blocked (a private window, or site data turned off): no reloading, then
  }
  return { storage, path: window.location.pathname, reload: () => window.location.reload() }
}

function read(storage: Env["storage"]) {
  try {
    return storage?.getItem(KEY) ?? null
  } catch {
    return null
  }
}

/** Loads a page's code; if it's gone (an older build in this tab), reloads the page once onto the new build. */
export async function withFreshBuild<T>(load: () => Promise<T>, env: () => Env = browser): Promise<T> {
  try {
    const loaded = await load()
    const { storage } = env()
    if (read(storage) !== null) {
      try {
        storage?.removeItem(KEY)
      } catch {
        // nothing to forget, then
      }
    }
    return loaded
  } catch (error) {
    const { storage, path, reload } = env()
    if (storage === null || read(storage) === path) throw error
    try {
      storage.setItem(KEY, path)
    } catch {
      throw error
    }
    reload()
    // the page is going: never settle, so nothing renders an error first
    return new Promise<T>(() => {})
  }
}
