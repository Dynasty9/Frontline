# Synthetic recording after a storage restart

Source revision: `5db6dfe1c3874d5a90adb481c8c76dba4da497ff`.
Godot 4.7.2 standard Linux; Compatibility renderer on Xvfb/Mesa llvmpipe.

The real game recorded the built-in attack scenario, seed 3, for 12.2 simulation
seconds into six chunks. The recorder exited 0. No user recording or production
credentials were used. An existing exit resource-leak warning remains.

The local fixture ingested those exact emitted JSON chunks through `Replays` and
`BucketStore` into a loopback fake Storage API backed by a temporary JSON object
file. That process exited. A new process reopened the object file with empty
in-memory replay caches, compared all six returned payloads to the originals,
and required a complete manifest before exposing the replay through the normal
matchmaker HTTP routes. All comparisons passed.

The real game then opened that HTTP replay. Playback reached time 8.2 with 39
entities (21 structures, 18 soldiers), and exited 0. The video shows the source
recording followed by playback after the restart; it cannot visually prove the
off-screen restart, concurrent writes, or real Supabase availability. Those are
separate assertions/tests. This fixture implements only the Storage operations
needed for the exercise and is not a substitute for a Supabase integration test.

## Reproduce locally

Use a new writable directory as FIXTURE. Do not point this tool at user recordings.
Set writable XDG data/config/cache directories and DISPLAY for a local renderer.
Record with the standard engine (GODOT is its path):

```sh
"$GODOT" --path . --rendering-method gl_compatibility --audio-driver Dummy --resolution 960x600 -- --scenario=attack --seed=3 --play=0 --record-replay="$FIXTURE/synthetic-attack" --quit-after=12 --no-stun --mood=day --matchmaker=http://127.0.0.1:9 --set=perf:0
node tools/showcase/replay_storage_fixture.mjs ingest "$FIXTURE"
# Start this as a new process after ingestion exits; it binds only to loopback.
node tools/showcase/replay_storage_fixture.mjs serve "$FIXTURE"
```

Open the URL in `FIXTURE/replay-url.txt` with `--replay=URL`,
`--matchmaker=http://127.0.0.1:18974`, and `--quit-after=8`.
The helper uses a literal fixture-only key, `env: {}` and `auth: null`; it never
reads shared credentials, contacts Supabase, changes SQL/settings or deploys.

Capture: FFmpeg x11grab, 960x600, 15 fps, silent VP9. Final edit uses source-video
seconds 120–124 at normal speed followed by restarted-playback seconds 90–150
at 4x, explicitly labeled as accelerated footage (not a change to the player rate). Different camera positions are not a visual comparison
of backend behavior. Raw footage and replay JSON remain local; only the compact
clip and poster are tracked. No performance, simulation-parity or AAA claim.
