import { useEffect, useRef } from "react"
import { BRASS, FRAGMENT, LEAN, PAN, TAP_LIFE, VERTEX } from "@/lib/topo-shader"
import { cn } from "@/lib/utils"

// How the map sits behind the pages: fainter than in the menus (it's under
// text here), the clouds fainter still, and drawn at no more than about two
// and a half million pixels (a sharp backdrop isn't worth a hot laptop).
const INK = 0.85
const COLUMN = 576 // half the pages' column (max-w-6xl), in CSS pixels: the map is quieter behind it
const QUIET = 0.5 // by this much
const CLOUDS = 0.7
const MAX_PIXELS = 2_600_000
const FPS = 30 // it drifts slowly: thirty frames a second is plenty, but a click's ring gets every frame
const START = 4 // seconds into the menu's clock: its colours start at the brass, as the site does
const SCROLL = 0.12 // how far the sheet moves as the page scrolls, against the page

/**
 * The game's menu backdrop, a living topographic map, behind every page. It
 * stays still for people who prefer reduced motion (and in automated
 * browsers) and rests while the tab is hidden. Without WebGL 2, or with only a software renderer (no graphics
 * acceleration, where even one frame of it is slow), it isn't drawn, and the
 * page keeps its plain ground.
 */
export function TopoBackdrop({ className }: { className?: string }) {
  const canvas = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const el = canvas.current
    const gl = el?.getContext("webgl2", ATTRIBUTES)
    if (!el || !gl || software(gl)) return
    const map: Map = { u: {} } as Map
    const motion = window.matchMedia("(prefers-reduced-motion: reduce)")
    // a browser driven by a program (the stories' tests, screenshots) gets one
    // still frame too: nothing there waits on the map, and the picture is the same each time
    const still = () => motion.matches || navigator.webdriver

    let raf = 0
    let last = 0
    let drawn = 0
    let clock = START
    let lost = true // until the shaders are ready
    let waiting = 0
    let scale = 1
    const mouse = { x: 0.5, y: 0.5, toX: 0.5, toY: 0.5, on: 0, inside: false, moved: false }
    const taps: { x: number; y: number; at: number }[] = []
    const tapData = new Float32Array(12)

    const resize = () => {
      const w = Math.max(1, el.clientWidth)
      const h = Math.max(1, el.clientHeight)
      scale = Math.min(window.devicePixelRatio || 1, Math.sqrt(MAX_PIXELS / (w * h)), 2)
      el.width = Math.max(1, Math.round(w * scale))
      el.height = Math.max(1, Math.round(h * scale))
    }

    const draw = () => {
      if (lost) return
      const aspect = el.width / el.height
      const on = still() ? 0 : mouse.on
      const scroll = still() ? 0 : (window.scrollY / Math.max(1, window.innerHeight)) * SCROLL
      for (let i = 0; i < 4; i++) {
        const tap = taps[i]
        tapData.set(tap ? [tap.x, tap.y, clock - tap.at] : [0.5, 0.5, 99], i * 3)
      }
      gl.viewport(0, 0, el.width, el.height)
      // (WebGL's, not a React hook)
      // oxlint-disable-next-line react/rules-of-hooks
      gl.useProgram(map.program)
      gl.uniform2f(map.u.res, el.width, el.height)
      gl.uniform1f(map.u.clock, clock)
      gl.uniform2f(map.u.lean, (mouse.x - 0.5) * aspect * LEAN * on, (mouse.y - 0.5) * LEAN * on)
      gl.uniform2f(map.u.cam, clock * PAN, scroll)
      gl.uniform3fv(map.u.taps, tapData)
      gl.uniform1f(map.u.ink, INK)
      gl.uniform2f(map.u.column, Math.min(COLUMN, el.clientWidth / 2) * scale, QUIET)
      gl.uniform1f(map.u.clouds, CLOUDS)
      gl.uniform1f(map.u.grain, still() ? 0 : 1)
      gl.bindVertexArray(map.vao)
      gl.drawArrays(gl.TRIANGLES, 0, 3)
      el.dataset.drawn = ""
    }

    const frame = (now: number) => {
      raf = requestAnimationFrame(frame)
      const busy = taps.some((t) => clock - t.at < TAP_LIFE)
      if (!busy && now - drawn < 1000 / FPS - 4) return
      // the clock runs while the page is on screen, a tenth of a second at most a frame
      const dt = last ? Math.min((now - last) / 1000, 0.1) : 0
      last = now
      drawn = now
      clock += dt
      // the map follows the cursor lazily, never snaps
      const target = mouse.inside && mouse.moved ? 1 : 0
      mouse.on += Math.max(-dt * 0.8, Math.min(dt * 0.8, target - mouse.on))
      const k = 1 - Math.exp(-dt * 2)
      mouse.x += (mouse.toX - mouse.x) * k
      mouse.y += (mouse.toY - mouse.y) * k
      while (taps.length && clock - taps[0].at > TAP_LIFE) taps.shift()
      draw()
    }

    const start = () => {
      cancelAnimationFrame(raf)
      last = 0
      if (still()) draw()
      else if (!document.hidden) raf = requestAnimationFrame(frame)
    }

    const onMove = (e: PointerEvent) => {
      if (e.pointerType !== "mouse") return
      mouse.moved = true
      mouse.inside = true
      mouse.toX = e.clientX / Math.max(1, window.innerWidth)
      mouse.toY = e.clientY / Math.max(1, window.innerHeight)
    }
    const onLeave = () => {
      mouse.inside = false
    }
    const onDown = (e: PointerEvent) => {
      if (still() || !e.isPrimary) return
      taps.push({
        x: e.clientX / Math.max(1, window.innerWidth),
        y: e.clientY / Math.max(1, window.innerHeight),
        at: clock,
      })
      if (taps.length > 4) taps.shift()
    }
    const onLost = (e: Event) => {
      e.preventDefault()
      lost = true
      cancelAnimationFrame(raf)
    }
    // The shader takes the GPU most of a second to compile the first time: it
    // compiles alongside the page (KHR_parallel_shader_compile, where there is
    // one), and the map comes in once it's ready, rather than the page waiting for it.
    const parallel = gl.getExtension("KHR_parallel_shader_compile")
    const load = () => {
      window.clearTimeout(waiting)
      if (!compile(gl, map)) return
      const ready = () => {
        if (parallel && !gl.getProgramParameter(map.program, parallel.COMPLETION_STATUS_KHR)) {
          waiting = window.setTimeout(ready, 50)
          return
        }
        if (!link(gl, map)) return
        lost = false
        resize()
        draw() // the first frame at once, then the clock runs
        start()
      }
      ready()
    }
    const onRestored = () => load()

    const observer = new ResizeObserver(() => {
      resize()
      draw()
    })
    observer.observe(el)
    load()
    window.addEventListener("pointermove", onMove, { passive: true })
    window.addEventListener("pointerdown", onDown, { passive: true })
    document.documentElement.addEventListener("pointerleave", onLeave)
    window.addEventListener("blur", onLeave)
    document.addEventListener("visibilitychange", start)
    motion.addEventListener("change", start)
    el.addEventListener("webglcontextlost", onLost)
    el.addEventListener("webglcontextrestored", onRestored)
    return () => {
      cancelAnimationFrame(raf)
      window.clearTimeout(waiting)
      observer.disconnect()
      window.removeEventListener("pointermove", onMove)
      window.removeEventListener("pointerdown", onDown)
      document.documentElement.removeEventListener("pointerleave", onLeave)
      window.removeEventListener("blur", onLeave)
      document.removeEventListener("visibilitychange", start)
      motion.removeEventListener("change", start)
      el.removeEventListener("webglcontextlost", onLost)
      el.removeEventListener("webglcontextrestored", onRestored)
      for (const sh of map.shaders ?? []) gl.deleteShader(sh)
      gl.deleteProgram(map.program ?? null)
      gl.deleteVertexArray(map.vao ?? null)
    }
  }, [])

  return (
    <canvas
      ref={canvas}
      aria-hidden="true"
      className={cn(
        "pointer-events-none fixed inset-x-0 top-0 -z-10 h-lvh w-full opacity-0 transition-opacity duration-700 data-drawn:opacity-100 motion-reduce:transition-none",
        className
      )}
    />
  )
}

