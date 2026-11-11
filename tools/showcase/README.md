# Present changes so players can understand them

Read the [presentation skill](../../.agents/skills/changelog-presentation/SKILL.md)
when authoring changelog evidence. Choose the medium before recording. A clear
text explanation is preferable to an irrelevant image, silent audio demo or
invented benchmark. The website and generated history show one outcome and one
lead artifact; original notes and supporting media remain under **Explore this change**.

## Reusable stages

| Stage | Use | Inputs |
| --- | --- | --- |
| Native media | Website changelog; source images with HTML captions | Shared shadcn Card, Button, Badge and Dialog |
| Archive plate | Standalone exports only, not embedded website cards | Title, takeaway, source image, attribution |
| Archive pair | A genuine, matched before/after view | Explicitly reviewed pair, same subject and conditions |
| Controlled motion | Traverse, propulsion and muzzle geometry | `tests/fixtures/vehicle-motion-clips.tscn`; matched main/PR recordings |
| Controlled capture presets | Tanks, boats and aircraft | `stages.json`: fixture, duration, simulation rate and cue |
| Armament effects | Grenade, HE, fuel, tracer and impact timing | `armaments`: real effect pools, seed 712, 10 m ground marks, fixed 30 Hz |
| Audible explosions | Separate grenade, HE and fuel reports | `explosions`: real explosion events at 1, 5 and 9 seconds; use `--write-movie` for audio |
| Material impact close-ups | Dirt, stone and metal debris without obscuring fuel smoke | `impacts`: four seconds per material, fixed 30 Hz, normal speed |
| Illumination flares | Parachute descent, wind, sparks and smoke | `flares`: same effect code at night, following camera, fixed 30 Hz |
| Battlefield effects reel | All armaments over real terrain, followed by a night flare | `battlefield-effects`: 28 seconds, showroom seed 712, fixed 24 Hz, Forward+ |
| Battlefield blast | Earth and dust against real terrain and cover | `blast-close` / `blast-rts`: showroom seed 712, day, fixed 24 Hz |
| Cloud intersections | Fuel inside tank armor and HE against stone cover | `blast-cover`: two four-second shots, showroom seed 712, fixed 24 Hz |
| Ground damage and blast timing | Immediate flash, lighter dust and actual crater aftermath | `blast-ground`: two six-second HE shots, open ground and stone cover, fixed 24 Hz |
| Text | Reliability, compatibility, unrecorded sound or unmeasured performance | Short player outcome and original detail |
| Vehicle surfaces | Fixed-light roster sheets, close-ups and material swatches | `vehicle-surfaces.tscn`; `--surface-out`, `--surface-kinds`, `--surface-team`, `--surface-single`, `--surface-swatches`, `--surface-offset` |

The website uses the main site’s Signal tokens and shadcn/Radix components.
Do not embed a branded presentation frame inside the changelog layout: it duplicates
headings and makes the evidence too small. Source media, HTML captions and thin rules
provide the presentation. Archive plates are opt-in standalone exports.

Archive stages use HTML/CSS to compose the original evidence without retouching it.
Images are contained, not cropped. The render checks text overflow and loads the
project fonts. Do not infer a before/after pair from arbitrary words in captions:
“after-action report” is a screen name, not evidence of an after state. Different
map sizes, populations or machines are not controlled performance comparisons.

```sh
# npm ci and npx playwright install chromium in web/ first
node tools/showcase/render-archive.mjs              # registered standalone exports (none by default)
node tools/showcase/render-archive.mjs fog-of-war   # optional entry-path filter
python3 tools/showcase/audit.py
```

For a controlled motion stage, set `GODOT` and `FFMPEG` (or put them on PATH), then:

```sh
python3 tools/showcase/capture.py boats --output /absolute/scratch/boats
```

