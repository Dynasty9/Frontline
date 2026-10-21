class_name MapDims
extends RefCounted
## How big the battlefield is. Everything sized to the map - the nav and
## terrain grids, the deformation and trench masks, the ground, the grass, the
## physics ground, the minimap, the grid references - derives from here.

static var N := 1024  # 1 m cells across; fixed for the lifetime of a world
static var HALF := 512.0
static var SIZE := 1024.0
## The biome noise (mud, grass, bare earth) is a seamless square this many
## pixels (metres) across, centred on the map; it must cover the map.
static var BIOME := 1024
## Grid references: GRID x GRID squares (A-H, 1-8) of CELL metres.
const GRID := 8
static var CELL := 128.0


static func configure(metres: int) -> void:
	# Every peer configures this before allocating its world. Keep terrain and
	# hierarchy boundaries aligned, and reject arbitrary network dimensions.
	N = metres if metres in [1024, 2048, 3072] else 1024
	HALF = N * 0.5
	SIZE = float(N)
	BIOME = N
	CELL = SIZE / GRID
	# Cache dimensions once per match; terrain queries must not dispatch a
	# chain of property getters for every cell lookup.
	Nav.N = N
	Nav.H = HALF
	TerrainMap.N = N
	TerrainMap.H = HALF
	TerrainMap.DN = N * TerrainMap.DRES
	HNav.C = 16 if N == 1024 else 32
	HNav.NC = N / HNav.C
	TrenchNet.N = N * TrenchNet.RES
	Defs.MAP_HALF = HALF


## Shader code with the map's size filled in (shaders use __MAP_HALF__ and
## __MAP_SIZE__ where they turn a world position into a map texture's UV, and
## __BIOME_HALF__ / __BIOME__ for the biome noise). The menu backdrop passes
## its own half-size.
static func shader(code: String, half := -1.0) -> String:
	if half < 0.0:
		half = HALF
	var c := code.replace("__MAP_HALF__", "%.1f" % half).replace("__MAP_SIZE__", "%.1f" % (half * 2.0))
	return TerrainTexture.shader(c.replace("__BIOME_HALF__", "%.1f" % (BIOME * 0.5)).replace("__BIOME__", "%.1f" % float(BIOME)))
