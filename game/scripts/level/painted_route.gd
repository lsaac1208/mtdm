extends Node2D
## Each landmark has a fixed place along the route. The distant painting pans
## inside its own bounds, while landmarks travel faster and the ground is 1:1.

const DIRECTORY := "res://assets/env/painted/"
const ZONE_KEYS := ["village", "road", "lowland", "temple", "burial"]
const SOIL := preload("res://shaders/painted_soil.gdshader")
# Painted near-plane objects [texture, world x, height at 720p, mirror].
const LANDMARKS := [
	["fence", -30, 58, true], ["wheel", 1070, 57, false],
	["chime", 1390, 78, true], ["fence", 2090, 48, false],
	["wheel", 2790, 77, true], ["fence", 3540, 58, true], ["wheel", 4140, 42, false],
	["reeds", 4500, 82, true], ["reeds", 5430, 70, false], ["fence", 5910, 44, true],
	["reeds", 6460, 58, false], ["bell", 6890, 100, false], ["fence", 7660, 56, false],
	["bell", 8460, 65, true], ["cairn", 8840, 66, false], ["cairn", 9530, 83, true],
	["cairn", 9880, 53, false], ["cairn", 10970, 62, true]
]
# Foreground silhouette clusters anchored cleanly in the bottom soil margin
# (strictly below screen y = 550 ground line) at 1.22x parallax for world depth.
# [texture, world_x, height_px, flip_h, zone_idx]
const FG_CLUSTERS := [
	["fg_village", 420.0, 118.0, false, 0],
	["fg_village", 1220.0, 132.0, true, 0],
	["fg_village", 2040.0, 124.0, false, 0],
	["fg_village", 2820.0, 120.0, true, 1],
	["fg_village", 3680.0, 134.0, false, 1],
	["fg_lowland", 4640.0, 126.0, false, 2],
	["fg_lowland", 5540.0, 136.0, true, 2],
	["fg_lowland", 6360.0, 124.0, false, 2],
	["fg_temple", 7060.0, 132.0, false, 3],
	["fg_temple", 7920.0, 138.0, true, 3],
	["fg_burial", 8940.0, 128.0, false, 4],
	["fg_burial", 9740.0, 136.0, true, 4],
	["fg_burial", 10720.0, 130.0, false, 4],
]

var paintings: Array[Sprite2D] = []
var landmarks: Array[Sprite2D] = []
var fg_props: Array[Sprite2D] = []


func texture(key: String) -> Texture2D:
	return load(DIRECTORY + key + ".webp")


func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = -10
	add_child(canvas)
	for key in ZONE_KEYS:
		var background := Sprite2D.new()
		background.texture = texture(key)
		background.centered = false
		canvas.add_child(background)
		paintings.append(background)
	for entry in LANDMARKS:
		var prop := Sprite2D.new()
		prop.texture = texture(entry[0])
		prop.offset.y = -prop.texture.get_height() * 0.5
		prop.scale = Vector2.ONE * float(entry[2]) / prop.texture.get_height()
		prop.flip_h = entry[3]
		prop.modulate = Color(0.86, 0.84, 0.78, 0.82)
		canvas.add_child(prop)
		landmarks.append(prop)
	var fg_canvas := CanvasLayer.new()
	fg_canvas.layer = 2
	add_child(fg_canvas)
	for entry in FG_CLUSTERS:
		var fg := Sprite2D.new()
		fg.texture = texture(String(entry[0]))
		fg.offset.y = -fg.texture.get_height() * 0.5
		fg.scale = Vector2.ONE * (float(entry[2]) * 1.16) / fg.texture.get_height()
		fg.flip_h = bool(entry[3])
		var zi: int = int(entry[4])
		var zshadow: Color = LevelData.ZONES[zi].light.shadow
		var dark := zshadow.darkened(0.54)
		fg.modulate = Color(dark.r, dark.g, dark.b, 0.88)
		fg_canvas.add_child(fg)
		fg_props.append(fg)


func follow(camera: Vector2, viewport: Vector2, weights: Array) -> void:
	var dy := camera.y - (Game.GROUND_Y - 190.0)
	var coverage := 0.0
	for i in paintings.size():
		var sprite := paintings[i]
		var weight: float = weights[i]
		coverage += weight
		sprite.visible = weight > 0.0
		if not sprite.visible:
			continue
		# For opaque paintings composited back-to-front the first visible
		# layer stays opaque, including halfway across a zone boundary.
		sprite.self_modulate.a = weight / coverage
		var dims := sprite.texture.get_size()
		var scale_factor := maxf((viewport.x + 240.0) / dims.x, (viewport.y + 130.0) / dims.y)
		sprite.scale = Vector2.ONE * scale_factor
		var start: float = LevelData.ZONES[i].x
		var end: float = LevelData.ZONES[i + 1].x if i + 1 < paintings.size() else LevelData.LENGTH
		var pan := smoothstep(start - 320.0, end + 320.0, camera.x)
		var excess := dims * scale_factor - viewport
		sprite.position = Vector2(-excess.x * pan, clampf(-excess.y * 0.48 - dy * 0.13, -excess.y, 0.0))
	for i in landmarks.size():
		var screen_x := viewport.x * 0.5 + (float(LANDMARKS[i][1]) - camera.x) * 0.79
		var prop := landmarks[i]
		prop.visible = screen_x > -200 and screen_x < viewport.x + 200
		if prop.visible:
			prop.position = Vector2(screen_x, viewport.y * 0.5 + 178.0 - dy * 0.79)
	for i in fg_props.size():
		var fg := fg_props[i]
		var screen_x := viewport.x * 0.5 + (float(FG_CLUSTERS[i][1]) - camera.x) * 1.22
		fg.visible = screen_x > -340.0 and screen_x < viewport.x + 340.0
		if fg.visible:
			# Bottom-anchored below screen y = 550 ground line so silhouettes never occlude actors.
			fg.position = Vector2(screen_x, viewport.y + 18.0 - dy * 1.15)


func add_soil(left: float, right: float, floor_y: float) -> void:
	# An overlap on entry lets soil colours blend with the same world-space
	# boundary as the paintings. Sample their actual lower rock strata.
	for i in ZONE_KEYS.size():
		var x0: float = left if i == 0 else maxf(left, LevelData.ZONES[i].x - 150.0)
		var x1: float = right if i + 1 == ZONE_KEYS.size() else minf(right, LevelData.ZONES[i + 1].x + 150.0)
		if x1 <= x0:
			continue
		var ground := Polygon2D.new()
		ground.texture = paintings[i].texture
		var top := floor_y - 4.0
		ground.polygon = PackedVector2Array([Vector2(x0, top), Vector2(x1, top), Vector2(x1, top + 600.0), Vector2(x0, top + 600.0)])
		ground.uv = PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, 600.0), Vector2(x0, 600.0)])
		var mat := ShaderMaterial.new()
		mat.shader = SOIL
		mat.set_shader_parameter("start_px", -32768.0 if i == 0 else LevelData.ZONES[i].x - 150.0)
		ground.material = mat
		ground.z_index = 1
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(ground)