// Renderers that draw on the processor, not a graphics card. A browser
// without one for WebGL (or a headless one, as the stories' tests run in)
// draws with one of these, and even a single frame of the map takes long
// enough there to hold up everything else on the page.
const SOFTWARE = /swiftshader|llvmpipe|softpipe|software|basic render driver/i

function software(gl: WebGL2RenderingContext) {
  const info = gl.getExtension("WEBGL_debug_renderer_info")
  return SOFTWARE.test(String(gl.getParameter(info ? info.UNMASKED_RENDERER_WEBGL : gl.RENDERER)))
}

const ATTRIBUTES: WebGLContextAttributes = {
  alpha: false,
  antialias: false,
  depth: false,
  stencil: false,
  powerPreference: "low-power",
  preserveDrawingBuffer: false,
  failIfMajorPerformanceCaveat: true,
}

const UNIFORMS = ["res", "clock", "lean", "cam", "taps", "keys", "ink", "column", "clouds", "grain"] as const

type Map = {
  program: WebGLProgram
  vao: WebGLVertexArrayObject
  shaders: WebGLShader[]
  u: Record<(typeof UNIFORMS)[number], WebGLUniformLocation | null>
}

/** Starts compiling the map's shaders into `map` (again, after a lost context comes back), asking nothing of them yet. */
function compile(gl: WebGL2RenderingContext, map: Map) {
  const shader = (type: number, source: string) => {
    const s = gl.createShader(type)
    if (!s) return null
    gl.shaderSource(s, source)
    gl.compileShader(s)
    return s
  }
  const vs = shader(gl.VERTEX_SHADER, VERTEX)
  const fs = shader(gl.FRAGMENT_SHADER, FRAGMENT)
  const program = gl.createProgram()
  const vao = gl.createVertexArray()
  if (!vs || !fs || !program || !vao) return false
  gl.attachShader(program, vs)
  gl.attachShader(program, fs)
  gl.linkProgram(program)
  map.program = program
  map.vao = vao
  map.shaders = [vs, fs]
  return true
}

/** Once the shaders are compiled: whether they linked, and the program set up to draw. */
function link(gl: WebGL2RenderingContext, map: Map) {
  const ok = gl.getProgramParameter(map.program, gl.LINK_STATUS)
  if (!ok && import.meta.env.DEV)
    console.warn(
      "Topographic backdrop:",
      ...map.shaders.map((s) => gl.getShaderInfoLog(s)),
      gl.getProgramInfoLog(map.program)
    )
  for (const s of map.shaders) gl.deleteShader(s)
  map.shaders = []
  if (!ok) return false
  for (const name of UNIFORMS) map.u[name] = gl.getUniformLocation(map.program, name)
  // (WebGL's, not a React hook)
  // oxlint-disable-next-line react/rules-of-hooks
  gl.useProgram(map.program)
  gl.uniform3fv(map.u.keys, new Float32Array(BRASS.flat()))
  return true
}
