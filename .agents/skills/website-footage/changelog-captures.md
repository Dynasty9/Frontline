# Changelog motion captures, 28 October 2026

Recorded from `1a925b4` (current main, including tank operation changes), with Godot 4.7.2 at 30 fps.
These illustrate current behaviour; they are not recordings of the historical release binaries.
Gameplay was not modified. The wildlife takes use the existing `FL_WILDLIFE_FOLLOW` camera.

Takes, cuts, brightness adjustments and output budgets are in `shots.json` under `changelog-*`.
`record.py` passes a take's optional `env` to its own Godot process and records it in the take's JSON stamp.
Raw takes and stamps are retained in `%TEMP%/frontline-changelog-footage/takes`.

Re-record the six changelog takes listed in `shots.json` with `record.py --work DIR --godot PATH`.
Build the seven named changelog outputs with `build.py --work DIR`; do not use `--install`, which targets homepage media.
Copy each output and its JPEG poster to its entry folder using the table below. Keep existing before/after
comparison images. Posters use the media filename stem followed by `-poster.jpg`.

| Output | Entry | Installed file |
| --- | --- | --- |
| changelog-tank-motion | unreleased/tank-operation | tank-motion.mp4 |
| changelog-boat-turn | v1.0.5/boats-handle-like-boats | boat-turn.mp4 |
| changelog-boat-sinking | v1.0.0/water-and-sea-battles | boat-sinking.mp4 |
| changelog-ocean-swell | v1.0.2/ocean-swell | ocean-swell.mp4 |
| changelog-fish-swimming | v1.0.3/wildlife | fish-swimming.webm |
| changelog-dolphin-leap | v1.0.3/wildlife | dolphin-leap.webm |
| changelog-helicopter-turn | v1.0.11/helicopter-flight | helicopter-turn.mp4 |

For the two wildlife outputs, transcode the built MP4 with FFmpeg:

```sh
ffmpeg -i INPUT.mp4 -an -c:v libvpx-vp9 -crf 34 -b:v 0 OUTPUT.webm
```

Use CRF 33 for dolphins. The six-second fish WebM is 0.41 MB; the trial 640px, 12 fps GIF was 13.44 MB,
so videos are used for the published footage. GIF support is exercised by a tiny three-frame story fixture.
The other media remain H.264 MP4, approximately 1.3–1.9 MB each.

After updating entry metadata, run `python .github/scripts/changelog.py check` and `build` to regenerate
website data and Markdown. The tank entry remains unreleased and appears on the website after its release.
