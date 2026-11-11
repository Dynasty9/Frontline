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
  --takes /tmp/frontline-trailer/takes --label '01 · Squad to harbour' --note 'Describe the outcome you saw on playback.' --at 7.07
```

Open `build/trailer-review/index.html` directly to compare the two latest editions. Choose edition 00 on the left to see the original. Listen to either track and scrub both pictures together. For editions archived with `--at`, the button below the note plays both pictures from the changed shot. The gallery is local. To share it, copy the entire gallery folder. Each edition keeps its recipe. Passing `--takes` also preserves the recording date, game revision and launch arguments for each take.

The edit opens on a readable action at squad scale, expands through infantry and armour, and gives the final aircraft approach and water impacts time to play as one event. Check the first ten seconds muted and the final approach with sound. These checks follow [Valve’s gameplay trailer guidance](https://partner.steamgames.com/doc/store/trailer) and [Derek Lieu’s line of rising action](https://www.derek-lieu.com/blog/2018/9/16/the-trailer-line-of-rising-action).

For a mix revision, keep the cut points fixed and compare editions with the audio selector. The reel's `score` names a separate take mixed continuously under the native effects. Its Godot scene records the game's battle cue and victory sting with a fixed musical seed. Edit the scene to retime the crescendo, or edit the gain in the recipe to rebalance the music against the effects.

## Picture sequence

| Beat | What the viewer can follow with the sound off |
| --- | --- |
| One order | The Sky Hook objective appears above five selected soldiers. When the destination ring lands, cut to the same squad at ground level. The Mohawk lifts off behind them. Both cameras record the same order, seed and simulation time. The same aircraft crosses the river later. |
| Armour arrives | Two Abrams come through the village at dawn in the Bridgehead mission. The lead tank crosses the roadside camera toward the right as the second follows under the mountain skyline. Cut to the closer gun on the same side. |
| Into the trench | See riflemen cross the timber trench beside a tracked vehicle. Look across the mortar pit with the tube on the left. Follow the specialist over the middle sandbag and down to a knee, then cut overhead as the rounds land along the line. The two field-camera scenes store their positions and travel times in metres and simulation seconds. |
| Off the ground | Watch the Mohawk fly overhead carrying the Nyx. Cut on its passage to the cargo door, where the same bridge sweeps beneath the tracked vehicle, then follow the water into the RHIB shot. |
| Into the harbour | Look past the coxswain’s right shoulder as the other launch crosses the bow and turns toward shore. Move down to shoulder height on the sand. The squad runs toward the left foreground while the patrol ship enters from the right on the same heading. Cut to the ship's bow as a second boat approaches. On the next simulation frame, look down from the bridge roof as it passes the port rail. Follow the jet until its load clears the wing. Cut down to the boat’s playable Stern quarter view. The mount engages at mission second eight, after the jet pass is underway, so the jet and boat takes show the same event. Keep the hull in sight as the spray rises above its cabin and falls. |

The end title uses the menu emblem and type. The score scene draws them on black. The editor blends that frame over the water as the spray falls, leaving room below for captions. The final picture holds the game name and desktop invitation.
