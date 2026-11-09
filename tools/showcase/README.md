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
| Material impact close-ups | Dirt, stone and metal debris without obscuring fuel smoke | `impacts`: four seconds per material, fixed 30 Hz, normal speed |
| Illumination flares | Parachute descent, wind, sparks and smoke | `flares`: same effect code at night, following camera, fixed 30 Hz |
| Battlefield blast | Earth and dust against real terrain and cover | `blast-close` / `blast-rts`: showroom seed 712, day, fixed 24 Hz |
| Text | Reliability, compatibility, unrecorded sound or unmeasured performance | Short player outcome and original detail |

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
Reject unclear subjects, broken materials, debug overlays and unlabelled speed
changes. Preserve the generated `capture.json` with the catalog's capture record.
Use fixed simulation timing when encoding image sequences so rendering speed
cannot turn an advertised real-time comparison into a time-lapse. New gameplay scenario presets require a reviewed capture before registration.
A current-build demonstration is not automatically a historical comparison.
The controlled-motion fixture has its own fixed 60 Hz integration and 12 fps output.

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
