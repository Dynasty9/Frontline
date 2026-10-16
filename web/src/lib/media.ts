// The footage on the page was recorded in the game itself (Godot's movie
// writer, off-screen), then cut and encoded for the web: /media/NAME.mp4,
// with its first frame as /media/NAME.jpg for the poster.

export const media = (name: string, ext: "mp4" | "jpg") => `/media/${name}.${ext}`

/** Seconds as a camera's timecode, MM:SS:FF at 30 frames a second. */
export function timecode(t: number) {
  const s = Math.floor(t)
  const two = (n: number) => String(n).padStart(2, "0")
  return `${two(Math.floor(s / 60))}:${two(s % 60)}:${two(Math.floor((t - s) * 30))}`
}

/** The visitor's browser has asked sites to go easy on data (Data Saver): show stills, not footage. */
export function saveData() {
  const nav = navigator as Navigator & { connection?: { saveData?: boolean } }
  return Boolean(nav.connection?.saveData)
}
