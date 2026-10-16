import { useEffect, useState } from "react"

type PollState<T> = {
  data: T | undefined
  error: Error | null
  loading: boolean
  updatedAt: number | null
}

/**
 * Calls `load` now and every `everyMs` after, while the tab is visible (a
 * background tab doesn't keep asking). Keeps the last good data through a
 * failed refresh. `load` should be a stable function (a module-level one).
 */
export function usePoll<T>(load: (signal: AbortSignal) => Promise<T>, everyMs: number): PollState<T> {
  const [state, setState] = useState<PollState<T>>({ data: undefined, error: null, loading: true, updatedAt: null })

  useEffect(() => {
    let timer: number | undefined
    let ctl: AbortController | undefined
    let stopped = false

    const tick = async () => {
      window.clearTimeout(timer)
      if (document.hidden) return
      ctl?.abort()
      ctl = new AbortController()
      try {
        const data = await load(ctl.signal)
        if (!stopped) setState({ data, error: null, loading: false, updatedAt: Date.now() })
      } catch (e) {
        if (stopped || (e as Error).name === "AbortError") return
        setState((s) => ({ ...s, error: e as Error, loading: false }))
      }
      if (!stopped) timer = window.setTimeout(tick, everyMs)
    }
    const onVisible = () => {
      if (!document.hidden) tick()
    }

    tick()
    document.addEventListener("visibilitychange", onVisible)
    return () => {
      stopped = true
      window.clearTimeout(timer)
      ctl?.abort()
      document.removeEventListener("visibilitychange", onVisible)
    }
  }, [load, everyMs])

  return state
}
