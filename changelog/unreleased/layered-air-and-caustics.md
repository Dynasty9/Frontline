+++
title = "Mist in the hollows, smoke that drifts, light under the water"
summary = "The air over the battlefield lies in layers now: ground mist in the low ground, a sunlit haze above, smoke plumes that drift off downwind, and weather that varies across the map. A net of sunlight plays over shallow beds and flickers on hulls and piers."
kind = "improved"

[[screenshots]]
file = "mist-off-on.jpg"
caption = "Off and on: pale dawn mist lying level in the valley, the hills rising out of it"

[[screenshots]]
file = "shafts-off-on.jpg"
caption = "Off and on at dawn, looking toward the sun: the air glows close around the sun, with softer shadowed air below the ridges, while the town stays clear"

[[screenshots]]
file = "glow-off-on.jpg"
caption = "Off and on: a burning house at dusk, the billows nearest its flames lit dull orange"

[[screenshots]]
file = "night-off-on.jpg"
caption = "Off and on at night: the street lamps glow softly in the damp air over the town"

[[screenshots]]
file = "rain-off-on.jpg"
caption = "Off and on under rain at the command view: far showers hang as soft grey veils below the clouds"

[[screenshots]]
file = "plume-off-on.jpg"
caption = "Off and on: the grey pall a barrage leaves, drifting off downwind"

[[screenshots]]
file = "net-off-on.jpg"
caption = "Off and on: the net of sunlight on the sand under the shallows"

[[screenshots]]
file = "piles-off-on.jpg"
caption = "Off and on: sunlight thrown up off the water onto the pier's shaded side"

[[screenshots]]
file = "caustics-command-view.jpg"
caption = "The shallows at the usual command view: the net is an even shimmer, with no pattern repeating"

[[screenshots]]
file = "mist-command-view-off-on.jpg"
caption = "Off and on at the usual command view: the mist stays light, so the battle stays clear"

[[screenshots]]
file = "browser-shallows.jpg"
caption = "The browser version's simpler caustics"

[[videos]]
file = "dawn-approach.webm"
poster = "dawn-approach.jpg"
caption = "Dawn approach, before and after the coastal mist correction: matching camera, seed, exposure and full High settings. Three seconds of actual Forward+ output with a static naval fixture and advancing camera and weather, at normal simulation speed; software Vulkan capture, not a performance measurement."

[[videos]]
file = "mist-flicker.webm"
poster = "mist-flicker-poster.jpg"
caption = "The same frozen dawn moment, mist off and on every second."

[[videos]]
file = "shafts-flicker.webm"
poster = "shafts-flicker-poster.jpg"
caption = "The same frozen dawn moment, the layered air off and on every second."

[[videos]]
file = "glow-flicker.webm"
poster = "glow-flicker-poster.jpg"
caption = "A burning house at dusk, the fire's light in its smoke off and on every second."

[[videos]]
file = "burst-flash.webm"
poster = "burst-flash-poster.jpg"
caption = "Shells bursting at dusk flash the smoke hanging round them."

[[videos]]
file = "night-flicker.webm"
poster = "night-flicker-poster.jpg"
caption = "The same frozen night moment, the air off and on every second."

[[videos]]
file = "convoy-dust.webm"
poster = "convoy-dust-poster.jpg"
caption = "A column on a dirt road: its dust hangs along the route, drifts off downwind and settles."

[[videos]]
file = "headlights.webm"
poster = "headlights-poster.jpg"
caption = "The same column at night, side-on: each vehicle's pair of headlight beams in its dust and the damp air."

[[videos]]
file = "rain-flicker.webm"
poster = "rain-flicker-poster.jpg"
caption = "Under rain at the command view, the far showers off and on every second."

[[videos]]
file = "plume-flicker.webm"
poster = "plume-flicker-poster.jpg"
caption = "The same frozen moment after a barrage, plume off and on every second."

