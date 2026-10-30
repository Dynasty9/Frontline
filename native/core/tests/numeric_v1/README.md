# Numeric contract 1

These are exact byte transcripts, not observer recordings or verified battles.
`numeric_contract.rs` compares them without tolerances on Windows x64, Linux x64,
Linux ARM64 and macOS ARM64, in debug and release builds. Failure reports the first
different byte rather than dumping the fixture.

- `flight.bin`: projectile, drone, guided and support-aircraft checkpoints, support
  events and RNG cursors over fixed ticks.
- `geometry.bin`: water/carved terrain, craters, rotated geometry and ray hits,
  spherical interpolation, cover anchors and infantry movement checkpoints.
- `infantry_weapon.bin`: cover-fire decisions, postures, ammunition and burst
  recovery, checkpoint state and RNG cursors, including draws between shots and recovery.

Rust 1.94.0, glam 0.32.1 with `libm`, and libm 0.2.16 with `force-soft-floats`
define this contract. No fast-math is enabled. Existing component resume tests
check continuation, and Godot fixtures separately check gameplay compatibility.
This corpus is a regression gate, not proof for every floating-point input.

To establish a deliberately changed numeric contract, bump `NUMERIC_VERSION`,
rename this directory and the test's path, review changed gameplay, then generate
the replacement files with `FL_WRITE_NUMERIC_GOLDENS=1 cargo +1.94.0 test --locked
--manifest-path native/Cargo.toml -p frontline_core --test numeric_contract`.
The update mode is forbidden in CI. Never refresh a failed platform's fixture to
accept a discrepancy: all platforms must compare against the same committed bytes.
