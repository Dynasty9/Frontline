import { useSyncExternalStore } from "react"

// The sign-in dialog: one for the whole site (src/pages/layout.tsx), opened
// from wherever a page offers signing in: the header's Sign in, the ranks
// page. Back from GitHub, the layout opens it to finish the sign-in.

let open = false
const listeners = new Set<() => void>()

function set(o: boolean) {
  if (open === o) return
  open = o
  for (const l of listeners) l()
}

export const openSignIn = () => set(true)
export const closeSignIn = () => set(false)

const subscribe = (l: () => void) => {
  listeners.add(l)
  return () => {
    listeners.delete(l)
  }
}

/** Whether the sign-in dialog is open. */
export const useSignInDialog = () => useSyncExternalStore(subscribe, () => open)
