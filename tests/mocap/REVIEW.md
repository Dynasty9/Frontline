# Animation approval

Run from the repository root with the locally installed SWAT and Mixamo assets:

```powershell
godot --path . tests/mocap/review.tscn -- --swat-units
```

The left list contains every clip discovered by the animation viewer, including separate pack variants. The approval dropdown contains every soldier action, posture previews, life states, cover heights, stance transitions, movement directions, mounted-gun pose and impact responses. Currently this is 141 source clips and 75 gameplay cases. The gameplay cases call the shared SoldierModel renderer; they are controlled presentation tests, not live battles.

Select an item, orbit with right-drag, scrub a source clip, change playback speed, or click the character to shoot it. Reset replays the clip or gameplay case. Approve, Reject or mark Unreviewed; notes are saved when you click a decision. Next unreviewed visits both lists and wraps around. Reviews persist in `user://animation-reviews.cfg`; Open saved review folder reveals the location. `--reviews=PATH` selects another review file. Approval is feedback only and does not enable or disable game animations.

Reviews are tied to the model, core animation code and source clip hashes. A changed fingerprint is shown as Unreviewed, retaining old notes. Source clips and gameplay cases have separate approvals: approving a clip does not approve its transitions or use in battle.

## Coverage limits

Mounted-gun review uses representative hand targets without a weapon rig. Vehicle entering, exiting, piloting and sitting clips can be reviewed in the source list, but this does not validate a tank, boat or helicopter's seat alignment or boarding system. Weapon stow/draw clips likewise do not prove backpack anchoring or attachment timing. Missing integrations must still be built and reviewed in their actual environments. This tool reviews the selected SWAT infantry model; it does not certify tank animation or physics.

## Check

```powershell
godot --headless --path . tests/mocap/review.tscn -- --swat-units --review-test --reviews=user://review-test.cfg
```

The check traverses every discovered source clip and gameplay case, verifies decision/note persistence, advances the queue and invalidates changed approval. Its review file is separate from human decisions. Success prints `ANIMATION REVIEW PASS`; also check the log for script errors.
