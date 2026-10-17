import { useCallback, useEffect, useRef, useState } from "react"
import { knownInstalled, rememberInstalled, watchHandoff } from "@/lib/launch"

/**
 * idle: not tried yet. waiting: the browser has the link. opened: it went to
 * the game (or its prompt). missing: nothing took it, so the game most likely
 * isn't installed.
 */
export type LaunchState = "idle" | "waiting" | "opened" | "missing"

/**
 * For a frontline:// link: put `onClick` on the <a> (the browser follows its
 * href as usual) and `state` says how the handoff went. `installed` is true
 * once this browser has opened the game before.
 */
export function useLaunch() {
  const [state, setState] = useState<LaunchState>("idle")
  const [installed, setInstalled] = useState(knownInstalled)
  const live = useRef(true)
  useEffect(() => {
    live.current = true
    return () => {
      live.current = false
    }
  }, [])

  const onClick = useCallback(() => {
    setState("waiting")
    void watchHandoff(window, document).then((handed) => {
      if (handed) {
        rememberInstalled()
        if (live.current) setInstalled(true)
      }
      if (live.current) setState(handed ? "opened" : "missing")
    })
  }, [])

  const reset = useCallback(() => setState("idle"), [])

  return { state, installed, onClick, reset }
}
