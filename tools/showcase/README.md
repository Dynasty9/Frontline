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
the same capture fixture. Add `--capture-set=rain --mood=rain` to check distant rain, town splashes and elevated ground. With `--fixed-fps 30`, `--capture-clip=close` also saves six seconds of full-frame PNGs beside the close still; encode them at 30 fps.

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
