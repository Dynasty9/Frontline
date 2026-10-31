# Battle viewing and recordings

The browser viewer is the Godot client renderer, running without simulation,
player commands, networking presence, rank progress, or result submission.
The same observer reads local recordings and public broadcasts.

## Players

- The host saves battles in `user://replays/`. **Replays** in the desktop menu
  opens a recording folder. A recording is `index.json` and numbered chunk files;
  keep the folder together when sharing it.
- Listed, unlocked battles upload automatically when the matchmaker enables
  recording storage. Unlisted, LAN-only, and password-protected games stay local.
- The site's **Battles → Watch** section lists broadcasts and recordings.
  Completed account reports link to their replay when the host had successfully
  started broadcasting before the battle ended.
- Pause, playback speed, and the scrubber affect only the viewer. The host's
  match continues normally. “Latest” seeks to the newest publicly available moment.
- Each uploaded chunk is withheld for one second after receipt, even if the host
  says the match has ended. Two-second chunks, immediate uploads, and half-second viewer polling aim for roughly 3–5 seconds behind play on a healthy connection. Loading and slow networks can add delay.
- If the host closes the game or loses its connection before uploading everything,
  the public recording can be partial. Returning to the menu lets queued uploads
  finish; local chunks remain available even if the public upload fails.

## Deployment

The existing static website alone cannot serve a Godot viewer. Build the web
service with repository-root context and `Dockerfile.web`; it builds the Godot
Web export and React site together, then serves both with nginx. Keep Railway's
`PORT` setting and set build argument `VITE_MATCHMAKER_URL` for a non-production
matchmaker. The viewer uses WebGL 2, the Compatibility renderer, and no threads.
`/game/viewer.json` identifies the supported recording format and network protocol.
Absent or incompatible builds show an explanation instead of an unusable launch.

Mount a persistent volume on the matchmaker and set `REPLAY_DIR` to its directory
(for example `/data/replays`). Without this setting the API reports recording
disabled. The same single matchmaker instance serves recordings through HTTP;
no WebSocket dependency or account/database migration is needed. Requests and
chunks are bounded; uploads require a public active lobby's host token, then a
separate recording token. Neither token is returned by public read endpoints.

Public storage is limited to 500 recordings, 5 GiB total, 256 MiB per recording,
and four hours per battle. Recordings expire after seven days. Expiration is
applied at startup and when recordings are listed or created. Retention and
capacity are deliberately fixed for this first implementation. Local files are
not automatically deleted; each local recording has the same size/duration cap.

## Format and seeking

Format 1 stores independent checkpoints every two seconds, with ten observation
samples per simulated second between them (static entities update once per second).
The first chunk includes the ground, water, scenery, and initial match settings.
Checkpoints contain entity properties and their existing network state; following
frames contain spawns, removals, property changes, effects, and state updates.
Unchanged scenery records and observer packets are cached in small entity-ID blocks; dirty scenery, active buildings, spawns and removals refresh those blocks. Snapshot timestamps are refreshed for each sample. Completed immutable chunks are serialized and compressed by one worker; only finished files enter the manifest. The next chunk and shutdown join any pending worker, bounding memory without dropping samples.

Each chunk is a bounded, zstd-compressed Godot Variant encoded as base64 in JSON.
Decoding never permits objects or scripts. The viewer checks structure, entity
types, and packet boundaries before handing data to the existing renderer.

Saved replays download and validate every part before playback begins. Loading
progress, the timeline, pause, speed, and camera controls are all inside the game
UI. The viewer keeps compressed parts in memory, so playback and scrubbing need
no further chunk downloads. Live broadcasts continue streaming as new parts arrive.

Seeking reconstructs the observer world from the preceding checkpoint and advances
its state to the target. This also clears transient effects. It can take a few
seconds on a large battlefield; the controls show loading and reject overlapping
seeks. Cosmetic debris and effects that occurred before a seek are not reconstructed.
The camera is independent of the recording. Sequential playback keeps the world
and applies the next chunk without rebuilding it.

Public access is via `GET /replays`, `GET /replays/:id`, and
`GET /replays/:id/chunks/:sequence`. The host uses `POST /replays` with
`X-Lobby-Token`, then `POST /replays/:id/chunks` with the recording bearer token.
Chunk retries are idempotent; conflicting or out-of-order chunks are refused.
Metadata and chunks survive service restarts on the persistent volume.

## Verification is separate

Recordings keep ordered player command attempts, joins and disconnects with their
simulation tick, plus the initial settings and checkpoint RNG states. They do
**not** certify determinism or authenticity, and the API always reports
`verified: false`. State checkpoints are observer checkpoints, not full simulation
saves. A future verifier still needs full deterministic simulation coverage,
version-pinned headless builds, a trusted command source, and state-hash comparison.
The Rust migration and its full-state replay requirements are tracked in
[RUST_SIMULATION.md](RUST_SIMULATION.md). Extracted Rust kernel tests do not
constitute battle verification.

## Checks and local use

From the repository root:

```text
godot --headless --fixed-fps 30 --path . -- --scenario=attack --seed=3 --quit-after=30 --record-replay=build/example
godot --path . -- --replay=build/example
godot --path . -- --replay=https://your-matchmaker/replays/RECORDING_ID
godot --headless --fixed-fps 30 --path . -- --replay-test --no-stun
godot --headless --path . --export-release Web web/public/game/index.html
python .github/scripts/viewer_manifest.py web/public/game
```

Create the export directory first. Then run Vite with `VITE_MATCHMAKER_URL`
pointing to the local matchmaker. The standalone iframe URL is
`/game/index.html?replay=<URL-encoded recording API URL>`.
`tests/replay.test.mjs` checks recording, commands, rewind, forward seek, unit
positions, and malformed input. Matchmaker tests cover authorization, delayed
reads, restart persistence, ordering, retries, and expiry. Website stories cover
available, delayed, unavailable, and expired recordings.
