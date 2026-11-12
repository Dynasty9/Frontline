import { useRef, useState } from "react"
import { useSearchParams } from "react-router"
import archive from "@/lib/trailer-editions.json"
import { ArrowDownIcon, ArrowRightIcon, FilmStripIcon, PlayIcon } from "@phosphor-icons/react"
import { usePageTitle } from "@/hooks/use-page-title"
import comparison from "../../../tools/showcase/trailer-review/viewer.html?raw"
import "./cutting-room.css"

type Edition = {
  id: string
  label: string
  note: string
  frames: number
  file: string
  poster: string
  change_frame?: number
  captions?: string
  recipe?: string
  cuts?: number
}

const phases = [
  { name: "All edits", first: -1, last: Infinity },
  { name: "First assembly", first: -1, last: 8 },
  { name: "On board", first: 9, last: 16 },
  { name: "Closer to the action", first: 17, last: 25 },
  { name: "Building the finale", first: 26, last: 30 },
]

const decisions = [
  {
    id: "13",
    at: 9.97,
    title: "Follow the cargo",
    text: "The bridge passes under the load in both shots. That landmark lets the camera move from the bridge deck to the cargo door without losing the helicopter.",
  },
  {
    id: "26",
    at: 20.73,
    title: "Give the strike an outcome",
    text: "The early harbour sequence ended in spray. This cut introduces the pickup on the quay and stays long enough to see what happens to it.",
  },
  {
    id: "30",
    at: 20.63,
    title: "Hear the cut change",
    text: "From under the wing, each release has a short clack. Down on the quay, the engine recedes and falling air rises over the music.",
  },
]

const title = (e: Edition) => e.label.replace(/^\d+ · /, "")
const stamp = (s: number) => `${Math.floor(s / 60)}:${(s % 60).toFixed(1).padStart(4, "0")}`

const cameraTests = [
  {
    file: "wide",
    label: "Wide profile",
    verdict:
      "The ridge and the aircraft both read clearly. The dark payload passes across the mountain and is easy to miss.",
  },
  {
    file: "quarter",
    label: "Front quarter",
    verdict:
      "The whole aircraft stays in silhouette. The separated bombs quickly leave the frame and the ground below draws the eye.",
  },
  {
    file: "belly",
    label: "Under the wing",
    verdict:
      "This was the final angle. The bright sky separates each falling shape, and the close microphone makes the release audible before the cut to the quay.",
  },
]

function CameraTests() {
  const [choice, setChoice] = useState(0)
  const [revealed, setRevealed] = useState(false)
  const test = cameraTests[choice]
  const base = "/media/edits/cameras/" + test.file
  return (
    <section className="cut-section cut-lab" aria-labelledby="camera-test">
      <div>
        <p className="cut-kicker">Camera test</p>
        <h2 id="camera-test">Which angle would you cut to?</h2>
        <p className="cut-summary">
          Three recordings of the same 2.2 seconds. Choose the view that makes the release easiest to follow.
        </p>
        <div className="cut-filters" aria-label="Choose a camera">
          {cameraTests.map((camera, i) => (
            <button key={camera.file} aria-pressed={i === choice} onClick={() => setChoice(i)}>
              {camera.label}
            </button>
          ))}
        </div>
        <button className="cut-more" aria-expanded={revealed} onClick={() => setRevealed(!revealed)}>
          {revealed ? "Hide the editor’s notes" : "Reveal the editor’s choice"}
        </button>
        {revealed && (
          <output className="cut-verdict">
            <strong>Under the wing made the cut.</strong> {test.verdict}
          </output>
        )}
      </div>
      <video
        key={test.file}
        controls
        preload="none"
        playsInline
        poster={base + ".jpg"}
        src={base + ".mp4"}
        aria-label={test.label + " camera test"}
      >
        <track kind="captions" label="English" srcLang="en" src="/media/edits/cameras/release.vtt" />
      </video>
    </section>
  )
}

