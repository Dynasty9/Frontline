import { useEffect, useRef, useState } from "react"

type Options = {
  /** stay true after the first time it's seen (reveals) rather than tracking it (videos) */
  once?: boolean
  /** grow or shrink the viewport for the test, like CSS margin: "0px 0px -10% 0px" */
  margin?: string
  /** how much of the element must be showing */
  threshold?: number
}

/** Whether an element is on screen. Attach the returned ref to it. */
export function useInView<T extends Element>({ once = false, margin = "0px", threshold = 0 }: Options = {}) {
  const ref = useRef<T>(null)
  const [inView, setInView] = useState(false)

  useEffect(() => {
    const el = ref.current
    if (!el) return
    const io = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setInView(true)
          if (once) io.disconnect()
        } else if (!once) {
          setInView(false)
        }
      },
      { rootMargin: margin, threshold }
    )
    io.observe(el)
    return () => io.disconnect()
  }, [once, margin, threshold])

  return [ref, inView] as const
}
