# Signal: how Frontline's interface looks and moves

Signal is the interface's design: a battle management display laid straight onto the scene. It decides how every
screen is drawn, from the status line to the after-action report, and how anything on them moves. This page is the
reference; the code that carries it out is in `scripts/ui/ui_kit.gd` (tokens, fonts, the shared Theme, drawn parts),
`ui_frame.gd`, `ui_motion.gd`, `ui_seg.gd`, `ui_steps.gd`, `ui_scrim.gd` and `ui_fx.gd`.
`--ui-gallery=out.png [--gallery-theme=KEY] [--gallery-scene=scene.png]` saves every component in every state on
one screen (over a battle scene, if you give it one) and quits.

## The seven rules

1. **Signal over noise.** Show what helps a decision now; cut the rest. A panel that's empty says nothing rather
   than drawing a box around nothing.
2. **Data on the scene.** Lists and readouts sit on the battlefield over an edge scrim, not in boxed panels. A
   dialog or a sheet is flat ink.
3. **Lines, not frames.** A 1 px rule under a row or beside a header; four corner ticks to mark a region. Everything
   is square: no rounded corners, no shadows, no bevels.
4. **Two voices.** Condensed capitals for labels and names; mono for figures and codes. Prose only for sentences.
5. **Concise.** Codes, not phrases: `MOV D8`, `PINNED · DEF E4`, `SUP 615 +174/M`, `T+04:31`, `RDY`, `261S`.
6. **One signal colour.** The accent means selected, active, primary or live, and nothing else. The colours that
   mean something (good, bad, warning, intel) and the two sides' colours are fixed.
7. **Motion cuts, types on, counts or flickers.** Nothing eases, overshoots, bounces or glows.

## Colour

Each theme (Settings > Interface: Field Brass, Night Vision, Thermal, Arctic, Dusk) sets three colours, and the
rest are mixed from them, so a new theme recolours everything at once (`UiKit.apply_theme`).