Inspect the capture log and beginning/action/end frames before keeping a clip.
To repeat the low sandbag shot, pass `--clip=blast-sandbag` to `blast-world-clips.tscn`.
For synchronized sound, run the `armament-effects-clips.tscn` fixture with
`--fixed-fps 30 --write-movie /absolute/scratch/explosions.avi` before `--`, and
`--clip=explosions` after it. Encode the AVI with its audio track retained.
The PNG sequence from `capture.py` is silent and cannot demonstrate sound.
Reject unclear subjects, broken materials, debug overlays and unlabelled speed
changes. Preserve the generated `capture.json` with the catalog's capture record.
Use fixed simulation timing when encoding image sequences so rendering speed
cannot turn an advertised real-time comparison into a time-lapse. New gameplay scenario presets require a reviewed capture before registration.
A current-build demonstration is not automatically a historical comparison.
The controlled-motion fixture has its own fixed 60 Hz integration and 12 fps output.

## Generated environment views

`tests/fixtures/environment-views.gd` loads the real battlefield once, holds its simulation at
two seconds, then captures the highest playable ridge close and wide, the hillside forest,
and the whole valley. It records each camera in a JSON sidecar. Use the same fixture on the
before and after revisions; differences in source revision must be recorded in the catalog.

```sh
godot --path . --resolution 1600x900 --script tests/fixtures/environment-views.gd -- --aivai --seed=3 --offscreen --nohud --set=perf:0 --preset=high --mood=day --focus=0,0 --capture-prefix=build/terrain/review
```

Add `--capture-set=town` for street detail, the town entrance, an overview and a
residential driveway. `--capture-set=foliage` frames the same broadleaf tree from
both sides and at stand distance, with wind held still. Captures wait for scenery
residency and batching to settle. `--capture-set=river-boundary` frames seed 3's
northern river crossing close up and across the valley. Both revisions must use
the same capture fixture. `--capture-set=coast --mood=night` checks the sky and reflected cloud lighting over the sea.
Add `--capture-set=rain --mood=rain` to check distant rain, town splashes and elevated ground. With `--fixed-fps 30`, `--capture-clip=close` also saves six seconds of full-frame PNGs beside the close still; encode them at 30 fps.
Use `--capture-set=shoreline` for the beach beside seed 3's coastal town, with
near-ground and waterline views. `--fixed-fps 30 --capture-clip=waterline` saves
six seconds of rolling surf. Keep the same fixture on both shader revisions so
wave phase, camera and scenery warmup match; record any resource-pack overrides.

The camera uses the normal terrain clearance, so a low requested zoom may raise the lens
above a neighbouring ridge. This is a visual review stage, not a performance benchmark.

## Inventory and release process

`catalog.json` records every entry's medium, stage, rationale and evidence source.
Archived sources are hashed so an asset change prompts a presentation review.
Register new entries as part of the PR; text-only entries still state why text is
sufficient. `audit.py` runs in changelog CI and follows unreleased entries when the
release process files them into a version directory. It checks coverage, assets
and provenance; it does not replace human visual review.

The historical refresh keeps all 87 entries' original detail and release metadata.
New summaries are an editorial overview, not a rewrite of which features shipped
when. Original stills stay in the expandable gallery. Existing clips retain their
“recorded in the current build” attribution. Audio/performance changes with no
recorded evidence stay textual rather than acquiring a misleading silent clip or
unmeasured chart.

After an explicitly requested history refresh, rebuild the derived outputs:

```sh
python3 .github/scripts/changelog.py build
python3 .github/scripts/changelog.py check
python3 tools/showcase/audit.py
python3 -m unittest discover -s .github/scripts -p 'test_changelog.py'
```

Normal feature work adds an unreleased entry; it does not edit release versions,
dates or historical claims. Preview the website at desktop and phone widths,
check keyboard disclosure, media controls, reduced motion and source-image zoom.

