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
| One order | A destination appears on the commander's road view. Track the same five soldiers across the road at shoulder height, with dawn light on their gear and the village ahead. Both cameras record the same order, seed and simulation time. |
| Armour arrives | Keep the squad's left-to-right movement through the cut. From field level, a tank crosses the foreground before the closer gun shot. |
| Into the trench | See people beside the earthworks. Follow the mortar crew with the visible impacts along the trench line. |
| Off the ground | See the helicopter take the weight, then look down past its landing gear at the Humvee turning on the sling. Its shadow stays on the field below. |
| Into the harbour | From the starboard side of one launch, see the other cut across the bow and turn toward shore. From shore, see the squad run clear of the bow while the patrol ship crosses behind. Cut to the ship's bow as a second boat comes alongside. Follow the jet until its load clears the wing. Hold the harbour wide through the rise and fall of the spray. |

The end title uses the menu emblem and type. The score scene draws them on black. The editor blends that frame over the water as the spray falls, leaving room below for captions. The final picture holds the game name and desktop invitation.