| Token | What it is for |
| --- | --- |
| `ACCENT` | the signal: the selected row, the active tab or key, the primary button, a live state |
| `TEXT` | names, figures, the active item |
| `DIM` | codes, values, states (text mixed two thirds of the way from the ink) |
| `FAINT` | labels, units, timestamps, the inactive (half way) |
| `INK` | what the interface sits on |
| `PANEL` / `PANEL_SOFT` / `SCRIM` | ink at 0.9 (a dialog, a sheet), 0.62 (under the HUD's lists), 0.82 (a scrim at its darkest) |
| `LINE` / `RULE2` | rules: text at 0.14 (under rows, beside headers), 0.3 (key boxes, field lines, resting ticks) |
| `GOOD` `BAD` `WARN` `INTEL` | fixed in every theme: done or rising, lost or danger, caution, intelligence |
| `ON_ACCENT` | text on an accent fill |

The text tiers are opaque mixes, not alphas, so text over text never shows through. Side colours come from
`Defs.TEAM_COLORS`; a co-commander's from his player colour.

## Two voices

- **Labels and names**: Bahnschrift SemiCondensed in capitals, letter-spaced (`UiKit.cond`, `caps`, `caps_at`).
  Labels at 11 px in `FAINT` or `DIM`, names at 13 px and up in `TEXT`, buttons and tabs.
- **Figures and codes**: Cascadia Mono (Consolas, then DejaVu Sans Mono) (`UiKit.mono`, `mono_label`, `mono_at`).
  Every number, time, count, grid reference, key and state code, so columns line up and read like a readout.
- **Prose**: Bahnschrift at its normal width (`UiKit.font`, `label`), only for sentences: radio messages,
  descriptions, briefings, tooltips, help.

Text on the battlefield gets a soft dark outline (`UiKit.text_f(..., outline)`); on ink it barely shows.

## Voice

Write what a radio operator would say, as short as it stays clear. A label names (`SUP`, `UNITS`, `FIRES`); a code
states (`PINNED`, `TO SPT D4`, `RDY`, `3/8`, `42 MS`). Sentences stay sentences and keep their full stops. Keys
shown on screen are whatever the player bound them to (`Keys.label`), never a hard-coded letter.

## Codes

The HUD's states, as the ORBAT and the selection show them:

| Code | Means |
| --- | --- |
| `MOV D6` `BOUND D6` | moving, or bounding by fire teams, to the square |
| `ATK D6` `DEF D6` `AMBUSH D6` `BUILD D6` | attacking, defending, lying in ambush, building there |
| `PINNED ·` `CONTACT ·` `MOUNTED ·` | the squad's condition, ahead of what it's doing |
| `FALL BACK` `BREAK CONTACT` `ROUTING` `DISPLACE` `TUNNELS` | moving away from a fight |
| `PLAN D4` `TO SPT D4` `TO ASLT D4` `FIX D4` `FIRE ON D4` `ASSAULT D4` `REGROUP D4` | an attack plan's stages |
| `HOLD` `MOVING` `ENGAGING` `IMMOBILISED` `BADLY DAMAGED` | a vehicle |
| `RFL` `SL` `MG` `AT` `ENG` `MED` `MOR` `CRW` `FPV` `STR` | a man's role |
| `RDY` `287S` `+N ON COOLDOWN` | a fire mission ready, its cooldown, the ones folded away |
| `T+04:31` `+230/M` `+115 SUP` | the battle clock, a rate a minute, a delivery |

## Layout

The battle keeps the middle of the screen for the battle. Everything else sits on an edge, over a scrim that
darkens toward that edge (`UiScrim`), so it reads over any ground without a box:

- **Top** (the **Status** line): the side, `SUP` and its rate, `UNITS`, `FOB`, `TOWNS`, and the clock. A line under
  it for each FOB says what its trucks are doing.
- **Left**: the minimap is a fixed navigation anchor. Opening tools never hides, moves or resizes it.
  A 32 px line-icon strip opens **Units**, **Support** or **Layers**. Layers reveals switches beside the map.
- **Right**: Units and Support open a task workspace on the opposite edge, with enough height to scan a
  roster or compare support. It sits below objectives and above the contextual command card. On short
  viewports, objectives and the command net yield temporarily to keep the task controls clear of orders. The recent
  Events stream yields while a task is open and returns with its previous minimized state when it closes.
  Units focuses search on opening; search accepts callsigns, role names and vehicle names. Arrow keys browse
  the full result list and scroll the active row into view. Click selects without moving the camera;
  Shift-click adds. Enter, double-click or **Focus selected** focuses the unit and closes the workspace.
  Two-line 40 px rows separate names and strength from status, avoiding cramped code truncation.
  Support explains availability and supply requirements; choosing a strike closes the workspace so its target
  can be placed on the battlefield. Observer actions are clearly labelled demos.
- **Bottom**: selection details and the contextual order card stay available while comparing units.
  Escape cancels an active targeting action, then closes an open workspace before clearing selection.
  The bottom scrim only darkens while something is selected.

Normal battlefield views show selected squad plans; tactical views reveal other plans through the Orders
layer. Unit symbols and plan labels yield to occupied HUD areas. All task content follows Signal's condensed
typography, rules and feathered edge shading, with no enclosing panel backplates.

Menus put the title and the entries on the left over the living map, panels in the middle, the account on the
right. Dialogs stay inside the scaled viewport: long content scrolls, and keyboard focus brings its action into
view. The lobby's roster scrolls independently so Join, Ready, Start and Leave stay reachable; browser filters
and direct-connect controls wrap rather than pushing actions off the right edge.

## Scrim

`UiScrim` is the ink fading in from an edge of the screen: darkest at the edge, nothing a set distance in, and
fading out along the edge past the part it serves. There's one per edge, behind every HUD part on that edge, never
one per part; the bottom one darkens only while something is selected. The active left column holds readable
ink underneath its content and feathers out above and toward the battlefield, without a hard panel edge.

## Panels

A dialog, a sheet or a card is flat ink (`PANEL`) with four corner ticks in `RULE2` standing 6 px off it
(`UiKit.frame()`); the one that has the focus wears accent ticks (`UiKit.frame_hot()`). No borders, no rounded
corners, no glow. In code: a `PanelContainer` with `UiKit.frame()` as its `panel` stylebox, or `UiFx.panel` /
`UiKit.ticks` when a screen draws itself.

## Dialog

The pause menu is the pattern: a header (the dialog's name in capitals and a rule), a context line in mono
(`T+04:31 · OP BROKEN CROSSING`), and a list of rows. It arrives 8 px from below in 0.16 s.

## Row

A list row is 26 px in the HUD and 34 to 36 px in menus and dialogs, ruled off underneath in `LINE`. Its name in
capitals on the left, its codes in mono, its figures or key on the right. Under the cursor it lightens
(`TEXT` at 0.05); selected, it takes the accent (an accent fill with `ON_ACCENT` text, or accent text with a 2 px
accent edge on the left). A section of rows starts with a **header** (`UiKit.header`): a label in `DIM` capitals,
an optional count in mono, and a rule running on to the end of the column.

## Keys

A key is its name in mono in a square hairline of `RULE2` (`UiKit.key`, `Hud._key_box`), filled with the accent
when it's the order being given. The orders card is a grid of keyed rows: `[X] ATTACK-MOVE`, `[B] DEFEND`; the ones
that fall back are in `BAD`.

## Options

- A choice of two to five short options is a row of square segments, the chosen one filled with the accent
  (`UiSeg`): `OFF | ON`, `LOW | MEDIUM | HIGH | ULTRA`, the five themes.
- A longer list is a drop-down (`OptionButton`, square, from the shared Theme).
- A text field is mono on an underline.
- Tabs are capitals, the open one in the accent and underlined.

## Meter

An amount is counted, not smooth: a row of square steps filled to the value (`UiKit.steps`, `UiFx.bar`), in the
accent, or in a meaning colour when the amount means something (health). A slider is the same bar you can drag
(`UiSteps`, 20 steps). A squad's strength is pips, one per man: alive in `TEXT`, wounded in `WARN`, lost in `RULE2`
(`UiKit.pips`).

## Log

Up to three recent messages stay top right on the scrim, a line each: the time in mono, who it's from in capitals, what it
says in prose. They come in three levels:

- a **notice** is just a line;
- a **caution** (`▲ CAUTION`) is ruled off above and below in `WARN` and flickers on once;
- a **warning** (`▲ WARNING`) is ruled off in `BAD` and flickers on twice.

The **Events −** control minimizes the stream to **Events +**, with a count of new arrivals. Messages
continue entering history while minimized. Expanding clears the new-arrival count. The message history
(L by default) opens in their place on a lighter ink and also reopens a minimized stream. Minimizing
closes history too. The event control stays below objectives and the command net.

## Marks on the battlefield

In Battle view, routine soldier names, activity icons and speech belong to selected troops. Suppression
warnings, squad symbols and hover inspection remain available; the other tasks retain the detailed overlays.
Names over bases and towns are capitals with the world-text outline and a small square in the owner's colour, no
box; a selected vehicle wears accent corner ticks; hover cards are ink with ticks and counted health and ammunition;
order tags, grid letters and how long ago an enemy was seen are mono; a cursor hint says what the click will do in
capitals and its cost or square in mono (`MORTAR HE D4`, `3 × SANDBAGS 90 SUP`).

## Motion

The interface redraws like a display: it doesn't swing, bounce or glide (`UiMotion`).

| Motion | How | Time |
| --- | --- | --- |
| **Cut** | a state change: on, off, a new value | at once |
| **Arrive** | a panel or a dialog drawn 8 px off (rows 4 px) in its first frame, moving into place fast and exactly | 0.12 s (a dialog 0.16 s) |
| **Stagger** | a list's rows arriving one after another | 16 ms apart, the first eight |
| **Type on** | new text, left to right | 18 ms a character, at most 0.3 s |
| **Count** | a figure counting up to its value | 0.9 s |
| **Flicker** | an alert landing: on, off, on | one 60 ms frame each |

A spinner for real waiting is allowed. Nothing pulses to get attention; the accent and a flicker do that.
**Settings > Interface > Reduce motion** makes every one of these a cut (`UiMotion.reduced()`).

## Adding to the interface

- Build controls with `UiKit` (`caps`, `mono_label`, `header`, `button`, `UiSeg`, `UiSteps`) and set
  `theme = UiKit.theme()` on a new screen's root; draw with `caps_at`, `mono_at`, `rule`, `ticks`, `steps`, `pips`
  and `key`.
- Read the tokens when drawing (they're static vars, so a new theme shows at once); never write a colour literal for
  something a token covers.
- Use `UiMotion` for anything that moves.
- Add the new part to the gallery (`scripts/test/ui_gallery.gd`) and look at it with `--ui-gallery=out.png
  --gallery-theme=KEY` in each theme.
