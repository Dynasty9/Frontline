class_name MapDims
extends RefCounted
## How big the battlefield is. Everything sized to the map - the nav and
## terrain grids, the deformation and trench masks, the ground, the grass, the
## physics ground, the minimap, the grid references - derives from here.

const HALF := 256.0  # metres from the centre to each edge
const N := 512  # 1 m cells across
const SIZE := HALF * 2.0
## The biome noise (mud, grass, bare earth) is a seamless square this many
## pixels (metres) across, centred on the map; it must cover the map.
const BIOME := 512
## Grid references: GRID x GRID squares (A-H, 1-8) of CELL metres.
const GRID := 8
const CELL := SIZE / GRID


## Shader code with the map's size filled in (shaders use __MAP_HALF__ and
## __MAP_SIZE__ where they turn a world position into a map texture's UV, and
## __BIOME_HALF__ / __BIOME__ for the biome noise). The menu backdrop passes
## its own half-size.
static func shader(code: String, half := HALF) -> String:
	var c := code.replace("__MAP_HALF__", "%.1f" % half).replace("__MAP_SIZE__", "%.1f" % (half * 2.0))
	return c.replace("__BIOME_HALF__", "%.1f" % (BIOME * 0.5)).replace("__BIOME__", "%.1f" % float(BIOME))