function RidgeScreening() {
  const [latest, setLatest] = useState(true)
  const player = useRef<HTMLVideoElement>(null)
  const resume = useRef<{ at: number; playing: boolean } | null>(null)
  function swap(next: boolean) {
    const video = player.current
    if (!video || next === latest) return
    resume.current = { at: video.currentTime, playing: !video.paused && !video.ended }
    setLatest(next)
  }
  const base = "/media/edits/films/ridge-duel"
  return (
    <section id="ridge-duel" className="cut-section cut-lab" aria-labelledby="ridge-title">
      <div>
        <p className="cut-kicker">Full-length tank film</p>
        <h2 id="ridge-title">Two tanks, two ridges.</h2>
        <p className="cut-summary">
          Ride with the Abrams and T-55A across the valley. Both recordings follow the same seeded encounter. Switch
          versions to stay at the same moment.
        </p>
        <p className="cut-verdict">
          {latest ? "New capture · 1600 × 900" : "Earlier capture · 1280 × 720"} · 30 fps · stereo
        </p>
        <div className="cut-filters" aria-label="Choose a ridge recording">
          <button aria-pressed={latest} onClick={() => swap(true)}>
            New recording
          </button>
          <button aria-pressed={!latest} onClick={() => swap(false)}>
            Earlier recording
          </button>
        </div>
        <a
          className="cut-link"
          href="https://github.com/Dynasty9/Frontline/blob/2ab72eae2467c4648b8bf26333ca2f88744c8c06/tools/showcase/README.md#record-the-two-ridge-abrams-film"
        >
          Recording recipe · seed 712 <ArrowRightIcon />
        </a>
      </div>
      <video
        key={String(latest)}
        ref={player}
        controls
        playsInline
        preload="metadata"
        poster={base + (latest ? "-2026-11-11.jpg" : ".jpg")}
        src={base + (latest ? "-2026-11-11.mp4" : ".mp4")}
        aria-label={latest ? "Ridge duel, new recording" : "Ridge duel, earlier recording"}
        onLoadedMetadata={(event) => {
          const saved = resume.current
          if (!saved) return
          const video = event.currentTarget
          video.currentTime = Math.min(saved.at, video.duration)
          resume.current = null
          if (saved.playing) void video.play().catch(() => {})
        }}
      >
        <track kind="captions" label="English" srcLang="en" src={base + ".vtt"} />
      </video>
    </section>
  )
}

export default function CuttingRoom() {
  usePageTitle("The cutting room")
  return <ScreeningRoom editions={archive} />
}

