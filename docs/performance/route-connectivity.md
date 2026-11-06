# Route connectivity

`RouteGraph::components` rejects disconnected routes before budgeted A* starts.
The old depth-first traversal follows adjacency pointers through the whole graph,
including the degree-two nodes that hold local path costs. The replacement scans
point storage in order, joins endpoints with path halving, then resolves labels.
Each undirected edge is considered once. Components keep their smallest slot as
label, so every output label, including vacant slots, matches the old traversal.
Route weights, neighbor ordering, expansion budgets and cache invalidation stay
unchanged. The labels are derived state and are not added to checkpoints.

## Connectivity microbenchmarks

Windows, i9-11900K, Rust 1.94.0 release. Other apps remain running. Each row is a
20-call block; order alternates between old and new within one process. Restoring
or generating the graph is outside the measured region. Every graph is checked
against the independent depth-first implementation before timing.

| Graph | Entrances | All points | Old mean ranges, ms | New mean ranges, ms |
| --- | ---: | ---: | ---: | ---: |
| Open 1024-cell grid | 32,256 | 143,632 | 9.11–10.94 | 5.11–6.11 |
| Saved 3 km city | 70,218 | 300,549 | 17.55–21.77 | 9.54–14.77 |

The city block means average 20.44 ms before and 12.32 ms after (39.7% less time).
This is a component measurement, not an FPS claim. Connectivity semantics are retained; no new dependency or worker is introduced.

Reproduce the synthetic case from the repository root:

```powershell
cargo +1.94.0 test --locked --release --manifest-path native/Cargo.toml -p frontline_core --lib benchmark_connectivity -- --ignored --nocapture
```

Set `FL_NAV_BENCHMARK` to an exported `Hierarchy::checkpoint` file to use a real
battlefield. Local city evidence is retained under `build/linear.nav`,
`build/connectivity-city-bench.log` and `build/connectivity-bench.log` in the
route-connectivity worktree. The initial state is shared with the rendering
benchmarks at `soldier-presentation-queue/build/large.initial`.

## Correctness

The mutation/restore regression compares every label with a depth-first oracle,
including removed and reused slots and disconnected islands. Existing bounded
search, terrain repair, danger, checkpoint, numeric contract and replay tests
pass: 1,150 tests across the core, runtime and server crates (five opt-in tests
ignored by the normal command). The release native extension and server build.

A separate release run starts the saved 3 km city with 500 soldiers and advances
3,600 ticks on each implementation. Both produce command/event hash
`2c6897cd8e88a50cec7e341828aa7c62a76c32370426bd2eb2bbb2d6657768a2`
and final state hash
`f3183e4468c9bd1bce43a9b8777e6b995100bb895ab5f65cec4739054e6b2cc6`.
The state comparison excludes only the build identity prefix, which necessarily
changes with simulation source. Replay verification still requires the exact
recording build; that guard is unchanged.

The first whole-simulation timing run is excluded because a rendering fixture
was running concurrently. Its state/hash comparison remains valid. Isolated
whole-simulation measurements (last 1,800 of 3,600 ticks) were:

| Run | Mean tick, ms | p99 tick, ms | p99 navigation paths, ms |
| --- | ---: | ---: | ---: |
| New 1 | 9.46 | 24.35 | 11.93 |
| Old 2 | 7.41 | 26.46 | 16.77 |
| New 2 | 7.31 | 19.59 | 9.15 |
| Old 3 | 7.45 | 25.97 | 16.64 |

All four produced the same hashes above. Background application load varies:
these runs support a reduced navigation tail, not a general FPS or mean-tick
speedup. The headless Godot attack scenario also completes without script errors.