[[videos]]
file = "net-flicker.webm"
poster = "net-flicker-poster.jpg"
caption = "The shallows, caustics off and on every second."

[[videos]]
file = "piles-flicker.webm"
poster = "piles-flicker-poster.jpg"
caption = "The pier's shaded side, light off the water off and on every second."

[[videos]]
file = "caustics.webm"
poster = "caustics-poster.jpg"
caption = "The caustic net re-forming across the sand as the ripples run (Ultra water)."

[[videos]]
file = "barrage-drift.webm"
poster = "barrage-drift-poster.jpg"
caption = "A barrage's plume drifting off downwind and breaking up."

[[videos]]
file = "weather-boundary.webm"
poster = "weather-boundary.jpg"
caption = "Coastal mist and weather-cell boundary, before and after: the actual dawn shoreline with the same camera and exposure. The weather starts near a cell boundary; the battle is frozen while the weather advances. Forward+ diagnostic: 2048-pixel shadows, AA off."
+++

- **Ground mist** lies level in the valley, the hollows and along the water, a pale sheet at dawn with the hills
  rising out of it, and rises off wet ground after rain, torn into wisps by the wind. A **haze** lies higher
  up; the sun lights it, so clouds throw shafts of shadow through it.
- **Smoke that hangs**: a barrage or a burning building leaves a plume, dense where it rose, drawn out downwind,
  lit on top and grey underneath, breaking up and thinning away. Over a burning house or wreck the billows nearest the
  flames glow a dull orange, darkening to grey as they climb, and each shell burst flashes the smoke hanging round it.
- **Low sun**: at dawn, golden hour and dusk the air throws the sun's light forward, so it glows close around a low
  sun while looking across or away from it stays clear, and the air in the shadow of houses, woods and ridges stays dark.
- **The weather varies across the map**: rain comes over in heavier and lighter bands, and shells and vehicles raise
  dust from dry ground.
- **Dust behind a column**: vehicles on a dirt road or bare earth leave a pale bank of dust along their route that
  drifts off downwind and settles over half a minute or so. A paved street gives little, and grass, mud, water and rain
  give none.
- **Lights in the night air**: after dark a damp haze lies low over the field, so street lamps glow with soft halos,
  vehicles driving near you show their headlight beams, and flares, muzzle flashes and shell bursts bloom in it.
- **Rain far off**: under rain, distant showers hang as soft grey veils from the clouds, slanted by the wind, and
  drift across the valley, instead of the distance just turning to haze.
- It all eases off as you zoom out, so it never hides the fighting you're watching. It's scenery only: it doesn't
  change who can see whom.
- **Caustics**: a fine, even net of thin, sun-tinted lines of light, brightest where they meet, slowly re-forms
  across the sand and mud in the shallows, crisp in the first metre or so and softening deeper down (from Medium water quality, finer from High).
  From High it's also thrown back up onto hulls, piers and banks just above the water.
- The browser version gets a lighter version of the mist and smoke through its distance fog, and the simpler caustics.

### Weather drift at cell boundaries

The weather texture now shifts in the same frame as its sampling offset when the
air crosses a grid cell. Previously the old texture could stay in place until the
next row sweep finished, briefly moving the fog or smoke back by a whole cell.
The change keeps the existing densities, cloud lighting and caustic strengths.

### Clearer coastal sightlines

Open water no longer receives the same extra pooling weight as an enclosed
terrain hollow. The weather grid already makes the shore humid; stacking both
weights had turned dawn mist into an opaque band over nearby boats. The terrain-hollow
weighting, cloud lighting, caustic strength and exposure stay unchanged.

The matched clip is a software-Vulkan capture at 30 fixed simulation frames per
second. It demonstrates the in-game view, not hardware speed. Source revisions,
camera settings and renderer setup are recorded in `layered-air-and-caustics/weather-boundary-capture.json`.

The matched motion capture and its source revisions are recorded in `layered-air-and-caustics/dawn-approach-capture.json`.
