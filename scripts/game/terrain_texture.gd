class_name TerrainTexture
extends RefCounted
## Deformation is uploaded in small layers. A one-sample border preserves
## linear filtering across tile edges without re-uploading the entire map.

const TILE := 512  # 144 layers at 3 km, below the baseline 256-layer limit
var texture := Texture2DArray.new()
var source: Image
var count := 0
var pending := {}


func _init(image: Image) -> void:
	source = image
	count = ceili(float(image.get_width()) / TILE)
	var layers: Array[Image] = []
	for z in count:
		for x in count:
			layers.append(patch(Vector2i(x, z)))
	texture.create_from_images(layers)


func patch(key: Vector2i) -> Image:
	var region := Rect2i(key * TILE - Vector2i.ONE, Vector2i.ONE * (TILE + 2))
	var available := region.intersection(Rect2i(Vector2i.ZERO, source.get_size()))
	var image := Image.create(TILE + 2, TILE + 2, false, source.get_format())
	image.blit_rect(source, available, available.position - region.position)
	return image


func mark_dirty(rect: Rect2i) -> void:
	var from := (rect.position - Vector2i.ONE).clamp(Vector2i.ZERO, source.get_size() - Vector2i.ONE) / TILE
	var to := (rect.end + Vector2i.ONE).clamp(Vector2i.ZERO, source.get_size() - Vector2i.ONE) / TILE
	for z in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			pending[z * count + x] = true


func flush(limit := 2) -> void:
	for i in mini(limit, pending.size()):
		var layer: int = pending.keys()[0]
		pending.erase(layer)
		texture.update_layer(patch(Vector2i(layer % count, layer / count)), layer)


static func shader(code: String) -> String:
	return code.replace("// TERRAIN_TEXTURE_HELPER", SHADER_HELPER)


const SHADER_HELPER := """
float terrain_geology(sampler2DArray heights, vec2 uv) {
	float tiles = sqrt(float(textureSize(heights, 0).z));
	vec2 grid = clamp(uv, vec2(0.0), vec2(0.999999)) * tiles;
	vec2 cell = floor(grid);
	vec2 local_uv = (fract(grid) * 512.0 + 1.0) / 514.0;
	return textureLod(heights, vec3(local_uv, cell.y * tiles + cell.x), 0.0).g;
}

float terrain_height(sampler2DArray heights, vec2 uv) {
	float tiles = sqrt(float(textureSize(heights, 0).z));
	vec2 grid = clamp(uv, vec2(0.0), vec2(0.999999)) * tiles;
	vec2 cell = floor(grid);
	vec2 local_uv = (fract(grid) * 512.0 + 1.0) / 514.0;
	return textureLod(heights, vec3(local_uv, cell.y * tiles + cell.x), 0.0).r;
}
"""