function ScreeningRoom({ editions }: { editions: Edition[] }) {
  const [params, setParams] = useSearchParams()
  const ix = editions.findIndex((e) => e.id === params.get("edit"))
  const index = ix < 0 ? editions.length - 1 : ix
  const edit = editions[index]
  const comparing = params.get("view") === "compare"
  const at = Math.max(0, Math.min(Number(params.get("at")) || 0, (edit.frames - 1) / 30))
  const player = useRef<HTMLVideoElement>(null)
  const screen = useRef<HTMLDivElement>(null)
  const [phase, setPhase] = useState(0)
  const [started, setStarted] = useState(false)
  const [playError, setPlayError] = useState(false)
  const phaseEdits = editions
    .filter((e) => {
      const n = e.id === "published" ? -1 : Number(e.id)
      return n >= phases[phase].first && n <= phases[phase].last
    })
    .toReversed()
  const prior = Math.max(0, index - 1)
  const comparisonHtml = comparing
    ? comparison
        .replace('id="versions"', `id="versions" data-left="${prior}" data-right="${index}"`)
        .replace("__VERSIONS__", () => JSON.stringify(editions).replaceAll("<", "\\u003c"))
    : ""
  function select(id: string, seconds = 0, compare = false, scroll = true) {
    const next = new URLSearchParams({ edit: id })
    if (seconds) next.set("at", String(seconds))
    if (compare) next.set("view", "compare")
    setParams(next, { preventScrollReset: true })
    setStarted(false)
    setPlayError(false)
    if (id === edit.id && player.current && !compare) {
      player.current.pause()
      player.current.currentTime = seconds
    }
    if (scroll) screen.current?.scrollIntoView({ block: "start" })
  }
  function play() {
    void player.current?.play().catch(() => setPlayError(true))
  }
  return (
    <article className="cut-room">
      <header className="cut-heading">
        <div>
          <p className="cut-kicker">
            Frontline <span>/</span> Production journal
          </p>
          <h1>
            The cutting room<span>.</span>
          </h1>
        </div>
        <div className="cut-actions">
          <a className="cut-link" href="#ridge-duel">
            Tank film <ArrowDownIcon />
          </a>
          <a className="cut-link" href="#edit-archive">
            Browse the edits <ArrowDownIcon />
          </a>
        </div>
      </header>
      <div className="cut-screen" ref={screen}>
        <div className="cut-screen-bar">
          <span>
            <i /> Screening room
          </span>
          <span>
            {edit.id === "published" ? "Original release" : `Edition ${edit.id}`} &nbsp; / &nbsp;{" "}
            {stamp(edit.frames / 30)}
          </span>
        </div>
        {comparing ? (
          <iframe
            sandbox="allow-scripts"
            title="Synchronized edition comparison"
            className="cut-compare"
            srcDoc={comparisonHtml}
          />
        ) : (
          <div className="cut-player">
            <video
              key={edit.file}
              ref={player}
              controls
              playsInline
              preload="none"
              poster={edit.poster}
              src={edit.file}
              aria-label={title(edit)}
              onPlay={() => {
                setStarted(true)
                setPlayError(false)
              }}
              onError={() => setPlayError(true)}
              onLoadedMetadata={(e) => {
                e.currentTarget.currentTime = at
              }}
            >
              <track kind="captions" srcLang="en" label="English" src={edit.captions} />
            </video>
            {!started && !playError && (
              <button className="cut-play" onClick={play} aria-label={`Play ${title(edit)}`}>
                <PlayIcon weight="fill" />
              </button>
            )}
            {playError && (
              <output className="cut-error">
                Playback unavailable. <a href={edit.file}>Open the recording</a>
              </output>
            )}
          </div>
        )}
        <div className="cut-notes">
          <div>
            <p className="cut-kicker">{comparing ? "Comparison" : "Selected cut"}</p>
            <h2>{title(edit)}</h2>
          </div>
          <div>
            <p>{edit.note}</p>
            <div className="cut-actions">
              <button onClick={() => select(edit.id, 0, !comparing, false)}>
                {comparing ? "Single screening" : "Compare editions"}
              </button>
              {edit.change_frame !== undefined && !comparing && (
                <button
                  onClick={() => {
                    select(edit.id, edit.change_frame! / 30, false, false)
                    play()
                  }}
                >
                  Play the change · {stamp(edit.change_frame / 30)}
                </button>
              )}
              {edit.recipe && (
                <a href={edit.recipe} download>
                  Shot recipe ↓
                </a>
              )}
            </div>
          </div>
        </div>
      </div>
      <RidgeScreening />
      <section className="cut-section" aria-labelledby="decisions">
        <p className="cut-kicker">Editor’s assessment</p>
        <h2 id="decisions">Three decisions you can see.</h2>
        <p className="cut-summary cut-result">
          In 13 hours and 24 minutes, the edit grew from a {stamp(editions.find((e) => e.id === "00")!.frames / 30)}{" "}
          opening assembly to a {stamp(editions.at(-1)!.frames / 30)} trailer with {editions.at(-1)!.cuts} cuts. The
          extra screen time establishes the quay before impact and gives the finale room to resolve. Audience response
          is still unmeasured.
        </p>
        <div className="cut-studies">
          {decisions.map((d) => {
            const e = editions.find((v) => v.id === d.id)
            return (
              e && (
                <button key={d.id} onClick={() => select(d.id, d.at)}>
                  <div className="cut-still">
                    <img loading="lazy" src={e.poster} alt="" />
                    <span>
                      EDIT {d.id} &nbsp; / &nbsp; {stamp(d.at)}
                    </span>
                  </div>
                  <h3>
                    {d.title} <ArrowRightIcon />
                  </h3>
                  <p>{d.text}</p>
                </button>
              )
            )
          })}
        </div>
        <p className="cut-assessment">
          <strong>What still needs room</strong> The final cut spends less than a second under the wing. The release
          reads at full speed, but the quay and pickup are easier to place on a second viewing. The last wide shot shows
          the scale of the barrage better than individual soldiers.
        </p>
      </section>
      <CameraTests />
      <section className="cut-section" id="edit-archive">
        <p className="cut-kicker">
          <FilmStripIcon /> Film archive
        </p>
        <h2>Milestone cuts, in sequence.</h2>
        <p className="cut-summary">
          {editions.length - 1} selected editions and the previously published trailer. Pick a cut to screen it or
          compare it with an earlier edit.
        </p>
        <div className="cut-filters" aria-label="Filter editions">
          {phases.map((p, i) => (
            <button key={p.name} aria-pressed={phase === i} onClick={() => setPhase(i)}>
              {p.name}
            </button>
          ))}
        </div>
        <div className="cut-grid">
          {phaseEdits.map((e) => (
            <button
              key={e.id}
              className={e.id === edit.id ? "selected" : ""}
              aria-pressed={edit.id === e.id}
              onClick={() => select(e.id)}
            >
              <div className="cut-still">
                <img loading="lazy" src={e.poster} alt="" />
                <span>{stamp(e.frames / 30)}</span>
              </div>
              <small>{e.id === "published" ? "Previously published" : `Edition ${e.id}`}</small>
              <h3>{title(e)}</h3>
            </button>
          ))}
        </div>
      </section>
      <section className="cut-section" aria-labelledby="other-films">
        <p className="cut-kicker">Companion films</p>
        <h2 id="other-films">Stay with the scene.</h2>
        <div className="cut-studies">
          {[
            { title: "The vehicle loop", length: "0:20", film: "/media/vehicles.webm", poster: "/media/vehicles.jpg" },
            {
              title: "Listen to the harbour pass",
              length: "0:12",
              film: "/media/edits/films/harbour.webm",
              poster: "/media/edits/films/harbour.jpg",
            },
          ].map(({ title: filmTitle, length, film, poster }) => (
            <a key={film} href={film}>
              <div className="cut-still">
                <img loading="lazy" src={poster} alt="" />
                <span>{length}</span>
              </div>
              <h3>
                {filmTitle} <ArrowRightIcon />
              </h3>
            </a>
          ))}
        </div>
      </section>
      <details className="cut-method">
        <summary>How the recordings were made</summary>
        <p>
          Each scene runs in the game with a saved mission, seed and camera. Godot records native frames and stereo
          sound on a hidden Mac render surface. We review the pictures muted, listen again for timing and perspective,
          then save the edit and its recipe. The older cuts here are smaller screening copies.
        </p>
        <p>
          Download a numbered cut’s shot recipe to replay its setup. A new run can vary in particles and cosmetic
          motion. The archived video preserves the original performance.
        </p>
      </details>
    </article>
  )
}