The armament stages run their engine clock at 30 Hz as well as recording at 30 fps.
They are controlled visual demonstrations, not performance benchmarks or a blast
physics reference. To render a matched historical comparison, use the same fixture
and `--legacy-effects` against the source revision; record that revision and the
fixture revision separately. Capture both sides with the same renderer.
`capture.py --renderer forward_plus` checks the desktop path; Compatibility is
the default. `--legacy-effects` selects the historical two-argument explosion API.
In the armament and battlefield fixtures it also holds shown legacy rig timestamps:
slow offline image readback must not let the old wall-clock pool cleanup truncate
particle programs advancing at fixed simulation Hz. The original particle
lifetimes remain intact. This capture-only timing control is recorded explicitly
in `capture.json`; it is not a change to the baseline game's effect code.
The range fixture also accepts `--night`, `--elevation=75` and `--quality=0` for
lighting, steep-camera and reduced-effects checks. Record those arguments with
any retained evidence.

The `impacts` stage uses a dedicated close camera and visits three separated target points.
The refreshed `flares` stage uses controlled moonlight and a closer following camera so
cloth and suspension lines remain legible. These are presentation-only settings; they
do not brighten the in-game night or enlarge the effect geometry.

The `battlefield-effects` stage keeps the real ground, vegetation, cover and vehicles
in view for every shot. It cuts between grenade (0 s), HE (4 s), fuel (9 s), dirt
(14 s), stone (16 s), metal (18 s) and the night flare (20 s; closer at 23 s).
It stages visual events without combat damage and uses ordinary effect sizes and
simulation speed. Capture it with `--renderer forward_plus`; the stage records
its camera/event script revision and uses constrained-quality VP9 to keep the
complete reel inside the changelog media limit. For composition checks only, the
fixture accepts `--preview` with engine `--fixed-fps 12` at a smaller viewport;
release evidence uses the registered 24 Hz preset.

`blast-cover` uses the same battlefield fixture for closer intersection checks.
For a matched shader-only comparison, the fixture accepts `--cloud-shader=/absolute/path/to/historical.gdshader`.
Record the historical shader's revision and hash, and the current fixture revision;
this is a controlled shader comparison, not a full historical build.

Battlefield blast stages now perform the terrain stamp normally called by Combat,
in addition to the visual event. They still do not damage entities. The full reel
also uploads terrain updates while its atmosphere clock is paused. `blast-ground`
holds the crater after the dust clears and moves closer to the open-ground bowl;
its `ground.json` records the resulting depths and fails if deformation is missing.
Historical captures made before this fixture correction contain only visual events.

If a battlefield reel is interrupted, the fixture can replay its fixed-step
schedule without rasterization using `--resume-frame=384` (or 192 with the 12 Hz
preview). Only the cut to the fresh stone-impact shot at 16 seconds is supported:
GPU particle history from skipped shots is not reconstructed. Preserve frames
before the cut, record the resumed command/ref separately, and validate the
assembled 672-frame reel. Never present a resumed segment as a separately matched
historical capture.

## Native environment motion

Use `environment-motion.gd` for a reproducible, current-PR camera demonstration.
It records two four-second views for `stones`, `shore` and `town`, or three views
for `environment`. The simulation is held at two seconds; camera, wind and water
remain animated. This is not a combat demonstration or a performance benchmark.
The normal camera clearance remains active. Inspect each view before publishing.

```sh
godot --path . --fixed-fps 30 --resolution 1280x720 --script tools/showcase/environment-motion.gd -- --aivai --seed=3 --offscreen --nohud --set=perf:0 --preset=high --mood=day --motion-stage=stones --motion-output=build/media-review
# Set FFMPEG if it is not on PATH; SHOWCASE_FONT can select a local TrueType font.
python tools/showcase/encode-environment-motion.py --entry realism-08-fractured-stones --source-ref <rendering-commit>
```

The encoder adds a 48-pixel label above the untouched native frame, writes a
seekable silent VP9 WebM, a JPEG poster, and a capture/provenance JSON sidecar.
Keep matched historical stills as comparisons; do not call the current-PR tour
before/after footage. Inspect the encoded opening, middle and closing frames and
run the changelog and presentation checks before committing media.
