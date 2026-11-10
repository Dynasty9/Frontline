# Precomputed starting battlefields

Desktop hosts can reuse a complete generated starting battlefield before tick
zero. The same Rust importer, simulation and replay verifier are used for a
cache hit and a freshly generated match. Clients still receive the authoritative
map through the normal socket protocol. Browser generation is unchanged.

This deliberately caches the **exact starting deployment**, not just terrain.
Generation also chooses starting units, ownership, IDs, supply, navigation and
the RNG continuation. The package preserves them together, so reuse cannot
silently change subsequent simulation decisions. Every resolved gameplay option,
player identity/name/team/order, seed, dimensions and mission remains in the key.
Different setups miss safely. Fresh random seeds continue to generate fresh maps.

## Automatic cache

The generator reads bundled packages first, then `user://battlefields`. After a
successful uncached export it writes a package through a uniquely named temporary
file and atomic rename. The application's disposable cache retains at most eight
packages and 2 GiB; oldest writes are evicted, preserving the new entry. Custom
bake directories and bundled packages are not evicted. Cache write failures do
not prevent a match from starting.

The `FLMAP001` envelope contains the complete-input/code key, SHA-256 payload
digest, bounded length and unchanged `FLIN` payload. Length and digest are checked
before a hit is accepted; stale, truncated or corrupt packages fall back to
generation. Rust still performs its full initial-state validation. The envelope
is an integrity check for local build artifacts, not a signature for trusting
third-party downloads. Do not install untrusted packages.

Identity covers GDScript sources, scene/resource sources (including alpine
landform data), project settings, the actual native extension and server
binaries, bundled content and Godot version. Development builds hash source;
exports use a source stamp injected by the editor export plugin. Unstamped exports
skip caching. Rebuilds on another platform or with different native binaries
require their own bake. No replay/build identity checks are relaxed.

`--no-map-cache` bypasses reading and writing for `--local-server` or
`--export-simulation`. `--map-cache-dir=PATH` selects a private directory for
those test modes. Output paths, cache controls and profiling controls do not
affect the key. Unrecognized gameplay options do, conservatively. Nested
dictionary iteration order is preserved because player order affects deployment.

## Bake and export

Build the native runtime first, import Godot, then write a LocalServer config:

```json
{"fixed_seed":3,"map_size":1024,"ai_fill":true,"team":-1,"name":"Commander"}
```

```sh
python tools/bake_maps.py --config build/map.json --output maps/precomputed --godot /path/to/godot
```

The helper generates a package, runs 600 simulation ticks and independently
verifies the recording. It fails on generation errors or verification failure.
Use `--ticks=N` to change the validation duration. Packages are ignored by Git;
they are build artifacts, potentially hundreds of MiB for large maps. Desktop
export presets include `maps/precomputed/*.flmap`. Bake against the exact binaries
being exported, after all source changes. The enabled `addons/map_cache_stamp` plugin computes the source stamp during
every export, including headless CI exports, using the same function as the
generator. There is no manually maintained or build-time stamp to go stale.
The release pipeline does not replace random maps with a fixed catalog or
automatically ship every possible player setup.

Use a fixed seed and the same player setup to reuse a custom battlefield. A
prebaked observer setup is not a substitute for a player-controlled setup. This
avoids introducing a second deployment algorithm that might diverge from the
existing generator. A future reusable terrain-only format would require an
explicit map/deployment split and equivalence tests, not removing inputs from
this cache key.

## Validation and timing

`tests/battlefield-cache.test.mjs` checks input/code invalidation, corruption,
oversized lengths, atomic repair, cache bounds, exact initial bytes and independently
verified replay hashes for uncached, population and two cache-hit starts.

```sh
python tools/bake_maps.py --config build/map.json --output build/map-measurement --benchmark --ticks 600 --godot /path/to/godot
```

Use a fresh output directory. `results.json` retains generator-process wall time,
cache-hit status, payload size/hash and replay verification for each run. This
excludes Rust import and client loading; it is not the time until the battlefield
is visible. With `--local-server --perf-at=... --perf-json=...`, the existing
performance report also contains cumulative `startup_ms.generated`, `server_ready`
and `client_ready`, measured from helper launch. This includes the visual client's
terrain, entity and initial residency preparation, but excludes title/menu time
and the final loading-curtain fade. Do not sum these cumulative values.

GPU uploads, shader warmup, the client's view construction and Rust's validated
import still happen. Caching speeds repeated exact configurations; it does not
make never-before-generated random seeds or all client loading free.

## Measured results (Windows, November 9, 2026)

Godot 4.7.2, i9-11900K / RTX 3090. Other apps and the user's game remained running;
owned measurements ran serially. Results are workload-specific observations.

| Workload / boundary | Uncached | Populate cache | Cache hits |
|---|---:|---:|---:|
| Generated 3072 m, 500 soldiers: generator process | 314.535 s | 307.749 s | 4.857 / 3.663 s |
| Generated 1024 m, 500 soldiers: launch to client-ready | 77.627 s | 83.384 s | 35.835 / 32.995 s |

The large-map initial payload is 282,878,860 bytes (about 270 MiB), containing
14,659 entities. Both independent generations and both hits have identical
SHA-256 initial payloads and identical verified 600-tick initial/final simulation
hashes. No winner had been declared at that tick; this is not an end-of-match
conclusion test. Rust simulation code and replay formats are unchanged.

The rendered test uses High Forward+, safe rendering, 1280x720, focus 0,0, zoom
130, seed 3, 500 soldiers and no vehicles. It measures startup, not FPS: its
one-second performance capture only retrieves the loading-stage counters.
Client world construction still takes 24-29 seconds, and GPU/vegetation work can
continue after the client-ready boundary. Cache hits did not remove that work.
A single uncached control and two warm starts do not establish a universal speedup.

[Raw measurements and replay hashes](performance/precomputed-maps.json).
Reproduce the rendered settings with:

```sh
godot --path . --resolution 1280x720 -- --offscreen --local-server --scenario=stress --stress-generated --map-size=1024 --seed=3 --units=500 --scenery=0 --vehicles=0 --team=-1 --name=Commander --preset=high --perf-at=1 --perf-duration=1 --quit-after=6 --focus=0,0 --zoom=130 --map-cache-dir=build/startup-cache --perf-json=build/startup.json
```

Run once with `--no-map-cache`, once to populate an empty cache directory, and
twice more to reuse it, using a separate report filename each time. Existing
rendered shutdown warnings (eight ObjectDB instances) remain; no script errors
occurred in these captures.

Local validation: eight focused headless regressions passed; Godot import and
Windows release export passed. The exported executable loaded the bundled
20-unit package (`bundled=true`) with exact initial bytes and the same independently
verified 60-tick replay as the editor-generated package. Cache corruption/repair,
code/input invalidation, player order, disabled caching and eviction are covered.
Changelog and presentation audits passed.

The timing captures above were taken at d6f909bb. The export-stamping follow-up
shares the same source hashing algorithm and cache/loading path, and only moves
stamping into the export hook; it does not change generation or simulation.

The final exported-package check deliberately left an all-zero stale stamp on
disk. The export hook injected the current fingerprint, and the executable still
loaded the correct bundled package with exact initial bytes. The two cache-specific
regressions were rerun after moving the stamp into the export hook.
