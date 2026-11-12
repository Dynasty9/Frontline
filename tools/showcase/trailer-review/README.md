# Comparing Frontline trailers

The first 24-second edits and the original 25.5-second editions retain their running times. Extended cuts play to the end while the shorter comparison holds its last frame. Edition 00 preserves the homepage cut at the start of the 24-hour run. The viewer also includes the 32.9-second reel published before this series when its Git blob is available locally. Every 30 minutes, review the encoded pictures muted with Video Tool, choose a specific improvement, and capture or recut it. Check the mix after the pictures work. Archive the cut with a note about the change and any moment that still needs work.

From the repository root:

```sh
# Record every required shot from this checkout and assemble the trailer.
python3 .agents/skills/website-footage/scripts/record.py --render reel --work /tmp/frontline-trailer

# To rebuild an archived edit, pass its .json file with --recipe to either command.
# When only the edit changed, reuse those recordings.
python3 .agents/skills/website-footage/scripts/build.py reel --work /tmp/frontline-trailer

# Save the reviewed cut, captions and capture/edit recipe in build/trailer-review.
python3 tools/showcase/trailer-review/archive.py /tmp/frontline-trailer/build/reel.mp4 \
  --takes /tmp/frontline-trailer/takes --label '01 · Squad to harbour' --note 'Describe the outcome you saw on playback.' --at 7.07
```

Open `build/trailer-review/index.html` directly to compare the two latest editions. Use Previous edit and Next edit to move through neighboring pairs. Both playheads land at the changed shot, or at the start for early editions without a marker. Choose “Published homepage” on the left to compare with the earlier release, or edition 00 to compare with the first cut from this run. Listen to either track and scrub both pictures together. For editions archived with `--at`, the button below the note plays both pictures from the changed shot. The gallery is local. To share it, copy the entire gallery folder. Each edition keeps its recipe. Passing `--takes` also preserves the recording date, game revision and launch arguments for each take.

The edit opens on a readable action at squad scale, expands through infantry and armour, and gives the final aircraft approach and the truck’s destruction time to play as one event. Check the first ten seconds muted and the final approach with sound. These checks follow [Valve’s gameplay trailer guidance](https://partner.steamgames.com/doc/store/trailer) and [Derek Lieu’s line of rising action](https://www.derek-lieu.com/blog/2018/9/16/the-trailer-line-of-rising-action).

For a mix revision, keep the cut points fixed and compare editions with the audio selector. On a hard picture cut, `audio_bridge_frames` carries the previous take’s audio under the new camera and fades it out over that many frames. Leave enough recorded audio beyond the previous cut. The reel's `score` names a separate take mixed continuously under the native effects. Its Godot scene records the game's battle cue and victory sting with a fixed musical seed. Edit the scene to retime the crescendo, or edit the gain in the recipe to rebalance the music against the effects.

## Picture sequence

| Beat | What the viewer can follow with the sound off |
| --- | --- |
| One order | The player selects the Mohawk and clicks the Nyx in the Sky Hook mission. Hold just long enough to see the ring around the cargo and the helicopter clear the pad. Cut to the squad at eye level, then show the same type of cargo lifting on its cables. |
| Off the ground | Track the Mohawk from the bridge rail. Hold its broadside and the suspended Nyx in frame together, then cut to the cargo door, where the camera follows the swinging hull as the same bridge sweeps beneath the tracked vehicle, then follow the water into the RHIB shot. |
| The village road | Ride behind the second tank and watch both hulls enter the village. From the roadside, let the lead tank draw level. Cut to the following crew’s periscope on the next simulation frame, with the first tank still ahead in the dust. |
| Into the trench | See riflemen cross the timber trench beside a tracked vehicle. Look over the sandbag wall as the crew fires. Cut to the same round dropping beside the wreck and let the dirt rise against the sky before the airlift. The two field-camera scenes store their positions and travel times in metres and simulation seconds. |
| At sea | Follow the landing boats to the beach. From behind the patrol ship, watch the two defending boats approach from different sides of the harbour. |
| Airstrike | Follow the jet off the ridge, then look ahead from above its tail to see the quay. Cut under the wing as the bombs separate against the mountains. Cut to the parked pickup as the strike overturns it. |
| Trench assault | Two infantry fighting vehicles move toward an occupied line with rifle squads behind. Hold on the defenders, then move down beside the timber firing bay for the 155 mm barrage. |

The actual menu map comes in over the final burst. The menu emblem and wordmark appear first, followed by the free Windows, macOS and Linux invitation and the open-source license. The game score resolves over the card.
