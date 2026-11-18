+++
title = "Bounce light: in the shade, behind smoke, round fires"
summary = "Bounce light now lifts what stands in shade, such as a tank's shaded side and the ground in its shadow, and leaves sunlit grass and decks as they were. It stays hidden behind smoke and dust, and goes round a room more than once."
kind = "improved"

[[screenshots]]
file = "tank.jpg"
caption = "A tank on sunlit grass: its shaded side and skirts pick up the grass's light (off above, on below)"

[[screenshots]]
file = "tank-light.jpg"
caption = "The same, bounce light only (four times brighter): on the shaded hull side, while the sunlit deck and lawn stay dark"

[[screenshots]]
file = "dust.jpg"
caption = "Dust in front of a tank: laid over the dust, the hull's bounce light showed through it; now the dust hides it as it hides the hull"

[[screenshots]]
file = "red55.jpg"
caption = "From the 55 m command height: a red-brick house's shaded front and the ground at its foot take a faint red"

[[screenshots]]
file = "red55-light.jpg"
caption = "The same, bounce light only (four times brighter)"

[[screenshots]]
file = "room.jpg"
caption = "A house with its roof lifted: the shaded floor along its walls, and the walls, lit by the sunlit floor"

[[screenshots]]
file = "room-light.jpg"
caption = "The same, bounce light only (four times brighter): the sunlit floor itself stays as it was"

[[screenshots]]
file = "golden.jpg"
caption = "Golden hour, from 30 m: the shaded side of a ruin lifts with light off its sunlit walls"

[[screenshots]]
file = "golden-light.jpg"
caption = "Golden hour, bounce light only (four times brighter)"

[[screenshots]]
file = "fire-night.jpg"
caption = "Night: a burning car's light thrown onto the wall and ground beside it"

[[screenshots]]
file = "fire-night-light.jpg"
caption = "The same, bounce light only (four times brighter)"

[[videos]]
file = "golden-pan.webm"
poster = "golden-pan.jpg"
caption = "Golden hour, panning and zooming out over the town at 60 frames a second, bounce light on."

[[videos]]
file = "golden-pan-light.webm"
poster = "golden-pan-light.jpg"
caption = "The same pan, the bounce light alone (brightened): it stays on what it lights as the view moves, with no shimmer or crawl."

[[videos]]
file = "squad.webm"
poster = "squad.jpg"
caption = "Golden hour, a squad crossing the field to clear a house at 60 frames a second, camera still, bounce light on."

[[videos]]
file = "squad-light.webm"
poster = "squad-light.jpg"
caption = "The same, the bounce light alone (brightened): it moves with the men and holds steady on the ground and walls round them."

[[videos]]
file = "pan.webm"
poster = "pan.jpg"
caption = "The bounce light alone (brightened) while the camera pans: it stays on what it lights, with no smears or trails."
+++

- **Where it belongs:** sunlit grass, roads, roofs and hulls no longer take a yellowish lift. The light lands in the
  shade beside them, where bounce light really shows. A tank's shaded side and skirts pick up the green of the grass
  below them, and the ground in its shadow warms with the light off its hull.
- **Behind smoke and dust:** a dust cloud in front of a hull or a wall hides its bounce light, as it hides the hull,
  instead of the light showing through.
- **Coloured walls tint their surroundings:** a red-brick house faintly reddens the shade at its foot, even from
  the command height.
- **Rooms lit through their doors:** with a house's roof lifted, sunlight on its floor lights the shaded floor and
  walls round it.
- **Light goes round more than once:** what one wall throws onto the floor is thrown on again, into the corners of
  a room, and settles in a second or two.
- **Fires and lamps throw it too:** a burning car lights the wall and ground beside it in its colour.
- **Steady at the frame's edges.** Wet roads and smooth surfaces in shade also pick up a faint sheen of the colours
  round them.

### Light on newly revealed surfaces

Moving the camera or a vehicle no longer lets multi-bounce feedback borrow the
previous frame's light from a different surface. Each interpolated history sample
must agree in depth and facing before it can light the next bounce. This leaves the
existing shade strength, sunlight restraint and exposure unchanged.

The device regression is `godot --path . --rendering-method forward_plus --script
tests/fixtures/ssgi-feedback.gd`. It checks a stable surface, newly revealed ground,
a different-facing neighbour and an interpolation footprint crossing their edges.
