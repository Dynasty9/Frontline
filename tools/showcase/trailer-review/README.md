# Comparing Frontline trailers

New editions run exactly 24 seconds (720 frames at 30 fps). Editions 00–03 retain their original 25.5-second running time. The shared timeline ends with the shorter cut. Keep the original homepage reel as edition 00. Every 30 minutes, review the encoded pictures muted with Video Tool, choose a specific improvement, and capture or recut it. Check the mix after the pictures work. Archive the cut with a note about the change and any moment that still needs work.

From the repository root:

```sh
# Record every required shot from this checkout and assemble the trailer.
python3 .agents/skills/website-footage/scripts/record.py --render reel --work /tmp/frontline-trailer

# When only the edit changed, reuse those recordings.
python3 .agents/skills/website-footage/scripts/build.py reel --work /tmp/frontline-trailer

# Save the reviewed cut, captions and capture/edit recipe in build/trailer-review.
python3 tools/showcase/trailer-review/archive.py /tmp/frontline-trailer/build/reel.mp4 \
  --takes /tmp/frontline-trailer/takes --label '01 · Squad to harbour' --note 'Describe the outcome you saw on playback.'
```

Open `build/trailer-review/index.html` directly. Pick two editions, listen to either track and scrub both pictures together. The gallery is local. To share it, copy the entire gallery folder. Each edition keeps its recipe. Passing `--takes` also preserves the recording date, game revision and launch arguments for each take.

The edit opens on a readable action at squad scale, expands through infantry and armour, and gives the final aircraft approach and water impacts time to play as one event. Check the first ten seconds muted and the final approach with sound. These checks follow [Valve’s gameplay trailer guidance](https://partner.steamgames.com/doc/store/trailer) and [Derek Lieu’s line of rising action](https://www.derek-lieu.com/blog/2018/9/16/the-trailer-line-of-rising-action).

For a mix revision, keep the cut points fixed and compare editions with the audio selector. The reel's `score` names a separate take mixed continuously under the native effects. Its Godot scene records the game's battle cue and victory sting with a fixed musical seed. Edit the scene to retime the crescendo, or edit the gain in the recipe to rebalance the music against the effects.

## Picture sequence

| Beat | What the viewer can follow with the sound off |
| --- | --- |
| One order | A destination appears on the commander's road view. Cut to the same five soldiers crossing it at shoulder height. Both cameras record the same order, seed and simulation time. |
| Armour arrives | Read the formation first, then cut close enough to see one moving gun. |
| Into the trench | See people beside the earthworks before the overhead view reveals the whole line. Follow the mortar crew with the visible impacts. |
| Off the ground | Look across the cockpit and down the sling. Hold until daylight separates the Humvee's wheels from its shadow. |
| Into the harbour | Follow the launch from its stern quarter through the turn. The patrol ship and jet share its mountain skyline. Return to the water in time to see the impacts spread. |
