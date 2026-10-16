# Contributing to Frontline

Thanks for helping. Bug reports, ideas, balance feedback and pull requests are all welcome.

## Reporting a bug

Open an issue with the **Bug report** template. The most useful reports include:

- what you were doing, and what you expected to happen;
- the map seed (Esc menu) and the game mode (vs AI, co-op, PvP, observer);
- any `SCRIPT ERROR` lines from the console (run Godot from a terminal to see them);
- a screenshot, if it's something visual.

## Running the game from source

You need **Godot 4.7** (the standard build, not .NET). Open `project.godot` and press F5, or:

```
godot --path .
```

## Before you open a pull request

Everything in the game is code: models, effects, sounds and AI. There are no asset pipelines to set up. Please check two things before opening a pull request:

1. **Every script compiles.** This prints nothing if all is well:
   ```
   godot --headless --path . --import 2>&1 | grep -E "SCRIPT ERROR|Parse Error"
   ```
2. **The game still runs headless.** Run a couple of scenarios and a short AI-vs-AI game, and look for `SCRIPT ERROR` in the output:
   ```
   godot --headless --path . -- --scenario=attack --stats=60 --quit-after=60 --port=7901
   godot --headless --path . -- --aivai --timescale=6 --stats=300 --quit-after=900 --port=7902
   ```
   [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) lists every scenario and test flag. If you touch multiplayer, also run a host and a client (see "Host / client" there).

CI runs the same checks on every push and pull request.

## Code style

- GDScript with tabs. Use typed variables where the type isn't obvious (`var d: float = ...`), because Godot can't infer types through untyped calls.
- Comments explain **why**, in plain language: what a real soldier, crew or commander would do, and how the code models it. Read the neighbouring code and match it.
- Data (units, weapons, vehicles, buildings) lives in `scripts/autoload/defs.gd` and `scripts/game/vehicle_roster.gd`. Behaviour lives with the thing that behaves.
- The server is authoritative. Gameplay logic runs on the host (`world.srv`); clients only draw. Anything clients need to see has to be replicated (see `world.gd`, and `write_state` / `read_state` on each entity).
- Keep things deterministic per seed where you can (use `world.rng`), so a seed reproduces a map and a fight.

## Commits and pull requests

- One coherent change per pull request, with a description of what changed and how you tested it.
- Commit messages: a short summary line, then a body saying what and why.
- For anything visual, attach before and after screenshots.

## Licence

By contributing, you agree that your contributions are licensed under the project's [MIT licence](LICENSE).
